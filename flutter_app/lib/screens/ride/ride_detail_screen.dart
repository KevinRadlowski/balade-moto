import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/ride.dart';
import '../../models/waypoint.dart';
import '../../widgets/rating_form.dart';
import '../../widgets/average_rating_display.dart';
import '../../widgets/like_button.dart';
import '../../widgets/navigation/navigation_app_selector.dart';
import '../chat/ride_chat_screen.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;

  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  final ApiService _apiService = ApiService();
  Ride? _ride;
  bool _isLoading = true;
  bool _isParticipant = false;
  bool _isLiked = false;
  int _totalLikes = 0;
  bool _hasRated = false;
  bool _isSubmittingRating = false;
  String? _errorMessage;
  Map<String, dynamic>? _ratingsData;
  
  // Pour la carte
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isCalculatingRoute = false;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _loadRide();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('fr_FR', null);
  }

  Future<void> _loadRide() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final ride = await _apiService.getRideById(widget.rideId);
      
      // Vérifier si l'utilisateur a déjà noté
      bool hasRated = false;
      if (authService.user?.id != null) {
        try {
          hasRated = await _apiService.hasUserRatedRide(widget.rideId, authService.user!.id);
        } catch (e) {
          // Si erreur, on continue sans bloquer
          print('Erreur vérification note: $e');
        }
      }

      // Charger les notes pour afficher la moyenne et le nombre
      Map<String, dynamic>? ratingsData;
      try {
        ratingsData = await _apiService.getRatingsByRide(widget.rideId);
      } catch (e) {
        print('Erreur chargement notes: $e');
      }
      
      setState(() {
        _ride = ride;
        _isParticipant = ride.participants.any((p) => p.id == authService.user?.id);
        _isLiked = ride.hasUserLiked ?? ride.likes.contains(authService.user?.id);
        _totalLikes = ride.totalLikes ?? ride.likes.length;
        _hasRated = hasRated;
        _ratingsData = ratingsData;
        _isLoading = false;
      });
      
      // Charger le trajet sur la carte si des waypoints existent
      if (ride.waypoints != null && ride.waypoints!.isNotEmpty) {
        _loadRouteOnMap(ride.waypoints!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  bool get _isRidePast {
    if (_ride == null) return false;
    final rideDate = DateTime(
      _ride!.date.year,
      _ride!.date.month,
      _ride!.date.day,
      int.parse(_ride!.heure.split(':')[0]),
      int.parse(_ride!.heure.split(':')[1]),
    );
    return rideDate.isBefore(DateTime.now());
  }

  Future<void> _joinRide() async {
    if (_ride == null) return;

    try {
      await _apiService.joinRide(_ride!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous avez rejoint la balade !')),
        );
        _loadRide();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveRide() async {
    if (_ride == null) return;

    // Demander confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la balade'),
        content: const Text('Êtes-vous sûr de vouloir quitter cette balade ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.leaveRide(_ride!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous avez quitté la balade'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadRide();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleLike(bool newLikeState) async {
    if (_ride == null) return;

    // Mise à jour optimiste de l'UI
    setState(() {
      _isLiked = newLikeState;
      _totalLikes = newLikeState ? _totalLikes + 1 : _totalLikes - 1;
    });

    try {
      final response = await _apiService.toggleLike(_ride!.id);
      
      // Mettre à jour avec les vraies données du serveur
      if (mounted) {
        setState(() {
          _isLiked = response['data']?['isLiked'] ?? newLikeState;
          _totalLikes = response['data']?['totalLikes'] ?? _totalLikes;
        });
      }
    } catch (e) {
      // Revenir à l'état précédent en cas d'erreur
      if (mounted) {
        setState(() {
          _isLiked = !newLikeState;
          _totalLikes = newLikeState ? _totalLikes - 1 : _totalLikes + 1;
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

  Future<void> _submitRating(int rating, String? comment) async {
    if (_ride == null) return;

    setState(() {
      _isSubmittingRating = true;
    });

    try {
      await _apiService.createRating(
        balade: _ride!.id,
        note: rating,
        commentaire: comment,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Note envoyée avec succès !'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Recharger les données
        await _loadRide();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmittingRating = false;
        });
      }
    }
  }

  Future<void> _deleteRide() async {
    if (_ride == null) return;

    // Demander confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la balade'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette balade ? Cette action est irréversible et supprimera tous les messages associés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.deleteRide(_ride!.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balade supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Retourner à l'écran précédent
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la balade'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRide,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _ride == null
                  ? const Center(child: Text('Balade non trouvée'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _ride!.titre,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _ride!.typeVehicule == 'moto'
                                      ? Colors.orange.shade100
                                      : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _ride!.typeVehicule == 'moto' ? '🏍️ Moto' : '🚗 Voiture',
                                  style: TextStyle(
                                    color: _ride!.typeVehicule == 'moto'
                                        ? Colors.orange.shade900
                                        : Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_ride!.description != null && _ride!.description!.isNotEmpty)
                            Text(
                              _ride!.description!,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          const SizedBox(height: 24),
                          _InfoRow(
                            icon: Icons.calendar_today,
                            label: 'Date et heure',
                            value: _formatDateTime(_ride!.date, _ride!.heure),
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.location_on,
                            label: 'Lieu de départ',
                            value: _ride!.lieuDepart is String
                                ? _ride!.lieuDepart as String
                                : 'Lieu de départ',
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.place,
                            label: 'Lieu d\'arrivée',
                            value: _ride!.lieuArrivee is String
                                ? _ride!.lieuArrivee as String
                                : 'Lieu d\'arrivée',
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.radio_button_checked,
                            label: 'Rayon',
                            value: '${_ride!.rayon} km',
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.person,
                            label: 'Organisateur',
                            value: _ride!.organisateur.displayName,
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.people,
                            label: 'Participants',
                            value: '${_ride!.participants.length} participant${_ride!.participants.length > 1 ? 's' : ''}',
                          ),
                          // Afficher la carte avec le trajet si des waypoints existent
                          if (_ride!.waypoints != null && _ride!.waypoints!.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Itinéraire',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 300,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    GoogleMap(
                                      onMapCreated: (controller) {
                                        _mapController = controller;
                                        // Charger le trajet après la création de la carte
                                        if (_ride!.waypoints != null && _ride!.waypoints!.isNotEmpty) {
                                          _loadRouteOnMap(_ride!.waypoints!);
                                        }
                                      },
                                      initialCameraPosition: CameraPosition(
                                        target: _ride!.waypoints != null && _ride!.waypoints!.isNotEmpty
                                            ? LatLng(
                                                _ride!.waypoints!.first.latitude,
                                                _ride!.waypoints!.first.longitude,
                                              )
                                            : const LatLng(45.7640, 4.8357), // Lyon par défaut
                                        zoom: 12,
                                      ),
                                      markers: _markers,
                                      polylines: _polylines,
                                      mapType: MapType.normal,
                                      zoomControlsEnabled: false,
                                      myLocationButtonEnabled: false,
                                    ),
                                    if (_isCalculatingRoute)
                                      const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Affichage de la note moyenne
                          if (_ratingsData != null && 
                              (_ratingsData!['data']?['moyenne'] ?? 0) > 0) ...[
                            const SizedBox(height: 20),
                            AverageRatingDisplay(
                              averageRating: (_ratingsData!['data']?['moyenne'] ?? 0).toDouble(),
                              totalRatings: _ratingsData!['data']?['nombreNotes'] ?? 0,
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Formulaire de notation pour les balades passées
                          if (_isRidePast && _isParticipant && !_hasRated) ...[
                            RatingForm(
                              onSubmit: _submitRating,
                              isLoading: _isSubmittingRating,
                            ),
                            const SizedBox(height: 24),
                          ] else if (_isRidePast && _isParticipant && _hasRated) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Vous avez déjà noté cette balade',
                                      style: TextStyle(
                                        color: Colors.green.shade900,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Message si l'utilisateur a liké
                          if (_isLiked) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    color: Colors.red.shade700,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tu as aimé cette balade',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Bouton Naviguer (si waypoints disponibles)
                          if (_ride!.waypoints != null && _ride!.waypoints!.isNotEmpty) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    builder: (context) => NavigationAppSelector(
                                      waypoints: _ride!.waypoints!,
                                      rideId: _ride!.id,
                                      rideName: _ride!.titre,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.navigation, size: 24),
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
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isParticipant ? null : _joinRide,
                                  icon: Icon(_isParticipant ? Icons.check : Icons.person_add),
                                  label: Text(_isParticipant ? 'Participant' : 'Participer'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              LikeButton(
                                isLiked: _isLiked,
                                totalLikes: _totalLikes,
                                onTap: _toggleLike,
                                size: 28,
                              ),
                            ],
                          ),
                          if (_isParticipant) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RideChatScreen(
                                        rideId: _ride!.id,
                                        rideTitle: _ride!.titre,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Ouvrir le chat'),
                              ),
                            ),
                            // Boutons pour quitter ou supprimer la balade
                            Builder(
                              builder: (context) {
                                final authService = Provider.of<AuthService>(context, listen: false);
                                final isOrganizer = _ride!.organisateur.id == authService.user?.id;
                                
                                if (isOrganizer) {
                                  // Afficher le bouton de suppression pour l'organisateur
                                  return Column(
                                    children: [
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _deleteRide,
                                          icon: const Icon(Icons.delete),
                                          label: const Text('Supprimer la balade'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                
                                // Afficher le bouton pour quitter pour les participants
                                return Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _leaveRide,
                                        icon: const Icon(Icons.exit_to_app),
                                        label: const Text('Quitter la balade'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  String _formatDateTime(DateTime date, String heure) {
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(heure.split(':')[0]),
      int.parse(heure.split(':')[1]),
    );
    return DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(dateTime);
  }

  Future<void> _loadRouteOnMap(List<Waypoint> waypoints) async {
    if (waypoints.isEmpty) return;

    setState(() {
      _isCalculatingRoute = true;
      _markers.clear();
      _polylines.clear();
    });

    // Trier les waypoints par ordre
    final sortedWaypoints = List<Waypoint>.from(waypoints);
    sortedWaypoints.sort((a, b) => a.order.compareTo(b.order));

    // Ajouter les marqueurs
    for (int i = 0; i < sortedWaypoints.length; i++) {
      final waypoint = sortedWaypoints[i];
      final markerId = MarkerId('waypoint_$i');

      _markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(waypoint.latitude, waypoint.longitude),
          infoWindow: InfoWindow(
            title: waypoint.type == 'depart'
                ? 'Départ'
                : waypoint.type == 'arrivee'
                    ? 'Arrivée'
                    : 'Checkpoint ${i}',
            snippet: waypoint.address,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            waypoint.type == 'depart'
                ? BitmapDescriptor.hueGreen
                : waypoint.type == 'arrivee'
                    ? BitmapDescriptor.hueRed
                    : BitmapDescriptor.hueBlue,
          ),
        ),
      );
    }

    // Calculer le trajet si on a au moins 2 waypoints
    if (sortedWaypoints.length >= 2) {
      try {
        final origin = '${sortedWaypoints.first.latitude},${sortedWaypoints.first.longitude}';
        final destination = '${sortedWaypoints.last.latitude},${sortedWaypoints.last.longitude}';
        final waypointsParam = sortedWaypoints
            .sublist(1, sortedWaypoints.length - 1)
            .map((wp) => '${wp.latitude},${wp.longitude}')
            .join('|');

        final response = await _apiService.calculateRoute(
          origin: origin,
          destination: destination,
          waypoints: waypointsParam.isNotEmpty ? waypointsParam : null,
        );

        if (response['success'] == true && response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          
          if (data['status'] == 'OK') {
            if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
              final route = data['routes'][0] as Map<String, dynamic>;
              
              // Décoder la polyligne
              List<LatLng> routePoints = [];
              if (route['overview_polyline'] != null) {
                final overviewPolyline = route['overview_polyline'] as Map<String, dynamic>;
                if (overviewPolyline['points'] != null) {
                  routePoints = _decodePolyline(overviewPolyline['points'] as String);
                }
              }

              if (routePoints.isNotEmpty) {
                // Filtrer les points invalides
                final validPoints = routePoints.where((point) {
                  return point.latitude >= -90 && point.latitude <= 90 &&
                         point.longitude >= -180 && point.longitude <= 180;
                }).toList();

                if (validPoints.isNotEmpty) {
                  _polylines.add(
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: validPoints,
                      color: Colors.blue,
                      width: 4,
                      geodesic: false,
                    ),
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Erreur lors du calcul du trajet: $e');
      }
    }

    // Centrer la carte sur le premier waypoint
    if (sortedWaypoints.isNotEmpty) {
      final firstWaypoint = sortedWaypoints.first;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(firstWaypoint.latitude, firstWaypoint.longitude),
            zoom: 12,
          ),
        ),
      );
    }

    setState(() {
      _isCalculatingRoute = false;
    });
  }

  // Décoder une polyligne encodée de Google Maps
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    if (encoded.isEmpty) return points;
    
    int index = 0;
    int lat = 0;
    int lng = 0;

    try {
      while (index < encoded.length) {
        // Décoder la latitude
        int shift = 0;
        int result = 0;
        int byte;
        do {
          if (index >= encoded.length) {
            return points;
          }
          byte = encoded.codeUnitAt(index++) - 63;
          if (byte < 0 || byte > 127) {
            return points;
          }
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20);
        
        // Décoder le delta de latitude
        int dlat;
        if ((result & 1) != 0) {
          final unsigned = result >> 1;
          dlat = -unsigned - 1;
        } else {
          dlat = (result >> 1);
        }
        lat += dlat;

        // Décoder la longitude
        shift = 0;
        result = 0;
        do {
          if (index >= encoded.length) {
            return points;
          }
          byte = encoded.codeUnitAt(index++) - 63;
          if (byte < 0 || byte > 127) {
            return points;
          }
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20);
        
        // Décoder le delta de longitude
        int dlng;
        if ((result & 1) != 0) {
          final unsigned = result >> 1;
          dlng = -unsigned - 1;
        } else {
          dlng = (result >> 1);
        }
        lng += dlng;

        // Convertir en degrés décimaux
        final decodedLat = lat / 1e5;
        final decodedLng = lng / 1e5;
        
        // Valider les coordonnées
        if (decodedLat >= -90 && decodedLat <= 90 && 
            decodedLng >= -180 && decodedLng <= 180) {
          points.add(LatLng(decodedLat, decodedLng));
        } else {
          break;
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du décodage de la polyligne: $e');
    }

    return points;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
