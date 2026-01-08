import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/ride.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/ride_route_preview.dart';
import '../../screens/ride/ride_detail_screen.dart';

class RidePreviewCard extends StatefulWidget {
  final String rideId;
  final bool isOwnMessage;

  const RidePreviewCard({
    super.key,
    required this.rideId,
    this.isOwnMessage = false,
  });

  @override
  State<RidePreviewCard> createState() => _RidePreviewCardState();
}

class _RidePreviewCardState extends State<RidePreviewCard> {
  final ApiService _apiService = ApiService();
  Ride? _ride;
  bool _isLoading = true;
  String? _error;
  double? _distance; // en kilomètres
  String? _duration; // format "X h Y min"
  String? _departAddress; // Adresse formatée du départ
  String? _arriveeAddress; // Adresse formatée de l'arrivée

  @override
  void initState() {
    super.initState();
    _loadRideDetails();
  }

  Future<void> _loadRideDetails() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      // Charger les détails de la balade
      final ride = await _apiService.getRideById(widget.rideId);
      
      if (!mounted) return;
      
      // Obtenir les adresses complètes depuis les waypoints
      if (ride.waypoints != null && ride.waypoints!.isNotEmpty) {
        await _loadAddressesFromWaypoints(ride);
      }
      
      // Calculer la distance et la durée si on a des waypoints
      if (ride.waypoints != null && ride.waypoints!.length >= 2) {
        await _calculateRouteInfo(ride);
      }

      if (!mounted) return;
      setState(() {
        _ride = ride;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAddressesFromWaypoints(Ride ride) async {
    try {
      // Obtenir le waypoint de départ
      final departWaypoint = ride.waypoints!.firstWhere(
        (wp) => wp.type == 'depart',
        orElse: () => ride.waypoints!.first,
      );
      
      // Obtenir le waypoint d'arrivée
      final arriveeWaypoint = ride.waypoints!.firstWhere(
        (wp) => wp.type == 'arrivee',
        orElse: () => ride.waypoints!.last,
      );
      
      // Si l'adresse du waypoint est déjà complète (contient un code postal), l'utiliser
      if (departWaypoint.address.contains(RegExp(r'\d{5}'))) {
        _departAddress = _formatAddress(departWaypoint.address);
      } else {
        // Sinon, faire un géocodage inverse
        try {
          final placemarks = await placemarkFromCoordinates(
            departWaypoint.latitude,
            departWaypoint.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final postalCode = place.postalCode ?? '';
            final locality = place.locality ?? '';
            if (postalCode.isNotEmpty && locality.isNotEmpty) {
              _departAddress = '$postalCode $locality';
            } else if (locality.isNotEmpty) {
              _departAddress = locality;
            } else {
              _departAddress = _formatAddress(departWaypoint.address);
            }
          } else {
            _departAddress = _formatAddress(departWaypoint.address);
          }
        } catch (e) {
          // Si le géocodage échoue, utiliser l'adresse telle quelle
          _departAddress = _formatAddress(departWaypoint.address);
        }
      }
      
      // Même chose pour l'arrivée
      if (arriveeWaypoint.address.contains(RegExp(r'\d{5}'))) {
        _arriveeAddress = _formatAddress(arriveeWaypoint.address);
      } else {
        try {
          final placemarks = await placemarkFromCoordinates(
            arriveeWaypoint.latitude,
            arriveeWaypoint.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final postalCode = place.postalCode ?? '';
            final locality = place.locality ?? '';
            if (postalCode.isNotEmpty && locality.isNotEmpty) {
              _arriveeAddress = '$postalCode $locality';
            } else if (locality.isNotEmpty) {
              _arriveeAddress = locality;
            } else {
              _arriveeAddress = _formatAddress(arriveeWaypoint.address);
            }
          } else {
            _arriveeAddress = _formatAddress(arriveeWaypoint.address);
          }
        } catch (e) {
          _arriveeAddress = _formatAddress(arriveeWaypoint.address);
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des adresses: $e');
    }
  }

  Future<void> _calculateRouteInfo(Ride ride) async {
    try {
      final sortedWaypoints = List.from(ride.waypoints!);
      sortedWaypoints.sort((a, b) => a.order.compareTo(b.order));

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
        
        if (data['status'] == 'OK' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          
          // Calculer la distance totale
          double totalDistance = 0;
          int totalDuration = 0;
          
          if (route['legs'] != null) {
            final legs = route['legs'] as List;
            for (final leg in legs) {
              if (leg['distance'] != null && leg['distance']['value'] != null) {
                totalDistance += (leg['distance']['value'] as int).toDouble() / 1000; // Convertir en km
              }
              if (leg['duration'] != null && leg['duration']['value'] != null) {
                totalDuration += leg['duration']['value'] as int; // en secondes
              }
            }
          }

          // Formater la durée
          final hours = totalDuration ~/ 3600;
          final minutes = (totalDuration % 3600) ~/ 60;
          String durationText = '';
          if (hours > 0) {
            durationText = '$hours h';
            if (minutes > 0) {
              durationText += ' $minutes min';
            }
          } else {
            durationText = '$minutes min';
          }

          if (mounted) {
            setState(() {
              _distance = totalDistance;
              _duration = durationText;
            });
          }
        }
      }
    } catch (e) {
      print('Erreur lors du calcul de la route: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200]?.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _ride == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[100]?.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _error ?? 'Balade non trouvée',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final ride = _ride!;

    final textColor = widget.isOwnMessage ? Colors.white : Colors.black87;
    final subtitleColor = widget.isOwnMessage ? Colors.white70 : Colors.grey[600]!;
    final cardColor = widget.isOwnMessage 
        ? Colors.white.withOpacity(0.15)
        : Colors.grey[200]!.withOpacity(0.8);
    final borderColor = widget.isOwnMessage
        ? Colors.white.withOpacity(0.3)
        : Colors.grey[400]!.withOpacity(0.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de la balade
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              ride.titre,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          
          // Carte avec le trajet
          if (ride.waypoints != null && ride.waypoints!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: SizedBox(
                height: 200,
                child: RideRoutePreview(
                  key: RideRoutePreview.getKey(ride.id),
                  ride: ride,
                  height: 200,
                ),
              ),
            ),
          
          // Informations de la balade
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Point de départ
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _departAddress ?? (ride.waypoints != null && ride.waypoints!.isNotEmpty
                            ? _formatAddress(ride.waypoints!.firstWhere(
                                (wp) => wp.type == 'depart',
                                orElse: () => ride.waypoints!.first,
                              ).address)
                            : _getLocationName(ride.lieuDepart)),
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Point d'arrivée
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _arriveeAddress ?? (ride.waypoints != null && ride.waypoints!.isNotEmpty
                            ? _formatAddress(ride.waypoints!.firstWhere(
                                (wp) => wp.type == 'arrivee',
                                orElse: () => ride.waypoints!.last,
                              ).address)
                            : _getLocationName(ride.lieuArrivee)),
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Distance et durée
                Row(
                  children: [
                    if (_distance != null) ...[
                      Icon(Icons.straighten, size: 16, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        '${_distance!.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 13,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (_duration != null) ...[
                      Icon(Icons.access_time, size: 16, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        _duration!,
                        style: TextStyle(
                          fontSize: 13,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Bouton pour accéder au détail de la balade
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RideDetailScreen(
                              rideId: widget.rideId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Voir les détails de la balade'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLocationName(dynamic location) {
    // Cette fonction n'est utilisée que comme fallback si les waypoints ne sont pas disponibles
    // Si c'est une string, l'utiliser directement
    if (location is String) {
      return _formatAddress(location);
    }
    
    // Si c'est un Map, essayer d'extraire l'adresse
    if (location is Map) {
      final address = location['address'] ?? location['name'] ?? 'Lieu inconnu';
      return _formatAddress(address);
    }
    
    return 'Lieu inconnu';
  }

  String _formatAddress(String address) {
    if (address.isEmpty) return 'Lieu inconnu';
    
    // Si l'adresse contient des coordonnées (format "lat, lng"), essayer de la formater
    if (address.contains(',') && address.contains('.')) {
      // Vérifier si c'est des coordonnées (format numérique)
      final parts = address.split(',');
      if (parts.length == 2) {
        final latStr = parts[0].trim();
        final lngStr = parts[1].trim();
        // Vérifier si ce sont des nombres
        if (double.tryParse(latStr) != null && double.tryParse(lngStr) != null) {
          // Ce sont des coordonnées, retourner un message générique
          return 'Position GPS';
        }
      }
    }
    
    // Extraire la ville et le code postal si possible
    // Format typique: "Rue, Code Postal Ville" ou "Ville Code Postal"
    final postalCodeMatch = RegExp(r'\b(\d{5})\b').firstMatch(address);
    if (postalCodeMatch != null) {
      final postalCode = postalCodeMatch.group(1)!;
      // Extraire la ville (généralement après le code postal)
      final parts = address.split(postalCode);
      String city = '';
      if (parts.length > 1) {
        city = parts[1].trim();
        // Nettoyer la ville (enlever les virgules et espaces multiples)
        city = city.replaceAll(RegExp(r'[,\s]+'), ' ').trim();
      }
      
      // Si on a une ville, retourner "Code Postal Ville"
      if (city.isNotEmpty) {
        return '$postalCode $city';
      }
      
      // Sinon, retourner l'adresse complète si elle contient le code postal
      return address;
    }
    
    // Si l'adresse est complète et contient une virgule, c'est probablement une adresse complète
    if (address.contains(',') && address.length > 10) {
      return address;
    }
    
    // Sinon, retourner l'adresse telle quelle
    return address;
  }
}

