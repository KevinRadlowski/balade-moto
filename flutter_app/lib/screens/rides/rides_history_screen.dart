import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/ride.dart';
import '../../widgets/like_button.dart';
import '../../widgets/ride_route_preview.dart';
import '../../widgets/rides/ride_filters_chips.dart';
import '../../utils/background_helper.dart';
import '../../config/api_config.dart';
import '../ride/ride_detail_screen.dart';
import '../ride/create_ride_with_map_screen.dart';
import 'review_ride_dialog.dart';

class RidesHistoryScreen extends StatefulWidget {
  const RidesHistoryScreen({super.key});

  @override
  State<RidesHistoryScreen> createState() => _RidesHistoryScreenState();
}

class _RidesHistoryScreenState extends State<RidesHistoryScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  List<Ride> _upcomingRides = [];
  List<Ride> _pastRides = [];
  List<Ride> _myPastRides = [];
  
  bool _isLoadingUpcoming = true;
  bool _isLoadingPast = true;
  bool _isLoadingMyPast = true;
  
  String? _errorUpcoming;
  String? _errorPast;
  String? _errorMyPast;
  
  // Map pour stocker l'état des likes par balade
  final Map<String, bool> _likesState = {};
  final Map<String, int> _likesCount = {};
  
  // Filtres pour l'onglet "À venir"
  String? _upcomingTypeVehicule;
  String? _upcomingDateDebut;
  String? _upcomingDateFin;
  String? _upcomingSearch;
  double? _upcomingLatitude;
  double? _upcomingLongitude;
  double? _upcomingRayon;
  String _upcomingSortBy = 'date';
  String _upcomingSortOrder = 'asc';
  
  // Filtres pour l'onglet "Passées"
  String? _pastTypeVehicule;
  String? _pastVisibilite;
  String? _pastDateDebut;
  String? _pastDateFin;
  String? _pastSearch;
  double? _pastLatitude;
  double? _pastLongitude;
  double? _pastRayon;
  String _pastSortBy = 'date';
  String _pastSortOrder = 'desc';
  
  // Filtres pour l'onglet "Mes balades"
  String? _myPastTypeVehicule;
  String? _myPastDateDebut;
  String? _myPastDateFin;
  String? _myPastSearch;
  double? _myPastLatitude;
  double? _myPastLongitude;
  double? _myPastRayon;
  String _myPastSortBy = 'date';
  String _myPastSortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    await Future.wait([
      _loadUpcomingRides(),
      _loadPastRides(),
      _loadMyPastRides(),
    ]);
  }

  Future<void> _loadUpcomingRides() async {
    setState(() {
      _isLoadingUpcoming = true;
      _errorUpcoming = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final now = DateTime.now();
      final rides = await _apiService.getRides(
        typeVehicule: _upcomingTypeVehicule,
        dateDebut: _upcomingDateDebut ?? now.toIso8601String(),
        dateFin: _upcomingDateFin,
        search: _upcomingSearch,
        latitude: _upcomingLatitude,
        longitude: _upcomingLongitude,
        rayon: _upcomingRayon,
        sortBy: _upcomingSortBy,
        sortOrder: _upcomingSortOrder,
      );

      // Initialiser l'état des likes
      final likesState = <String, bool>{};
      final likesCount = <String, int>{};
      for (final ride in rides) {
        likesState[ride.id] = ride.hasUserLiked ?? false;
        likesCount[ride.id] = ride.totalLikes ?? ride.likes.length;
      }

      setState(() {
        _upcomingRides = rides;
        _likesState.addAll(likesState);
        _likesCount.addAll(likesCount);
        _isLoadingUpcoming = false;
      });
    } catch (e) {
      setState(() {
        _errorUpcoming = e.toString();
        _isLoadingUpcoming = false;
      });
    }
  }

  Future<void> _loadPastRides() async {
    setState(() {
      _isLoadingPast = true;
      _errorPast = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final now = DateTime.now();
      // Utiliser getRides avec dateFin pour les balades passées
      final rides = await _apiService.getRides(
        typeVehicule: _pastTypeVehicule,
        dateFin: _pastDateFin ?? now.toIso8601String(),
        dateDebut: _pastDateDebut,
        search: _pastSearch,
        latitude: _pastLatitude,
        longitude: _pastLongitude,
        rayon: _pastRayon,
        sortBy: _pastSortBy,
        sortOrder: _pastSortOrder,
      );

      // Initialiser l'état des likes
      final likesState = <String, bool>{};
      final likesCount = <String, int>{};
      for (final ride in rides) {
        likesState[ride.id] = ride.hasUserLiked ?? false;
        likesCount[ride.id] = ride.totalLikes ?? ride.likes.length;
      }

      setState(() {
        _pastRides = rides;
        _likesState.addAll(likesState);
        _likesCount.addAll(likesCount);
        _isLoadingPast = false;
      });
    } catch (e) {
      setState(() {
        _errorPast = e.toString();
        _isLoadingPast = false;
      });
    }
  }

  Future<void> _loadMyPastRides() async {
    setState(() {
      _isLoadingMyPast = true;
      _errorMyPast = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final now = DateTime.now();
      // Utiliser getRides avec participant pour mes balades passées
      final userId = authService.user?.id;
      
      final rides = await _apiService.getRides(
        typeVehicule: _myPastTypeVehicule,
        dateFin: _myPastDateFin ?? now.toIso8601String(),
        dateDebut: _myPastDateDebut,
        search: _myPastSearch,
        latitude: _myPastLatitude,
        longitude: _myPastLongitude,
        rayon: _myPastRayon,
        participant: userId,
        sortBy: _myPastSortBy,
        sortOrder: _myPastSortOrder,
      );

      // Initialiser l'état des likes
      final likesState = <String, bool>{};
      final likesCount = <String, int>{};
      for (final ride in rides) {
        likesState[ride.id] = ride.hasUserLiked ?? false;
        likesCount[ride.id] = ride.totalLikes ?? ride.likes.length;
      }

      setState(() {
        _myPastRides = rides;
        _likesState.addAll(likesState);
        _likesCount.addAll(likesCount);
        _isLoadingMyPast = false;
      });
    } catch (e) {
      setState(() {
        _errorMyPast = e.toString();
        _isLoadingMyPast = false;
      });
    }
  }

  Future<void> _duplicateRide(Ride ride) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateRideWithMapScreen(
          duplicateRide: ride,
        ),
      ),
    );
    
    if (result == true && mounted) {
      _loadRides();
    }
  }

  Future<void> _toggleLike(String rideId, bool newLikeState) async {
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
    final customBaladeBackground = user?.customBackgrounds?['balade'];
    final globalBackground = user?.customBackgrounds?['global'];
    final backgroundImage = (customBaladeBackground != null && customBaladeBackground.isNotEmpty)
        ? customBaladeBackground
        : (globalBackground != null && globalBackground.isNotEmpty)
            ? globalBackground
            : getBaladeBackgroundImageName(user?.vehiclePreference);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Balades'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/images/logo.png',
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // Texte blanc pour l'onglet actif
          unselectedLabelColor: Colors.white70, // Texte blanc semi-transparent pour les onglets inactifs
          indicatorColor: Colors.white, // Indicateur blanc sous l'onglet actif
          tabs: const [
            Tab(text: 'À venir'),
            Tab(text: 'Passées'),
            Tab(text: 'Mes balades'),
          ],
        ),
      ),
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
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildUpcomingRidesTab(),
            _buildPastRidesTab(),
            _buildMyPastRidesTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateRideWithMapScreen(),
            ),
          ).then((result) {
            if (result == true) {
              _loadRides();
            }
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Créer une balade'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildUpcomingRidesTab() {
    return Column(
      children: [
        RideFiltersChips(
          typeVehicule: _upcomingTypeVehicule,
          visibilite: null,
          dateDebut: _upcomingDateDebut,
          dateFin: _upcomingDateFin,
          search: _upcomingSearch,
          latitude: _upcomingLatitude,
          longitude: _upcomingLongitude,
          rayon: _upcomingRayon,
          sortBy: _upcomingSortBy,
          sortOrder: _upcomingSortOrder,
          showVisibilite: false,
          onTypeVehiculeChanged: (value) {
            setState(() {
              _upcomingTypeVehicule = value;
            });
            _loadUpcomingRides();
          },
          onVisibiliteChanged: (value) {
            // Non utilisé pour "À venir"
          },
          onDateDebutChanged: (value) {
            setState(() {
              _upcomingDateDebut = value;
            });
            _loadUpcomingRides();
          },
          onDateFinChanged: (value) {
            setState(() {
              _upcomingDateFin = value;
            });
            _loadUpcomingRides();
          },
          onSearchChanged: (value) {
            setState(() {
              _upcomingSearch = value;
            });
            _loadUpcomingRides();
          },
          onLocationChanged: (lat, lng, rayon) {
            setState(() {
              _upcomingLatitude = lat;
              _upcomingLongitude = lng;
              _upcomingRayon = rayon;
            });
            _loadUpcomingRides();
          },
          onSortChanged: (sortBy, sortOrder) {
            setState(() {
              _upcomingSortBy = sortBy;
              _upcomingSortOrder = sortOrder;
            });
            _loadUpcomingRides();
          },
          onClearFilters: () {
            setState(() {
              _upcomingTypeVehicule = null;
              _upcomingDateDebut = null;
              _upcomingDateFin = null;
              _upcomingSearch = null;
              _upcomingLatitude = null;
              _upcomingLongitude = null;
              _upcomingRayon = null;
              _upcomingSortBy = 'date';
              _upcomingSortOrder = 'asc';
            });
            _loadUpcomingRides();
          },
        ),
        Expanded(
          child: _isLoadingUpcoming
              ? const Center(child: CircularProgressIndicator())
              : _errorUpcoming != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Erreur: $_errorUpcoming'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadUpcomingRides,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : _upcomingRides.isEmpty
                      ? const Center(
                          child: Text('Aucune balade à venir'),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadUpcomingRides,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _upcomingRides.length,
                            itemBuilder: (context, index) {
                              final ride = _upcomingRides[index];
                              return _RideCard(
                                ride: ride,
                                isLiked: _likesState[ride.id] ?? false,
                                totalLikes: _likesCount[ride.id] ?? 0,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RideDetailScreen(rideId: ride.id),
                                    ),
                                  ).then((_) {
                                    _loadUpcomingRides();
                                  });
                                },
                                onLikeTap: (newLikeState) => _toggleLike(ride.id, newLikeState),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildPastRidesTab() {
    return Column(
      children: [
        RideFiltersChips(
          typeVehicule: _pastTypeVehicule,
          visibilite: _pastVisibilite,
          dateDebut: _pastDateDebut,
          dateFin: _pastDateFin,
          search: _pastSearch,
          sortBy: _pastSortBy,
          sortOrder: _pastSortOrder,
          showVisibilite: true,
          onTypeVehiculeChanged: (value) {
            setState(() {
              _pastTypeVehicule = value;
            });
            _loadPastRides();
          },
          onVisibiliteChanged: (value) {
            setState(() {
              _pastVisibilite = value;
            });
            _loadPastRides();
          },
          onDateDebutChanged: (value) {
            setState(() {
              _pastDateDebut = value;
            });
            _loadPastRides();
          },
          onDateFinChanged: (value) {
            setState(() {
              _pastDateFin = value;
            });
            _loadPastRides();
          },
          onSearchChanged: (value) {
            setState(() {
              _pastSearch = value;
            });
            _loadPastRides();
          },
          onLocationChanged: (lat, lng, rayon) {
            setState(() {
              _pastLatitude = lat;
              _pastLongitude = lng;
              _pastRayon = rayon;
            });
            _loadPastRides();
          },
          onSortChanged: (sortBy, sortOrder) {
            setState(() {
              _pastSortBy = sortBy;
              _pastSortOrder = sortOrder;
            });
            _loadPastRides();
          },
          onClearFilters: () {
            setState(() {
              _pastTypeVehicule = null;
              _pastVisibilite = null;
              _pastDateDebut = null;
              _pastDateFin = null;
              _pastSearch = null;
              _pastLatitude = null;
              _pastLongitude = null;
              _pastRayon = null;
              _pastSortBy = 'date';
              _pastSortOrder = 'desc';
            });
            _loadPastRides();
          },
        ),
        Expanded(
          child: _isLoadingPast
              ? const Center(child: CircularProgressIndicator())
              : _errorPast != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Erreur: $_errorPast'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadPastRides,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : _pastRides.isEmpty
                      ? const Center(
                          child: Text('Aucune balade passée'),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadPastRides,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pastRides.length,
                            itemBuilder: (context, index) {
                              final ride = _pastRides[index];
                              return _RideCard(
                                ride: ride,
                                isLiked: _likesState[ride.id] ?? false,
                                totalLikes: _likesCount[ride.id] ?? 0,
                                showDuplicate: true,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RideDetailScreen(rideId: ride.id),
                                    ),
                                  ).then((_) {
                                    _loadPastRides();
                                  });
                                },
                                onLikeTap: (newLikeState) => _toggleLike(ride.id, newLikeState),
                                onDuplicate: () => _duplicateRide(ride),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildMyPastRidesTab() {
    return Column(
      children: [
        RideFiltersChips(
          typeVehicule: _myPastTypeVehicule,
          dateDebut: _myPastDateDebut,
          dateFin: _myPastDateFin,
          search: _myPastSearch,
          latitude: _myPastLatitude,
          longitude: _myPastLongitude,
          rayon: _myPastRayon,
          sortBy: _myPastSortBy,
          sortOrder: _myPastSortOrder,
          showVisibilite: false,
          onTypeVehiculeChanged: (value) {
            setState(() {
              _myPastTypeVehicule = value;
            });
            _loadMyPastRides();
          },
          onVisibiliteChanged: (value) {
            // Non utilisé pour "Mes balades"
          },
          onDateDebutChanged: (value) {
            setState(() {
              _myPastDateDebut = value;
            });
            _loadMyPastRides();
          },
          onDateFinChanged: (value) {
            setState(() {
              _myPastDateFin = value;
            });
            _loadMyPastRides();
          },
          onSearchChanged: (value) {
            setState(() {
              _myPastSearch = value;
            });
            _loadMyPastRides();
          },
          onLocationChanged: (lat, lng, rayon) {
            setState(() {
              _myPastLatitude = lat;
              _myPastLongitude = lng;
              _myPastRayon = rayon;
            });
            _loadMyPastRides();
          },
          onSortChanged: (sortBy, sortOrder) {
            setState(() {
              _myPastSortBy = sortBy;
              _myPastSortOrder = sortOrder;
            });
            _loadMyPastRides();
          },
          onClearFilters: () {
            setState(() {
              _myPastTypeVehicule = null;
              _myPastDateDebut = null;
              _myPastDateFin = null;
              _myPastSearch = null;
              _myPastLatitude = null;
              _myPastLongitude = null;
              _myPastRayon = null;
              _myPastSortBy = 'date';
              _myPastSortOrder = 'desc';
            });
            _loadMyPastRides();
          },
        ),
        Expanded(
          child: _isLoadingMyPast
              ? const Center(child: CircularProgressIndicator())
              : _errorMyPast != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Erreur: $_errorMyPast'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadMyPastRides,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : _myPastRides.isEmpty
                      ? const Center(
                          child: Text('Aucune balade passée à laquelle vous avez participé'),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadMyPastRides,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _myPastRides.length,
                            itemBuilder: (context, index) {
                              final ride = _myPastRides[index];
                              return _RideCard(
                                ride: ride,
                                isLiked: _likesState[ride.id] ?? false,
                                totalLikes: _likesCount[ride.id] ?? 0,
                                showDuplicate: true,
                                showReview: true,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RideDetailScreen(rideId: ride.id),
                                    ),
                                  ).then((_) {
                                    _loadMyPastRides();
                                  });
                                },
                                onLikeTap: (newLikeState) => _toggleLike(ride.id, newLikeState),
                                onDuplicate: () => _duplicateRide(ride),
                                onReview: () async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => ReviewRideDialog(
                                      rideId: ride.id,
                                    ),
                                  );
                                  
                                  if (result == true && mounted) {
                                    _loadMyPastRides();
                                  }
                                },
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }


}

class _RideCard extends StatelessWidget {
  final Ride ride;
  final VoidCallback onTap;
  final bool isLiked;
  final int totalLikes;
  final Function(bool) onLikeTap;
  final bool showDuplicate;
  final VoidCallback? onDuplicate;
  final bool showReview;
  final VoidCallback? onReview;

  const _RideCard({
    required this.ride,
    required this.onTap,
    required this.isLiked,
    required this.totalLikes,
    required this.onLikeTap,
    this.showDuplicate = false,
    this.onDuplicate,
    this.showReview = false,
    this.onReview,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Colors.white.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ride.titre,
                      style: const TextStyle(
                        fontSize: 20,
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
                        fontSize: 12,
                        color: ride.typeVehicule == 'moto'
                            ? Colors.orange.shade900
                            : Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (showDuplicate && onDuplicate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: onDuplicate,
                      tooltip: 'Dupliquer cette balade',
                      iconSize: 20,
                    ),
                  ],
                ],
              ),
              if (ride.description != null && ride.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ride.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 12),
              RideRoutePreview(ride: ride, height: 150),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${ride.heure}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ride.waypoints != null && ride.waypoints!.isNotEmpty
                          ? '${ride.waypoints!.length} point${ride.waypoints!.length > 1 ? 's' : ''} de passage'
                          : (ride.lieuDepart is String
                              ? ride.lieuDepart as String
                              : 'Lieu de départ'),
                      style: TextStyle(color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.participants.length} participant${ride.participants.length > 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  if (ride.noteMoyenne > 0) ...[
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      ride.noteMoyenne.toStringAsFixed(1),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  LikeButton(
                    isLiked: isLiked,
                    totalLikes: totalLikes,
                    onTap: onLikeTap,
                    size: 20,
                  ),
                ],
              ),
              if (showReview && onReview != null) ...[
                const SizedBox(height: 12),
                FutureBuilder<Map<String, dynamic>>(
                  future: _checkUserReview(context, ride.id),
                  builder: (context, snapshot) {
                    final hasReviewed = snapshot.data?['hasReviewed'] ?? false;
                    final existingReview = snapshot.data?['review'];
                    
                    return ElevatedButton.icon(
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => ReviewRideDialog(
                            rideId: ride.id,
                            existingRating: existingReview?['rating'],
                            existingComment: existingReview?['comment'],
                          ),
                        );
                        
                        if (result == true && context.mounted && onReview != null) {
                          onReview!();
                        }
                      },
                      icon: Icon(
                        hasReviewed ? Icons.edit : Icons.star,
                        size: 18,
                      ),
                      label: Text(hasReviewed ? 'Modifier ma note' : 'Noter et commenter'),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _checkUserReview(BuildContext context, String rideId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService();
      final token = await authService.storage.read(key: 'token');
      apiService.setToken(token);
      final result = await apiService.hasUserReviewed(rideId);
      return result['data'] ?? {'hasReviewed': false};
    } catch (e) {
      return {'hasReviewed': false};
    }
  }
}

