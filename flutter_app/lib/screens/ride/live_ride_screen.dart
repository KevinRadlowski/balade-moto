import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../models/ride.dart';
import '../../models/waypoint.dart';
import '../../providers/live_ride_provider.dart';
import '../../providers/emergency_contact_provider.dart';
import '../../services/auth_service.dart';
import '../../constants/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import 'package:intl/intl.dart';

/// Écran Live Ride - Mode "Balade en cours"
/// Affiche l'itinéraire, les participants actifs, et les actions rapides
class LiveRideScreen extends StatefulWidget {
  final String rideId;
  final Ride ride;

  const LiveRideScreen({
    super.key,
    required this.rideId,
    required this.ride,
  });

  @override
  State<LiveRideScreen> createState() => _LiveRideScreenState();
}

class _LiveRideScreenState extends State<LiveRideScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  Timer? _heartbeatTimer;
  Timer? _statusRefreshTimer;
  Position? _currentPosition;
  
  bool _isInitialized = false;
  bool _showEmergencyDialog = false;
  bool _isRouteLoaded = false; // Cache pour éviter de recalculer la route

  @override
  void initState() {
    super.initState();
    // Utiliser addPostFrameCallback pour éviter setState() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLiveRide();
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _statusRefreshTimer?.cancel();
    // Ne pas disposer manuellement le contrôleur Google Maps sur web
    // Flutter le fait automatiquement et cela peut causer des erreurs
    // si la vue n'est pas encore construite
    _mapController = null;
    super.dispose();
  }

  Future<void> _initializeLiveRide() async {
    final liveRideProvider = Provider.of<LiveRideProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Vérifier si l'utilisateur est l'organisateur
    final isOrganizer = authService.user?.id == widget.ride.organisateur.id;
    
    try {
      // Si c'est l'organisateur, démarrer la balade
      if (isOrganizer) {
        // Récupérer la position (avec timeout)
        try {
          await _getCurrentLocation();
        } catch (e) {
          // Continuer sans position
        }
        
        try {
          await liveRideProvider.startLiveRide(
            rideId: widget.rideId,
            location: _currentPosition != null
                ? {
                    'latitude': _currentPosition!.latitude,
                    'longitude': _currentPosition!.longitude,
                  }
                : null,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Le démarrage de la balade a pris trop de temps', const Duration(seconds: 10));
            },
          );
        } on TimeoutException catch (e) {
          debugPrint('[LiveRideScreen] Timeout lors du démarrage: $e');
        } catch (e) {
          debugPrint('[LiveRideScreen] Erreur lors du démarrage de la balade: $e');
        }
      }
      
      // Charger le statut initial (pour organisateur ou participant)
      try {
        await liveRideProvider.refreshStatus(
          useCache: false,
          rideId: widget.rideId,
        );
      } catch (e) {
        debugPrint('[LiveRideScreen] Erreur lors de la récupération du statut: $e');
      }
    } catch (e) {
      debugPrint('[LiveRideScreen] Erreur lors de l\'initialisation: $e');
    }
    
    // Initialiser la carte
    try {
      await _loadRouteOnMap();
    } catch (e) {
      debugPrint('[LiveRideScreen] Erreur lors du chargement de la carte: $e');
    }
    
    // Démarrer les timers (seulement si la balade est active)
    if (liveRideProvider.isActive) {
      _startHeartbeat();
      _startStatusRefresh();
    }
    
    // TOUJOURS définir _isInitialized à true, même en cas d'erreur
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5), // Timeout de 5 secondes
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      // Continuer même si la géolocalisation échoue
    }
  }

  void _startHeartbeat() {
    // Envoyer un heartbeat toutes les 90 secondes (réduit pour éviter trop de requêtes)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 90), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final liveRideProvider = Provider.of<LiveRideProvider>(context, listen: false);
      if (!liveRideProvider.isActive || liveRideProvider.isPaused) {
        timer.cancel();
        return;
      }
      
      await _getCurrentLocation();
      
      try {
        await liveRideProvider.sendHeartbeat(
          location: _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                }
              : null,
        );
      } catch (e) {
        debugPrint('Erreur heartbeat: $e');
      }
    });
  }

  void _startStatusRefresh() {
    // Rafraîchir le statut toutes les 60 secondes (réduit pour éviter trop de requêtes)
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final liveRideProvider = Provider.of<LiveRideProvider>(context, listen: false);
      if (!liveRideProvider.isActive || liveRideProvider.isPaused) {
        timer.cancel();
        return;
      }
      
      await liveRideProvider.refreshStatus(useCache: false);
      _updateMapMarkers();
    });
  }

  Future<void> _loadRouteOnMap() async {
    // Ne pas recalculer si la route est déjà chargée
    if (_isRouteLoaded) {
      return;
    }
    
    if (widget.ride.waypoints == null || widget.ride.waypoints!.isEmpty) {
      return;
    }
    
    // Trier les waypoints par ordre (comme dans ride_detail_screen.dart)
    final sortedWaypoints = List<Waypoint>.from(widget.ride.waypoints!);
    sortedWaypoints.sort((a, b) => a.order.compareTo(b.order));
    
    // Ajouter les marqueurs pour les waypoints
    for (int i = 0; i < sortedWaypoints.length; i++) {
      final waypoint = sortedWaypoints[i];
      _markers.add(
        Marker(
          markerId: MarkerId('waypoint_$i'),
          position: LatLng(waypoint.latitude, waypoint.longitude),
          infoWindow: InfoWindow(
            title: waypoint.type == 'depart'
                ? 'Départ'
                : waypoint.type == 'arrivee'
                    ? 'Arrivée'
                    : 'Checkpoint $i',
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
    
    // Calculer la route réelle via l'API Directions
    if (sortedWaypoints.length >= 2) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final apiService = authService.apiService;
        
        final origin = '${sortedWaypoints.first.latitude},${sortedWaypoints.first.longitude}';
        final destination = '${sortedWaypoints.last.latitude},${sortedWaypoints.last.longitude}';
        
        String? waypointsParam;
        if (sortedWaypoints.length > 2) {
          waypointsParam = sortedWaypoints
              .sublist(1, sortedWaypoints.length - 1)
              .map((w) => '${w.latitude},${w.longitude}')
              .join('|');
        }
        
        final response = await apiService.calculateRoute(
          origin: origin,
          destination: destination,
          waypoints: waypointsParam,
        );
        
        if (response['success'] == true && response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          
          if (data['status'] == 'OK' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
            final route = data['routes'][0] as Map<String, dynamic>;
            
            // Utiliser overview_polyline qui est optimisée
            List<LatLng> allPoints = [];
            
            // Priorité à overview_polyline qui est déjà optimisée
            if (route['overview_polyline'] != null) {
              final overviewPolyline = route['overview_polyline'] as Map<String, dynamic>;
              if (overviewPolyline['points'] != null) {
                try {
                  final polylineEncoded = overviewPolyline['points'] as String;
                  allPoints = _decodePolyline(polylineEncoded);
                } catch (e) {
                  // Erreur lors du décodage, continuer avec les steps
                }
              }
            }
            
            // Si overview_polyline n'est pas disponible, utiliser les steps détaillés
            if (allPoints.isEmpty && route['legs'] != null && (route['legs'] as List).isNotEmpty) {
              LatLng? lastDecodedPoint;
              
              for (var leg in route['legs'] as List) {
                final legMap = leg as Map<String, dynamic>;
                if (legMap['steps'] != null && (legMap['steps'] as List).isNotEmpty) {
                  for (int stepIndex = 0; stepIndex < (legMap['steps'] as List).length; stepIndex++) {
                    final step = (legMap['steps'] as List)[stepIndex];
                    final stepMap = step as Map<String, dynamic>;
                    
                    if (stepMap['polyline'] != null) {
                      final polylineMap = stepMap['polyline'] as Map<String, dynamic>;
                      if (polylineMap['points'] != null) {
                        try {
                          // Décoder chaque step indépendamment (commence à 0)
                          final stepPoints = _decodePolyline(polylineMap['points'] as String);
                          
                          if (stepPoints.isNotEmpty) {
                            // Si on a un point de référence du step précédent, ajuster les coordonnées
                            if (lastDecodedPoint != null) {
                              // Calculer l'offset entre le premier point du step et le dernier point décodé
                              final offsetLat = lastDecodedPoint.latitude - stepPoints.first.latitude;
                              final offsetLng = lastDecodedPoint.longitude - stepPoints.first.longitude;
                              
                              // Ajuster tous les points du step
                              final adjustedPoints = stepPoints.map((point) {
                                return LatLng(
                                  point.latitude + offsetLat,
                                  point.longitude + offsetLng,
                                );
                              }).toList();
                              
                              // Ajouter tous les points sauf le premier (qui est un doublon)
                              allPoints.addAll(adjustedPoints.skip(1));
                              lastDecodedPoint = adjustedPoints.last;
                            } else {
                              // Premier step : ajouter tous les points
                              allPoints.addAll(stepPoints);
                              lastDecodedPoint = stepPoints.last;
                            }
                          }
                        } catch (e) {
                          // Erreur lors du décodage d'un step, continuer
                        }
                      }
                    }
                  }
                }
              }
            }
            
            if (allPoints.isNotEmpty) {
              final validPoints = allPoints.where((point) {
                return point.latitude >= -90 && point.latitude <= 90 &&
                       point.longitude >= -180 && point.longitude <= 180;
              }).toList();
              
              if (validPoints.isNotEmpty) {
                _polylines.add(
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: validPoints,
                    color: AppTheme.primaryColor,
                    width: 4,
                    geodesic: false, // Important : false pour suivre les routes, pas les lignes droites
                  ),
                );
                _isRouteLoaded = true; // Marquer la route comme chargée
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[LiveRideScreen] Erreur lors du calcul de la route: $e');
        // Ne pas ajouter de fallback ligne droite - laisser la route vide
      }
    }
    
    // Centrer la carte sur le premier waypoint
    if (sortedWaypoints.isNotEmpty && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(sortedWaypoints.first.latitude, sortedWaypoints.first.longitude),
          12.0,
        ),
      );
    }
    
    if (mounted) {
      setState(() {});
    }
  }
  
  // Décoder une polyligne encodée de Google Maps (version standard, commence à 0)
  // Algorithme basé sur la spécification Google Maps Encoding
  // Source: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
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
        
        // Décoder le delta de latitude (gestion correcte des valeurs négatives avec complément à deux)
        int dlat;
        if ((result & 1) != 0) {
          // Valeur négative : complément à deux
          final unsigned = result >> 1;
          dlat = -unsigned - 1; // Équivalent de ~unsigned mais plus sûr
        } else {
          // Valeur positive
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
        
        // Décoder le delta de longitude (gestion correcte des valeurs négatives avec complément à deux)
        int dlng;
        if ((result & 1) != 0) {
          // Valeur négative : complément à deux
          final unsigned = result >> 1;
          dlng = -unsigned - 1; // Équivalent de ~unsigned mais plus sûr
        } else {
          // Valeur positive
          dlng = (result >> 1);
        }
        lng += dlng;

        // Convertir en degrés décimaux
        final decodedLat = lat / 1e5;
        final decodedLng = lng / 1e5;
        
        // Valider les coordonnées avant d'ajouter
        if (decodedLat >= -90 && decodedLat <= 90 && 
            decodedLng >= -180 && decodedLng <= 180) {
          points.add(LatLng(decodedLat, decodedLng));
        } else {
          // Arrêter le décodage si on obtient des coordonnées invalides
          break;
        }
      }
    } catch (e) {
      // Erreur lors du décodage, retourner les points déjà décodés
    }
    
    return points;
  }

  void _updateMapMarkers() {
    final liveRideProvider = Provider.of<LiveRideProvider>(context, listen: false);
    final state = liveRideProvider.currentState;
    
    if (state == null) return;
    
    // Ajouter des marqueurs pour les participants actifs
    for (final position in state.participantPositions) {
      if (position.location != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('participant_${position.userId}'),
            position: LatLng(
              position.location!.latitude,
              position.location!.longitude,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: 'Participant actif',
              snippet: 'Dernière mise à jour: ${DateFormat('HH:mm').format(position.lastUpdate)}',
            ),
          ),
        );
      }
    }
    
    setState(() {});
  }

  Future<void> _handlePause() async {
    final liveRideProvider = Provider.of<LiveRideProvider>(context, listen: false);
    
    try {
      await _getCurrentLocation();
      await liveRideProvider.pauseLiveRide(
        location: _currentPosition != null
            ? {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude,
              }
            : null,
      );
      
      // Arrêter les timers
      _heartbeatTimer?.cancel();
      _statusRefreshTimer?.cancel();
      
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Balade mise en pause');
        setState(() {}); // Mettre à jour l'UI pour afficher le bouton "Reprendre"
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur: ${e.toString()}');
      }
    }
  }

  Future<void> _handleResume() async {
    final liveRideProvider = Provider.of<LiveRideProvider>(context, listen: false);
    
    try {
      await _getCurrentLocation();
      await liveRideProvider.resumeLiveRide(
        location: _currentPosition != null
            ? {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude,
              }
            : null,
      );
      
      // Redémarrer les timers
      _startHeartbeat();
      _startStatusRefresh();
      
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Balade reprise');
        setState(() {}); // Mettre à jour l'UI pour afficher le bouton "Pause"
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur: ${e.toString()}');
      }
    }
  }

  Future<void> _handleEndRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer la balade'),
        content: const Text('Êtes-vous sûr de vouloir terminer cette balade ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    final liveRideProvider = Provider.of<LiveRideProvider>(context, listen: false);
    
    try {
      await _getCurrentLocation();
      await liveRideProvider.endLiveRide(
        location: _currentPosition != null
            ? {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude,
              }
            : null,
        summary: {
          'completed': true,
          'endedAt': DateTime.now().toIso8601String(),
        },
      );
      
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Balade terminée');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur: ${e.toString()}');
      }
    }
  }

  Future<void> _handleIncident() async {
    final incidentType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler un incident'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('Panne mécanique'),
              onTap: () => Navigator.pop(context, 'mechanical'),
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital, color: Colors.red),
              title: const Text('Accident'),
              onTap: () => Navigator.pop(context, 'accident'),
            ),
            ListTile(
              leading: const Icon(Icons.location_off, color: Colors.blue),
              title: const Text('Perdu'),
              onTap: () => Navigator.pop(context, 'lost'),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.grey),
              title: const Text('Autre'),
              onTap: () => Navigator.pop(context, 'other'),
            ),
          ],
        ),
      ),
    );
    
    if (incidentType == null) return;
    
    final liveRideProvider = Provider.of<LiveRideProvider>(context, listen: false);
    
    try {
      await _getCurrentLocation().timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('[LiveRideScreen] Timeout lors de la récupération de la position pour incident');
        return;
      });
      
      await liveRideProvider.reportIncident(
        incidentType: incidentType,
        location: _currentPosition != null
            ? {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude,
              }
            : null,
        description: 'Incident signalé depuis l\'app',
      );
      
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Incident signalé');
        // Rafraîchir le statut
        await liveRideProvider.refreshStatus(useCache: false);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        if (errorMsg.contains('Trop de requêtes')) {
          SnackBarHelper.showError(context, errorMsg);
        } else {
          SnackBarHelper.showError(context, 'Erreur: $errorMsg');
        }
      }
    }
  }

  Future<void> _handleEmergency() async {
    if (_showEmergencyDialog) return;
    
    setState(() {
      _showEmergencyDialog = true;
    });
    
    final emergencyProvider = Provider.of<EmergencyContactProvider>(context, listen: false);
    final liveRideProvider = Provider.of<LiveRideProvider>(context, listen: false);
    
    // Charger le contact d'urgence si nécessaire
    await emergencyProvider.loadContact(useCache: false);
    
    // Vérifier si le contact d'urgence est configuré
    if (!emergencyProvider.hasContact) {
      final setupContact = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contact d\'urgence non configuré'),
          content: const Text(
            'Vous devez configurer un contact d\'urgence dans votre profil avant de pouvoir déclencher une alerte.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Configurer'),
            ),
          ],
        ),
      );
      
      if (setupContact == true && mounted) {
        Navigator.pop(context);
        // TODO: Naviguer vers la page de profil pour configurer le contact
      }
      
      setState(() {
        _showEmergencyDialog = false;
      });
      return;
    }
    
    // Confirmation avant déclenchement
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.errorColor, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Alerte d\'urgence',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Cette action va envoyer une alerte d\'urgence à votre contact d\'urgence et aux autres participants. '
          'Êtes-vous sûr de vouloir continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              setState(() {
                _showEmergencyDialog = false;
              });
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Déclencher l\'alerte'),
          ),
        ],
      ),
    );
    
    if (confirm != true) {
      setState(() {
        _showEmergencyDialog = false;
      });
      return;
    }
    
    try {
      await _getCurrentLocation();
      
      // Déclencher l'alerte d'urgence
      await emergencyProvider.triggerEmergencyAlert(
        rideId: widget.rideId,
        reason: 'Alerte d\'urgence déclenchée sur la balade "${widget.ride.titre}"',
        location: _currentPosition != null
            ? {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude,
              }
            : null,
      );
      
      // Signaler aussi comme incident
      await liveRideProvider.reportIncident(
        incidentType: 'emergency',
        location: _currentPosition != null
            ? {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude,
              }
            : null,
        description: 'Alerte d\'urgence déclenchée',
      );
      
      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          'Alerte d\'urgence envoyée',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur: ${e.toString()}');
      }
    } finally {
      setState(() {
        _showEmergencyDialog = false;
      });
    }
  }

  Future<void> _showParticipants() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = authService.apiService;
    final isOrganizer = authService.user?.id == widget.ride.organisateur.id;

    // Récupérer les données à jour de la balade
    Ride? ride;
    try {
      ride = await apiService.getRideById(widget.rideId);
    } catch (e) {
      // Si erreur, utiliser les données actuelles
      ride = widget.ride;
    }

    if (!mounted) return;
    final currentRide = ride;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.people, size: 28, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Participants',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${currentRide.participants.length} participant${currentRide.participants.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Liste des participants
              Expanded(
                child: currentRide.participants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun participant',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: currentRide.participants.length,
                        itemBuilder: (context, index) {
                          final participant = currentRide.participants[index];
                          final displayName = participant.pseudo ?? 'Utilisateur';
                          final isOrganizerParticipant = currentRide.organisateur.id == participant.id;
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isOrganizerParticipant 
                                  ? AppTheme.primaryColor.withOpacity(0.2)
                                  : AppTheme.primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: isOrganizerParticipant ? FontWeight.w600 : FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                if (isOrganizerParticipant) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Organisateur',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Pour l'organisateur, afficher les actions de validation de ponctualité
                            trailing: isOrganizer && !isOrganizerParticipant
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                        onPressed: () => _validatePunctuality(currentRide.id, participant.id, true),
                                        tooltip: 'Marquer comme à l\'heure',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                        onPressed: () => _validatePunctuality(currentRide.id, participant.id, false),
                                        tooltip: 'Marquer comme en retard',
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _validatePunctuality(String rideId, String userId, bool isOnTime) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = authService.apiService;
      await apiService.validatePunctuality(rideId, userId, isOnTime);
      
      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          isOnTime 
            ? 'Le participant a été marqué comme étant à l\'heure'
            : 'Le participant a été marqué comme étant en retard',
        );
        
        // Rafraîchir la liste des participants
        Navigator.pop(context);
        _showParticipants();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Erreur lors de la validation: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveRideProvider = Provider.of<LiveRideProvider>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final isOrganizer = authService.user?.id == widget.ride.organisateur.id;
    final state = liveRideProvider.currentState;
    
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Balade en cours'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Déterminer le statut affiché
    String statusText = '🟢 Active';
    if (state != null) {
      if (state.ride.status == 'paused') {
        statusText = '⏸️ En pause';
      } else if (state.ride.status == 'in_progress') {
        statusText = '🟢 Active';
      }
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Balade en cours'),
            Text(
              statusText,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Indicateur de heartbeat actif
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Actif',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Carte
            GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              // Ne pas recharger la route ici, elle est déjà chargée dans _initializeLiveRide
              // _loadRouteOnMap();
            },
            initialCameraPosition: CameraPosition(
              target: widget.ride.waypoints != null && widget.ride.waypoints!.isNotEmpty
                  ? LatLng(
                      widget.ride.waypoints!.first.latitude,
                      widget.ride.waypoints!.first.longitude,
                    )
                  : const LatLng(46.6034, 1.8883),
              zoom: 12.0,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          
          // Panneau d'informations
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ride.titre,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Participants: ${widget.ride.participants.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (state != null) ...[
                      // Afficher le nombre de participants actifs (ceux qui ont envoyé leur position)
                      // Si aucun participant n'a envoyé de position mais qu'il y a des participants,
                      // considérer qu'ils sont tous actifs (ils sont dans la balade en cours)
                      Text(
                        'Participants actifs: ${state.participantPositions.length > 0 ? state.participantPositions.length : widget.ride.participants.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      if (state.lastEvent != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Dernier événement: ${state.lastEvent!.type}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ],
                    ] else ...[
                      // Si pas d'état, afficher le nombre total de participants comme actifs
                      Text(
                        'Participants actifs: ${widget.ride.participants.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showParticipants,
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: Text('Voir les participants (${widget.ride.participants.length})'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Actions rapides (en bas)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton urgence (toujours visible)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showEmergencyDialog ? null : _handleEmergency,
                    icon: const Icon(Icons.emergency),
                    label: const Text('URGENCE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Actions pour l'organisateur
                if (isOrganizer) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: liveRideProvider.isPaused ? _handleResume : _handlePause,
                          icon: Icon(liveRideProvider.isPaused ? Icons.play_arrow : Icons.pause),
                          label: Text(liveRideProvider.isPaused ? 'Reprendre' : 'Pause'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleIncident,
                          icon: const Icon(Icons.warning),
                          label: const Text('Incident'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _handleEndRide,
                          icon: const Icon(Icons.stop),
                          label: const Text('Terminer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

