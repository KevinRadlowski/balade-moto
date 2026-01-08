import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/ride.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../utils/background_helper.dart';
import '../../config/api_config.dart';
import '../../widgets/home/home_community_header.dart';
import '../../widgets/home/next_ride_section.dart';
import '../../widgets/home/discover_rides_section.dart';
import '../../widgets/home/active_groups_section.dart';
import '../../widgets/home/quick_actions_fab.dart';
import '../../services/navigation_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
  
  // Méthode statique pour rafraîchir l'écran depuis l'extérieur
  static void refresh(BuildContext? context) {
    if (context != null) {
      final state = context.findAncestorStateOfType<_HomeScreenState>();
      state?.refresh();
    }
  }
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  // Données
  Ride? _nextRide;
  List<Group> _myGroups = [];
  List<Group> _allGroups = []; // Tous les groupes pour les statistiques
  List<Ride> _suggestedRides = [];
  bool _isLoading = true;
  String? _errorMessage;
  Position? _userPosition;
  
  // Statistiques communautaires
  int _ridesThisMonth = 0;
  int _activeGroups = 0;

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

  // Méthode publique pour rafraîchir les données
  Future<void> refresh() async {
    await _loadData();
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

      // Charger la position de l'utilisateur d'abord (nécessaire pour les suggestions de balades proches)
      await _loadUserPosition();

      // Charger toutes les données en parallèle
      await Future.wait([
        _loadNextRide(user?.id),
        _loadMyGroups(),
        _loadAllGroups(), // Charger tous les groupes pour les statistiques
        _loadSuggestedRides(user), // Utilisera la position si disponible
      ]);

      // Calculer les statistiques après avoir chargé les données
      _calculateCommunityStats();

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

  /// Charge tous les groupes pour les statistiques communautaires
  Future<void> _loadAllGroups() async {
    try {
      // Charger tous les groupes (sans filtre membre) pour les statistiques
      final groupsData = await _apiService.getGroups();
      final groups = groupsData.map((g) => Group.fromJson(g)).toList();
      
      if (mounted) {
        setState(() {
          _allGroups = groups;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de tous les groupes: $e');
    }
  }

  Future<void> _loadSuggestedRides(User? user) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.user?.id;
      
      List<Ride> allRides;
      
      // Si la position GPS est disponible, utiliser getRidesNearby pour obtenir les balades les plus proches
      if (_userPosition != null) {
        allRides = await _apiService.getRidesNearby(
          latitude: _userPosition!.latitude,
          longitude: _userPosition!.longitude,
          rayon: 50, // Rayon de 50 km
          typeVehicule: user?.vehiclePreference == 'les deux' ? null : user?.vehiclePreference,
          limit: 20, // Charger plus pour filtrer
        );
      } else {
        // Sinon, charger les balades publiques récentes normalement
        allRides = await _apiService.getRides(
          typeVehicule: user?.vehiclePreference == 'les deux' ? null : user?.vehiclePreference,
          limit: 20, // Charger plus pour filtrer
        );
      }

      // Filtrer pour ne garder que les balades où l'utilisateur n'a pas participé
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

  /// Calcule les statistiques communautaires à partir des données disponibles
  Future<void> _calculateCommunityStats() async {
    try {
      // Compter tous les groupes créés dans l'application (pas seulement ceux dont l'utilisateur est membre)
      final activeGroups = _allGroups.length;
      
      // Pour les balades de ce mois, on pourrait charger les données séparément si nécessaire
      // Pour l'instant, on met 0 car on ne charge plus _allRides
      if (mounted) {
        setState(() {
          _ridesThisMonth = 0; // Ne sera plus calculé ici car on ne charge plus toutes les balades
          _activeGroups = activeGroups;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du calcul des statistiques: $e');
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
                        // Community Hero Header (agrandi d'au moins 300px)
                        SliverAppBar(
                          expandedHeight: () {
                            final screenHeight = MediaQuery.of(context).size.height;
                            final baseHeight = screenHeight < 650
                                ? screenHeight * 0.22
                                : screenHeight < 700
                                    ? screenHeight * 0.26
                                    : screenHeight * 0.30;
                            // Ajouter au moins 300px
                            return baseHeight + 300;
                          }(),
                          floating: false,
                          pinned: false,
                          snap: false,
                          backgroundColor: Colors.transparent,
                          flexibleSpace: FlexibleSpaceBar(
                            stretchModes: const [
                              StretchMode.zoomBackground,
                              StretchMode.blurBackground,
                            ],
                            background: HomeCommunityHeader(
                              user: user,
                              ridesThisMonth: _ridesThisMonth,
                              activeGroups: _activeGroups,
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
                                // Espacement après le header
                                const SizedBox(height: 8),
                                
                                // Section: Ma prochaine balade
                                NextRideSection(
                                  nextRide: _nextRide,
                                  getLocationText: _getLocationText,
                                  onDataReload: _loadData,
                                ),
                                const SizedBox(height: 16),
                                
                                // Section: Groupes actifs
                                ActiveGroupsSection(
                                  groups: _myGroups,
                                  onDataReload: _loadData,
                                ),
                                const SizedBox(height: 16),
                                
                                // Section: Découvrir (améliorée)
                                DiscoverRidesSection(
                                  rides: _suggestedRides,
                                  getLocationText: _getLocationText,
                                  onDataReload: _loadData,
                                  onSeeMore: () {
                                    // Rediriger vers la page balades (index 1 dans MainNavigation)
                                    final navigationState = Provider.of<NavigationState>(context, listen: false);
                                    navigationState.setIndex(1);
                                  },
                                ),
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





}


