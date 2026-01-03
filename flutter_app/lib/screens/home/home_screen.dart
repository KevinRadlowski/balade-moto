import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/navigation_state.dart';
import '../../models/ride.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../widgets/like_button.dart';
import '../../widgets/ride_route_preview.dart';
import '../../utils/background_helper.dart';
import '../../config/api_config.dart';
import '../../constants/home_style_constants.dart';
import '../../widgets/home/home_hero_header.dart';
import '../../widgets/home/next_ride_card.dart';
import '../../widgets/home/favorite_groups_card.dart';
import '../../widgets/home/discover_preview_card.dart';
import '../../widgets/home/quick_actions_fab.dart';
import '../ride/ride_detail_screen.dart';
import '../groups/groups_screen.dart';

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
    if (!mounted) return;
    
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

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
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

  /// Compte le nombre de balades à venir pour le micro-signal
  int? _getUpcomingRidesCount() {
    // On pourrait charger toutes les balades à venir, mais pour l'instant
    // on retourne null si on n'a pas cette info chargée
    // TODO: Charger le count depuis l'API si nécessaire
    return null;
  }

  Future<void> _loadMyGroups() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.user?.id;
      
      // Ne charger que les groupes dont l'utilisateur est membre
      if (userId == null) {
        if (mounted) {
          setState(() {
            _myGroups = [];
          });
        }
        return;
      }
      
      // Utiliser le paramètre 'membre' pour ne récupérer que les groupes où l'utilisateur est membre
      final groupsData = await _apiService.getGroups(membre: userId);
      final groups = groupsData.map((g) {
        final group = Group.fromJson(g);
        // Si le backend ne fournit pas unreadCount/lastMessageAt, simuler temporairement
        // TODO: Retirer cette simulation quand le backend sera prêt
        if (group.unreadCount == null && group.lastMessageAt == null) {
          // Simuler des données mockées pour la démo
          // En production, ces données viendront du backend
          return Group(
            id: group.id,
            nom: group.nom,
            description: group.description,
            visibilite: group.visibilite,
            createur: group.createur,
            membres: group.membres,
            bannedUsers: group.bannedUsers,
            // Mock: simuler un groupe avec 2 messages non lus
            unreadCount: group.membres.length > 1 ? 2 : 0,
            // Mock: simuler un dernier message il y a 30 minutes
            lastMessageAt: group.membres.length > 1 
                ? DateTime.now().subtract(const Duration(minutes: 30))
                : null,
          );
        }
        return group;
      }).toList();
      
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

      // Limiter à 2 éléments maximum pour la section Découvrir
      if (mounted) {
        setState(() {
          _suggestedRides = filteredRides.take(2).toList();
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
    if (!mounted) return;
    
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
                        // Hero Header (25-30% de l'écran, réduit sur petits écrans)
                        SliverAppBar(
                          expandedHeight: () {
                            final screenHeight = MediaQuery.of(context).size.height;
                            if (screenHeight < 650) {
                              return screenHeight * 0.18; // 18% sur très petits écrans (Xiaomi) - encore plus réduit
                            } else if (screenHeight < 700) {
                              return screenHeight * 0.23; // 23% sur petits écrans
                            } else {
                              return screenHeight * 0.28; // 28% sur grands écrans
                            }
                          }(),
                          floating: false,
                          pinned: false, // Ne pas épingler pour un effet plus immersif
                          snap: false,
                          backgroundColor: Colors.transparent,
                          flexibleSpace: FlexibleSpaceBar(
                            stretchModes: const [
                              StretchMode.zoomBackground,
                              StretchMode.blurBackground,
                            ],
                            background: HomeHeroHeader(
                              user: user,
                              secondaryMessage: _getSecondaryMessage(),
                              nextRide: _nextRide,
                              groups: _myGroups,
                              upcomingRidesCount: _getUpcomingRidesCount(),
                            ),
                          ),
                        ),
                        // Contenu scrollable
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Espacement clair après le hero header
                                const SizedBox(height: 24),
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
                                // Padding pour éviter le chevauchement avec le FAB
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: QuickActionsFab(
        scrollController: _scrollController,
      ),
    );
  }


  Widget _buildNextRideSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: HomeStyleConstants.cardPadding,
      decoration: HomeStyleConstants.glassCardDecoration,
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
            NextRideCard(
              ride: _nextRide!,
              locationText: _getLocationText(_nextRide!),
              onDataReload: _loadData,
            )
          else
            _buildNoNextRideCard(),
        ],
      ),
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
              // Ouvrir l'onglet "Balades" (index 1) au lieu de CreateRideWithMapScreen
              final navigationState = Provider.of<NavigationState>(context, listen: false);
              navigationState.setIndex(1);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: HomeStyleConstants.cardPadding,
      decoration: HomeStyleConstants.glassCardDecoration,
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
          ..._myGroups.map((group) => FavoriteGroupsCard(
                group: group,
                onDataReload: _loadData,
              )),
        ],
      ),
    );
  }


  Widget _buildDiscoverSection() {
    if (_suggestedRides.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: HomeStyleConstants.cardPadding,
      decoration: HomeStyleConstants.glassCardDecoration,
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
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: const Text('Voir plus'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._suggestedRides.map((ride) => DiscoverPreviewCard(
                ride: ride,
                locationText: _getLocationText(ride),
                onDataReload: _loadData,
              )),
        ],
      ),
    );
  }


  Widget _buildAllRidesSection() {
    if (_allRides.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: HomeStyleConstants.cardPadding,
      decoration: HomeStyleConstants.glassCardDecoration,
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
