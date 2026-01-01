import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/ride.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../widgets/like_button.dart';
import '../../widgets/ride_route_preview.dart';
import '../../utils/background_helper.dart';
import '../../widgets/navigation/navigation_app_selector.dart';
import '../../config/api_config.dart';
import '../ride/ride_detail_screen.dart';
import '../ride/create_ride_with_map_screen.dart';
import '../groups/group_detail_screen.dart';
import '../groups/groups_screen.dart';
import '../groups/create_group_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  // Données
  List<Ride> _allRides = [];
  Ride? _nextRide;
  List<Group> _myGroups = [];
  List<Ride> _suggestedRides = [];
  bool _isLoading = true;
  String? _errorMessage;
  Position? _userPosition;
  
  // Map pour stocker l'état des likes par balade
  final Map<String, bool> _likesState = {};
  final Map<String, int> _likesCount = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadData();
  }

  Future<void> _loadUserData() async {
    // Recharger les données utilisateur pour avoir le pseudo et l'avatar à jour
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.loadUser();
    } catch (e) {
      debugPrint('Erreur lors du chargement de l\'utilisateur: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      final user = authService.user;
      _apiService.setToken(token);

      // Charger la position de l'utilisateur pour calculer les distances
      _loadUserPosition();

      // Charger toutes les données en parallèle
      await Future.wait([
        _loadNextRide(user?.id),
        _loadMyGroups(),
        _loadSuggestedRides(user),
        _loadAllRides(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _userPosition = position;
          });
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de la position: $e');
    }
  }

  // Calculer la distance entre deux coordonnées GPS (en km)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convertir en km
  }

  // Extraire la ville d'une adresse
  String _extractCityFromAddress(String address) {
    // Essayer d'extraire la ville (généralement après la dernière virgule)
    final parts = address.split(',');
    if (parts.length > 1) {
      return parts.last.trim();
    }
    // Si pas de virgule, retourner les premiers mots (limiter à 2-3 mots)
    final words = address.split(' ');
    if (words.length > 3) {
      return '${words[0]} ${words[1]}...';
    }
    return address;
  }

  // Obtenir le texte de localisation pour une balade
  String _getLocationText(Ride ride) {
    if (ride.waypoints != null && ride.waypoints!.isNotEmpty) {
      final departWaypoint = ride.waypoints!.firstWhere(
        (w) => w.type == 'depart',
        orElse: () => ride.waypoints!.first,
      );
      
      // Si on a la position de l'utilisateur, calculer la distance
      if (_userPosition != null) {
        final distance = _calculateDistance(
          _userPosition!.latitude,
          _userPosition!.longitude,
          departWaypoint.latitude,
          departWaypoint.longitude,
        );
        return 'À ${distance.toStringAsFixed(1)} km de toi';
      }
      
      // Sinon, extraire la ville de l'adresse
      return _extractCityFromAddress(departWaypoint.address);
    } else if (ride.lieuDepart is String) {
      final address = ride.lieuDepart as String;
      // Si l'adresse contient des coordonnées GPS, ne pas l'afficher
      if (address.contains(RegExp(r'^-?\d+\.?\d*,\s*-?\d+\.?\d*$'))) {
        return 'Position GPS';
      }
      return _extractCityFromAddress(address);
    }
    return 'Position GPS';
  }

  // Obtenir le message secondaire dynamique
  String _getSecondaryMessage() {
    if (_nextRide == null) {
      return 'Aucune balade prévue pour le moment';
    }
    
    final rideDateTime = DateTime(
      _nextRide!.date.year,
      _nextRide!.date.month,
      _nextRide!.date.day,
      int.parse(_nextRide!.heure.split(':')[0]),
      int.parse(_nextRide!.heure.split(':')[1]),
    );
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rideDate = DateTime(rideDateTime.year, rideDateTime.month, rideDateTime.day);
    
    if (rideDate == today) {
      return 'Une balade est prévue aujourd\'hui';
    } else {
      return 'Ta prochaine sortie approche';
    }
  }

  Future<void> _loadNextRide(String? userId) async {
    if (userId == null) return;

    try {
      // Récupérer les balades où l'utilisateur participe
      final rides = await _apiService.getRides(
        participant: userId,
      );

      // Filtrer pour ne garder que les balades futures et trouver la plus proche
      final now = DateTime.now();
      Ride? closestRide;
      DateTime? closestDate;

      for (final ride in rides) {
        final rideDateTime = DateTime(
          ride.date.year,
          ride.date.month,
          ride.date.day,
          int.parse(ride.heure.split(':')[0]),
          int.parse(ride.heure.split(':')[1]),
        );

        if (rideDateTime.isAfter(now)) {
          if (closestDate == null || rideDateTime.isBefore(closestDate)) {
            closestDate = rideDateTime;
            closestRide = ride;
          }
        }
      }

      if (mounted) {
        setState(() {
          _nextRide = closestRide;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de la prochaine balade: $e');
    }
  }

  Future<void> _loadMyGroups() async {
    try {
      final groupsData = await _apiService.getGroups();
      final groups = groupsData.map((g) => Group.fromJson(g)).toList();
      
      // Limiter à 3 groupes maximum
      if (mounted) {
        setState(() {
          _myGroups = groups.take(3).toList();
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des groupes: $e');
    }
  }

  Future<void> _loadSuggestedRides(User? user) async {
    try {
      // Charger quelques balades publiques récentes
      final allRides = await _apiService.getRides(
        typeVehicule: user?.vehiclePreference == 'les deux' ? null : user?.vehiclePreference,
        limit: 20, // Charger plus pour filtrer
      );

      // Filtrer pour ne garder que les balades où l'utilisateur n'a pas participé
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.user?.id;
      
      final filteredRides = allRides.where((ride) {
        // Exclure les balades où l'utilisateur participe déjà
        if (userId != null) {
          final isParticipant = ride.participants.any((p) => p.id == userId);
          if (isParticipant) return false;
        }
        // Exclure la prochaine balade si elle existe
        if (_nextRide != null && ride.id == _nextRide!.id) return false;
        return true;
      }).toList();

      // Limiter à 2-3 éléments maximum
      if (mounted) {
        setState(() {
          _suggestedRides = filteredRides.take(3).toList();
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des suggestions: $e');
    }
  }

  Future<void> _loadAllRides() async {
    try {
      final rides = await _apiService.getRides();
      
      // Initialiser l'état des likes
      final likesState = <String, bool>{};
      final likesCount = <String, int>{};
      for (final ride in rides) {
        likesState[ride.id] = ride.hasUserLiked ?? false;
        likesCount[ride.id] = ride.totalLikes ?? ride.likes.length;
      }

      if (mounted) {
        setState(() {
          _allRides = rides;
          _likesState.clear();
          _likesState.addAll(likesState);
          _likesCount.clear();
          _likesCount.addAll(likesCount);
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des balades: $e');
    }
  }

  Future<void> _toggleLike(String rideId, bool newLikeState) async {
    // Mise à jour optimiste
    setState(() {
      _likesState[rideId] = newLikeState;
      _likesCount[rideId] = (_likesCount[rideId] ?? 0) + (newLikeState ? 1 : -1);
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final response = await _apiService.toggleLike(rideId);
      
      if (mounted) {
        setState(() {
          _likesState[rideId] = response['data']?['isLiked'] ?? newLikeState;
          _likesCount[rideId] = response['data']?['totalLikes'] ?? _likesCount[rideId]!;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _likesState[rideId] = !newLikeState;
          _likesCount[rideId] = (_likesCount[rideId] ?? 0) + (newLikeState ? -1 : 1);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Bonjour';
    } else if (hour < 18) {
      return 'Bon après-midi';
    } else {
      return 'Bonsoir';
    }
  }

  String _getAvatarUrl(String avatarUrl) {
    // Utiliser ApiConfig.getFileUrl() qui gère le remplacement de localhost
    return ApiConfig.getFileUrl(avatarUrl);
  }

  String _getVehicleBadgeText(String? preference) {
    switch (preference) {
      case 'moto':
        return '🏍️ Moto';
      case 'voiture':
        return '🚗 Voiture';
      case 'les deux':
        return '🏍️🚗 Moto & Voiture';
      default:
        return '🏍️ Moto';
    }
  }

  Color _getVehicleBadgeColor(String? preference) {
    switch (preference) {
      case 'moto':
        return Colors.orange.shade700;
      case 'voiture':
        return Colors.blue.shade700;
      case 'les deux':
        return Colors.purple.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;
    
    // Priorité : background spécifique > background global > background par défaut
    final customBaladeBackground = user?.customBackgrounds?['balade'];
    final globalBackground = user?.customBackgrounds?['global'];
    final backgroundImage = (customBaladeBackground != null && customBaladeBackground.isNotEmpty)
        ? customBaladeBackground
        : (globalBackground != null && globalBackground.isNotEmpty)
            ? globalBackground
            : getBaladeBackgroundImageName(user?.vehiclePreference);
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: backgroundImage.startsWith('http') || backgroundImage.startsWith('/uploads')
                ? NetworkImage(backgroundImage.startsWith('/uploads') 
                    ? ApiConfig.getFileUrl(backgroundImage)
                    : backgroundImage)
                : AssetImage(backgroundImage) as ImageProvider,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // AppBar personnalisé
                        SliverAppBar(
                          expandedHeight: 120,
                          floating: false,
                          pinned: true,
                          backgroundColor: Colors.transparent,
                          flexibleSpace: FlexibleSpaceBar(
                            background: _buildHeader(user),
                          ),
                        ),
                        // Contenu scrollable
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section: Ma prochaine balade
                                _buildNextRideSection(),
                                const SizedBox(height: 16),
                                
                                // Section: Mes groupes
                                _buildMyGroupsSection(),
                                const SizedBox(height: 16),
                                
                                // Section: Découvrir
                                _buildDiscoverSection(),
                                const SizedBox(height: 16),
                                
                                // Section: Toutes les balades
                                _buildAllRidesSection(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: _buildQuickActions(),
    );
  }

  Widget _buildHeader(User? user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.3),
                backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                    ? NetworkImage(_getAvatarUrl(user.avatarUrl!))
                    : null,
                onBackgroundImageError: (exception, stackTrace) {
                  // En cas d'erreur de chargement, afficher l'initiale
                  debugPrint('Erreur de chargement de l\'avatar: $exception');
                },
                child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                    ? Text(
                        user != null && user.displayName.isNotEmpty
                            ? user.displayName.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Message de bienvenue
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_getGreeting()}, ${user?.displayName ?? "Utilisateur"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getSecondaryMessage(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Badge véhicule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getVehicleBadgeColor(user?.vehiclePreference).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getVehicleBadgeText(user?.vehiclePreference),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextRideSection() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'Ma prochaine balade',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_nextRide != null)
            _buildNextRideCard(_nextRide!)
          else
            _buildNoNextRideCard(),
        ],
      ),
    );
  }

  Widget _buildNextRideCard(Ride ride) {
    final dateTime = DateTime(
      ride.date.year,
      ride.date.month,
      ride.date.day,
      int.parse(ride.heure.split(':')[0]),
      int.parse(ride.heure.split(':')[1]),
    );
    final dateFormat = DateFormat('EEEE d MMMM', 'fr_FR');
    final timeFormat = DateFormat('HH:mm');

    final locationText = _getLocationText(ride);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        Text(
          ride.titre,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Date et heure
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              '${dateFormat.format(dateTime)} à ${timeFormat.format(dateTime)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Lieu de départ
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                locationText,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Participants
        Row(
          children: [
            Icon(Icons.people, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              '${ride.participants.length} participant${ride.participants.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Boutons d'action
        Column(
          children: [
            // Bouton Naviguer (pleine largeur, mis en évidence)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (ride.waypoints != null && ride.waypoints!.isNotEmpty) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => NavigationAppSelector(
                        waypoints: ride.waypoints!,
                        rideId: ride.id,
                        rideName: ride.titre,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Aucun trajet configuré pour cette balade'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.navigation, size: 20),
                label: const Text(
                  'Naviguer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Boutons secondaires
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RideDetailScreen(rideId: ride.id),
                        ),
                      ).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Voir la balade'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Trouver le groupe associé à la balade ou créer une conversation
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RideDetailScreen(rideId: ride.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoNextRideCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy,
            size: 48,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            'Aucune balade prévue pour le moment',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateRideWithMapScreen(),
                ),
              ).then((_) => _loadData());
            },
            icon: const Icon(Icons.search),
            label: const Text('Rechercher une balade'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyGroupsSection() {
    if (_myGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.group, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'Mes groupes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GroupsScreen(),
                    ),
                  );
                },
                child: const Text('Voir tout'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._myGroups.map((group) => _buildGroupCard(group)),
        ],
      ),
    );
  }

  Widget _buildGroupCard(Group group) {
    final isPublic = group.visibilite == 'publique';
    // Indicateur d'activité : groupe actif s'il a plusieurs membres
    // TODO: Implémenter la vérification de nouveaux messages et d'activité récente
    final isActive = group.membres.length > 1;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(groupId: group.id),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icône groupe avec indicateur d'activité
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (isPublic ? Colors.green : Colors.orange).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPublic ? Icons.public : Icons.lock,
                      color: isPublic ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Infos groupe
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.nom,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Actif',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group.membres.length} membre${group.membres.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isPublic ? Colors.green : Colors.orange).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPublic ? 'Public' : 'Privé',
                            style: TextStyle(
                              fontSize: 10,
                              color: isPublic ? Colors.green.shade700 : Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverSection() {
    if (_suggestedRides.isEmpty) {
      return const SizedBox.shrink();
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.explore, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'Découvrir',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // Scroll vers la section "Toutes les balades"
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: const Text('Voir plus'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._suggestedRides.map((ride) => _buildSuggestedRideCard(ride)),
        ],
      ),
    );
  }

  Widget _buildSuggestedRideCard(Ride ride) {
    final dateTime = DateTime(
      ride.date.year,
      ride.date.month,
      ride.date.day,
      int.parse(ride.heure.split(':')[0]),
      int.parse(ride.heure.split(':')[1]),
    );
    final dateFormat = DateFormat('d MMM', 'fr_FR');

    final locationText = _getLocationText(ride);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RideDetailScreen(rideId: ride.id),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icône type véhicule
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (ride.typeVehicule == 'moto' ? Colors.orange : Colors.blue).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  ride.typeVehicule == 'moto' ? Icons.motorcycle : Icons.directions_car,
                  color: ride.typeVehicule == 'moto' ? Colors.orange.shade700 : Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Infos balade
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.titre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(dateTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Bouton voir
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideDetailScreen(rideId: ride.id),
                    ),
                  ).then((_) => _loadData());
                },
                child: const Text('Voir'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllRidesSection() {
    if (_allRides.isEmpty) {
      return const SizedBox.shrink();
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              const Text(
                'Toutes les balades',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._allRides.take(5).map((ride) => _RideCard(
                ride: ride,
                isLiked: _likesState[ride.id] ?? false,
                totalLikes: _likesCount[ride.id] ?? 0,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideDetailScreen(rideId: ride.id),
                    ),
                  ).then((_) => _loadData());
                },
                onLikeTap: (newLikeState) => _toggleLike(ride.id, newLikeState),
              )),
          if (_allRides.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // Scroll vers le bas pour voir plus
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  child: Text(
                    'Voir ${_allRides.length - 5} balade${_allRides.length - 5 > 1 ? 's' : ''} de plus',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return FloatingActionButton.extended(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Que veux-tu faire ?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                _buildQuickActionButton(
                  icon: Icons.add_location_alt,
                  label: 'Créer une balade',
                  color: Colors.blue.shade700,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateRideWithMapScreen(),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionButton(
                  icon: Icons.group_add,
                  label: 'Créer un groupe',
                  color: Colors.purple.shade700,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateGroupScreen(),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionButton(
                  icon: Icons.search,
                  label: 'Rechercher une balade',
                  color: Colors.green.shade700,
                  onTap: () {
                    Navigator.pop(context);
                    // Scroll vers la section "Toutes les balades"
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
      icon: const Icon(Icons.add),
      label: const Text('Actions rapides'),
      backgroundColor: Colors.blue.shade700,
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

// Widget pour les cards avec effet glassmorphism
class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Card pour les balades (réutilisée depuis l'ancien code)
class _RideCard extends StatelessWidget {
  final Ride ride;
  final VoidCallback onTap;
  final bool isLiked;
  final int totalLikes;
  final Function(bool) onLikeTap;

  const _RideCard({
    required this.ride,
    required this.onTap,
    required this.isLiked,
    required this.totalLikes,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateTime = DateTime(
      ride.date.year,
      ride.date.month,
      ride.date.day,
      int.parse(ride.heure.split(':')[0]),
      int.parse(ride.heure.split(':')[1]),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ride.titre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ride.typeVehicule == 'moto'
                          ? Colors.orange.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ride.typeVehicule == 'moto' ? '🏍️ Moto' : '🚗 Voiture',
                      style: TextStyle(
                        fontSize: 11,
                        color: ride.typeVehicule == 'moto'
                            ? Colors.orange.shade900
                            : Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (ride.description != null && ride.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ride.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              // Prévisualisation du trajet (plus petite)
              SizedBox(
                height: 100,
                child: RideRoutePreview(ride: ride, height: 100),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${ride.heure}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.participants.length} participant${ride.participants.length > 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const Spacer(),
                  if (ride.noteMoyenne > 0) ...[
                    Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      ride.noteMoyenne.toStringAsFixed(1),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  LikeButton(
                    isLiked: isLiked,
                    totalLikes: totalLikes,
                    onTap: onLikeTap,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
