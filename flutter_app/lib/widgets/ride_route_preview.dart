import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/ride.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class RideRoutePreview extends StatefulWidget {
  final Ride ride;
  final double height;

  const RideRoutePreview({
    super.key,
    required this.ride,
    this.height = 200,
  });

  @override
  State<RideRoutePreview> createState() => _RideRoutePreviewState();
  
  // Clé unique basée sur l'ID de la balade pour éviter les recréations inutiles
  static Key getKey(String rideId) {
    return ValueKey('route_preview_$rideId');
  }

}

class _RideRoutePreviewState extends State<RideRoutePreview> {
  final ApiService _apiService = ApiService();
  final Set<Polyline> _polylines = {};
  bool _isCalculatingRoute = false;
  bool _routeLoaded = false;

  @override
  void initState() {
    super.initState();
    // Charger le trajet si des waypoints existent
    if (widget.ride.waypoints != null && widget.ride.waypoints!.isNotEmpty) {
      _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    if (_routeLoaded || _isCalculatingRoute) return;

    final waypoints = widget.ride.waypoints!;
    if (waypoints.length < 2) return;

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      // Trier les waypoints par ordre
      final sortedWaypoints = List.from(waypoints);
      sortedWaypoints.sort((a, b) => a.order.compareTo(b.order));

      final origin = '${sortedWaypoints.first.latitude},${sortedWaypoints.first.longitude}';
      final destination = '${sortedWaypoints.last.latitude},${sortedWaypoints.last.longitude}';
      final waypointsParam = sortedWaypoints
          .sublist(1, sortedWaypoints.length - 1)
          .map((wp) => '${wp.latitude},${wp.longitude}')
          .join('|');

      // Récupérer le token
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

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

              if (validPoints.isNotEmpty && mounted) {
                setState(() {
                  _polylines.add(
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: validPoints,
                      color: Colors.blue,
                      width: 3,
                      geodesic: false,
                    ),
                  );
                  _routeLoaded = true;
                  _isCalculatingRoute = false;
                });
                return;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du calcul du trajet dans la prévisualisation: $e');
    }

    if (mounted) {
      setState(() {
        _isCalculatingRoute = false;
        _routeLoaded = true; // Marquer comme chargé même en cas d'erreur pour éviter les tentatives répétées
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si la balade a des waypoints, les utiliser
    if (widget.ride.waypoints != null && widget.ride.waypoints!.isNotEmpty) {
      return _buildMapWithWaypoints();
    }

    // Sinon, afficher juste les informations de départ/arrivée
    return _buildSimplePreview();
  }

  Widget _buildMapWithWaypoints() {
    final waypoints = widget.ride.waypoints!;
    
    // Trier les waypoints par ordre
    final sortedWaypoints = List.from(waypoints);
    sortedWaypoints.sort((a, b) => a.order.compareTo(b.order));
    
    // Créer les marqueurs
    final markers = <Marker>{};
    for (int i = 0; i < sortedWaypoints.length; i++) {
      final waypoint = sortedWaypoints[i];
      markers.add(
        Marker(
          markerId: MarkerId('waypoint_$i'),
          position: LatLng(waypoint.latitude, waypoint.longitude),
          infoWindow: InfoWindow(
            title: waypoint.type == 'depart'
                ? 'Départ'
                : waypoint.type == 'arrivee'
                    ? 'Arrivée'
                    : 'Checkpoint',
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

    // Si le trajet n'est pas encore chargé, afficher une polyligne temporaire en ligne droite
    final polylinesToShow = _polylines.isNotEmpty 
        ? _polylines 
        : <Polyline>{
            Polyline(
              polylineId: const PolylineId('route_temp'),
              points: sortedWaypoints.map((w) => LatLng(w.latitude, w.longitude)).toList(),
              color: Colors.blue.withOpacity(0.3),
              width: 2,
              geodesic: true, // Ligne droite temporaire
            ),
          };

    // Calculer les bounds pour centrer la carte
    double minLat = sortedWaypoints.first.latitude;
    double maxLat = sortedWaypoints.first.latitude;
    double minLng = sortedWaypoints.first.longitude;
    double maxLng = sortedWaypoints.first.longitude;

    for (final waypoint in sortedWaypoints) {
      if (waypoint.latitude < minLat) minLat = waypoint.latitude;
      if (waypoint.latitude > maxLat) maxLat = waypoint.latitude;
      if (waypoint.longitude < minLng) minLng = waypoint.longitude;
      if (waypoint.longitude > maxLng) maxLng = waypoint.longitude;
    }

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    final latDelta = (maxLat - minLat) * 1.5;
    final lngDelta = (maxLng - minLng) * 1.5;

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: _calculateZoom(latDelta, lngDelta),
              ),
              markers: markers,
              polylines: polylinesToShow,
              mapType: MapType.normal,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
            ),
            if (_isCalculatingRoute)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _calculateZoom(double latDelta, double lngDelta) {
    final maxDelta = latDelta > lngDelta ? latDelta : lngDelta;
    if (maxDelta < 0.01) return 15.0;
    if (maxDelta < 0.05) return 13.0;
    if (maxDelta < 0.1) return 12.0;
    if (maxDelta < 0.5) return 10.0;
    if (maxDelta < 1.0) return 9.0;
    return 8.0;
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

  Widget _buildSimplePreview() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            widget.ride.lieuDepart is String
                ? widget.ride.lieuDepart as String
                : 'Départ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Icon(Icons.arrow_downward, size: 20, color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text(
            widget.ride.lieuArrivee is String
                ? widget.ride.lieuArrivee as String
                : 'Arrivée',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

