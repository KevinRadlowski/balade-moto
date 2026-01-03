import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/waypoint.dart';
import '../../models/ride.dart';

class CreateRideWithMapScreen extends StatefulWidget {
  final Ride? duplicateRide;
  
  const CreateRideWithMapScreen({super.key, this.duplicateRide});

  @override
  State<CreateRideWithMapScreen> createState() => _CreateRideWithMapScreenState();
}

class _CreateRideWithMapScreenState extends State<CreateRideWithMapScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Contrôleurs
  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  
  // État
  String _typeVehicule = 'moto';
  String _visibilite = 'publique';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  bool _avoidTolls = false;
  bool _avoidHighways = false;
  
  // Carte et waypoints
  GoogleMapController? _mapController;
  List<Waypoint> _waypoints = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  int _nextOrder = 0;
  
  // Mode de saisie (carte ou adresse)
  bool _isAddressMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.duplicateRide != null) {
      _loadDuplicateRide();
    } else {
      _getCurrentLocation();
    }
  }

  void _loadDuplicateRide() {
    final ride = widget.duplicateRide!;
    _titreController.text = '${ride.titre} (copie)';
    _descriptionController.text = ride.description ?? '';
    _typeVehicule = ride.typeVehicule;
    _visibilite = ride.visibilite;
    
    // Charger les waypoints
    if (ride.waypoints != null && ride.waypoints!.isNotEmpty) {
      setState(() {
        _waypoints = ride.waypoints!.map((wp) => Waypoint(
          type: wp.type,
          address: wp.address,
          latitude: wp.latitude,
          longitude: wp.longitude,
          order: wp.order,
        )).toList();
        _nextOrder = _waypoints.length;
      });
      
      // Centrer la carte sur le premier waypoint après que la carte soit créée
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mapController != null && _waypoints.isNotEmpty) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(_waypoints.first.latitude, _waypoints.first.longitude),
              12.0,
            ),
          );
        }
      });
      
      // Mettre à jour les marqueurs et polylines après un court délai
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _updateMarkersAndPolylines();
        }
      });
    }
    
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    // Vérifier que le contrôleur est initialisé avant de le disposer
    if (_mapController != null) {
      try {
        _mapController!.dispose();
      } catch (e) {
        debugPrint('Erreur lors de la disposition du contrôleur de carte: $e');
      }
    }
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permission de localisation refusée')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission de localisation refusée définitivement')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      if (_mapController != null && _currentLocation != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 12.0),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    if (_currentLocation != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 12.0),
      );
    }
  }

  Future<void> _addWaypointFromMap(LatLng position) async {
    try {
      String address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      
      // Utiliser l'API backend pour le géocodage inverse (fonctionne sur web)
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        _apiService.setToken(token);
        
        final geocodeResult = await _apiService.reverseGeocode(
          position.latitude,
          position.longitude,
        );
        
        // Construire l'adresse complète avec rue, code postal et ville
        if (geocodeResult['street'] != null && 
            geocodeResult['postalCode'] != null && 
            geocodeResult['locality'] != null) {
          address = '${geocodeResult['street']}, ${geocodeResult['postalCode']} ${geocodeResult['locality']}';
        } else if (geocodeResult['postalCode'] != null && geocodeResult['locality'] != null) {
          address = '${geocodeResult['postalCode']} ${geocodeResult['locality']}';
        } else if (geocodeResult['address'] != null && geocodeResult['address'].toString().isNotEmpty) {
          address = geocodeResult['address'];
        } else if (geocodeResult['formattedAddress'] != null && geocodeResult['formattedAddress'].toString().isNotEmpty) {
          address = geocodeResult['formattedAddress'];
        }
      } catch (geocodingError) {
        // Si le géocodage échoue, on utilise les coordonnées comme adresse
        debugPrint('Géocodage inverse non disponible: $geocodingError');
      }

      // Déterminer le type de waypoint
      // Règle : premier = départ, dernier = arrivée, autres = checkpoints
      String type;
      if (_waypoints.isEmpty) {
        type = 'depart';
      } else {
        // Si on a déjà un départ, le nouveau point devient l'arrivée
        // et l'ancienne arrivée devient un checkpoint
        if (_waypoints.length == 1) {
          // Le deuxième point devient l'arrivée
          type = 'arrivee';
        } else {
          // On a déjà départ + arrivée, donc on convertit l'arrivée en checkpoint
          // et le nouveau point devient l'arrivée
          type = 'checkpoint';
        }
      }

      final waypoint = Waypoint(
        type: type,
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
        order: _nextOrder++,
      );

      setState(() {
        _waypoints.add(waypoint);
        _reorganizeWaypointTypes();
        _updateMarkersAndPolylines();
      });
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout du point: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ajout du point: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addWaypointFromAddress() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir une adresse')),
      );
      return;
    }

    try {
      // Géocodage de l'adresse
      List<Location> locations = await locationFromAddress(_addressController.text.trim());

      if (locations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adresse non trouvée')),
        );
        return;
      }

      final location = locations.first;
      final position = LatLng(location.latitude, location.longitude);

      // Déterminer le type (même logique que pour _addWaypointFromMap)
      String type;
      if (_waypoints.isEmpty) {
        type = 'depart';
      } else if (_waypoints.length == 1) {
        type = 'arrivee';
      } else {
        type = 'checkpoint';
      }

      final waypoint = Waypoint(
        type: type,
        address: _addressController.text.trim(),
        latitude: location.latitude,
        longitude: location.longitude,
        order: _nextOrder++,
      );

      setState(() {
        _waypoints.add(waypoint);
        _reorganizeWaypointTypes();
        _addressController.clear();
        _isAddressMode = false;
        _updateMarkersAndPolylines();
      });

      // Centrer la carte sur le nouveau point
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(position, 14.0),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la recherche: $e')),
        );
      }
    }
  }

  // Réorganiser les types de waypoints pour que l'arrivée soit toujours le dernier
  void _reorganizeWaypointTypes() {
    if (_waypoints.isEmpty) return;
    
    final updatedWaypoints = <Waypoint>[];
    for (int i = 0; i < _waypoints.length; i++) {
      String type;
      if (i == 0) {
        type = 'depart';
      } else if (i == _waypoints.length - 1) {
        type = 'arrivee';
      } else {
        type = 'checkpoint';
      }
      
      updatedWaypoints.add(
        Waypoint(
          type: type,
          address: _waypoints[i].address,
          latitude: _waypoints[i].latitude,
          longitude: _waypoints[i].longitude,
          order: i,
        ),
      );
    }
    _waypoints = updatedWaypoints;
    _nextOrder = _waypoints.length;
  }

  // Obtenir le tracé de la route via le backend (pour éviter CORS)
  Future<List<LatLng>> _getRoutePoints() async {
    if (_waypoints.length < 2) return [];

    try {
      // Préparer les paramètres
      final origin = '${_waypoints.first.latitude},${_waypoints.first.longitude}';
      final destination = '${_waypoints.last.latitude},${_waypoints.last.longitude}';
      
      // Construire les waypoints intermédiaires (sans le départ et l'arrivée)
      String? waypointsParam;
      if (_waypoints.length > 2) {
        waypointsParam = _waypoints
            .sublist(1, _waypoints.length - 1)
            .map((w) => '${w.latitude},${w.longitude}')
            .join('|');
      }

      debugPrint('🔵 Calcul de l\'itinéraire via le backend...');
      debugPrint('🔵 Origin: $origin');
      debugPrint('🔵 Destination: $destination');
      if (waypointsParam != null) {
        debugPrint('🔵 Waypoints: $waypointsParam');
      }

      // Appeler le backend qui fera l'appel à l'API Directions
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final response = await _apiService.calculateRoute(
        origin: origin,
        destination: destination,
        waypoints: waypointsParam,
        avoidTolls: _avoidTolls,
        avoidHighways: _avoidHighways,
      );
      
      debugPrint('🔵 Réponse du backend: ${response['success']}');
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        
        debugPrint('🔵 Status de la réponse Directions: ${data['status']}');
        
            if (data['status'] == 'OK') {
              if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
                final route = data['routes'][0] as Map<String, dynamic>;
                
                // Debug: vérifier la structure de la réponse
                debugPrint('🔵 Structure de la route:');
                debugPrint('  - overview_polyline: ${route['overview_polyline'] != null}');
                debugPrint('  - legs: ${route['legs'] != null}');
                if (route['legs'] != null) {
                  debugPrint('  - nombre de legs: ${(route['legs'] as List).length}');
                }
                
                // Utiliser overview_polyline qui est optimisée et sans problème d'accumulation
                List<LatLng> allPoints = [];
                
                // Priorité à overview_polyline qui est déjà optimisée
                if (route['overview_polyline'] != null) {
                  final overviewPolyline = route['overview_polyline'] as Map<String, dynamic>;
                  if (overviewPolyline['points'] != null) {
                    try {
                      final polylineEncoded = overviewPolyline['points'] as String;
                      debugPrint('🔵 Polyligne encodée (longueur: ${polylineEncoded.length} caractères)');
                      debugPrint('🔵 Polyligne encodée (premiers 100 caractères): ${polylineEncoded.substring(0, polylineEncoded.length > 100 ? 100 : polylineEncoded.length)}...');
                      
                      allPoints = _decodePolyline(polylineEncoded);
                      debugPrint('🔵 Utilisation de overview_polyline: ${allPoints.length} points décodés');
                      if (allPoints.isNotEmpty) {
                        debugPrint('🔵 Premier point décodé: ${allPoints.first.latitude}, ${allPoints.first.longitude}');
                        debugPrint('🔵 Dernier point décodé: ${allPoints.last.latitude}, ${allPoints.last.longitude}');
                        
                        // Vérifier que le dernier point correspond à la destination
                        final expectedDestLat = double.parse(destination.split(',')[0]);
                        final expectedDestLng = double.parse(destination.split(',')[1]);
                        final lastPoint = allPoints.last;
                        final latDiff = (lastPoint.latitude - expectedDestLat).abs();
                        final lngDiff = (lastPoint.longitude - expectedDestLng).abs();
                        
                        if (latDiff > 0.01 || lngDiff > 0.01) {
                          debugPrint('⚠️ ATTENTION: Le dernier point décodé ne correspond pas à la destination');
                          debugPrint('⚠️ Attendu: $expectedDestLat, $expectedDestLng');
                          debugPrint('⚠️ Obtenu: ${lastPoint.latitude}, ${lastPoint.longitude}');
                        }
                      }
                    } catch (e, stackTrace) {
                      debugPrint('❌ Erreur lors du décodage de overview_polyline: $e');
                      debugPrint('❌ Stack trace: $stackTrace');
                    }
                  }
                }
                
                // Si overview_polyline n'est pas disponible, utiliser les steps détaillés
                // mais en décodant chaque step indépendamment et en les connectant correctement
                if (allPoints.isEmpty && route['legs'] != null && (route['legs'] as List).isNotEmpty) {
                  debugPrint('⚠️ overview_polyline non disponible, utilisation des steps détaillés');
                  debugPrint('🔵 Nombre de legs: ${(route['legs'] as List).length}');
                  
                  LatLng? lastDecodedPoint;
                  
                  for (var leg in route['legs'] as List) {
                    final legMap = leg as Map<String, dynamic>;
                    if (legMap['steps'] != null && (legMap['steps'] as List).isNotEmpty) {
                      debugPrint('🔵 Nombre de steps dans ce leg: ${(legMap['steps'] as List).length}');
                      
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
                                  debugPrint('🔵 Step $stepIndex: ajouté ${adjustedPoints.length - 1} points (ajustés, total: ${allPoints.length})');
                                } else {
                                  // Premier step : ajouter tous les points
                                  allPoints.addAll(stepPoints);
                                  lastDecodedPoint = stepPoints.last;
                                  debugPrint('🔵 Step $stepIndex: ajouté ${stepPoints.length} points (total: ${allPoints.length})');
                                }
                              }
                            } catch (e) {
                              debugPrint('❌ Erreur lors du décodage d\'une polyligne: $e');
                            }
                          }
                        }
                      }
                    }
                  }
                  
                  if (allPoints.isNotEmpty) {
                    debugPrint('✅ Utilisation des steps détaillés: ${allPoints.length} points au total');
                  }
                }
                
                debugPrint('🔵 Nombre total de points de route obtenus: ${allPoints.length}');
                
                if (allPoints.isNotEmpty) {
                  // Filtrer les points invalides
                  final validPoints = allPoints.where((point) {
                    return point.latitude >= -90 && point.latitude <= 90 &&
                           point.longitude >= -180 && point.longitude <= 180;
                  }).toList();
                  
                  if (validPoints.length != allPoints.length) {
                    debugPrint('⚠️ ${allPoints.length - validPoints.length} points invalides filtrés');
                  }
                  
                  if (validPoints.isNotEmpty) {
                    debugPrint('✅ Route calculée avec succès !');
                    debugPrint('🔵 Premier point: ${validPoints.first.latitude}, ${validPoints.first.longitude}');
                    debugPrint('🔵 Dernier point: ${validPoints.last.latitude}, ${validPoints.last.longitude}');
                    return validPoints;
                  } else {
                    debugPrint('⚠️ Aucun point valide après filtrage');
                  }
                } else {
                  debugPrint('⚠️ Aucun point de route trouvé dans la réponse');
                }
              } else {
                debugPrint('❌ Aucune route trouvée dans la réponse');
              }
        } else {
          final errorMessage = data['error_message'] ?? 'Aucun message';
          debugPrint('❌ Erreur Directions API: ${data['status']}');
          debugPrint('❌ Message d\'erreur: $errorMessage');
          
          if (mounted) {
            String userMessage = 'Erreur lors du calcul de l\'itinéraire';
            if (data['status'] == 'REQUEST_DENIED') {
              userMessage = 'L\'API Directions n\'est pas activée ou la clé API n\'a pas les permissions.';
            } else if (data['status'] == 'OVER_QUERY_LIMIT') {
              userMessage = 'Quota de l\'API Directions dépassé.';
            } else if (data['status'] == 'ZERO_RESULTS') {
              userMessage = 'Aucun itinéraire trouvé entre ces points.';
            } else {
              userMessage = 'Erreur: ${data['status']} - $errorMessage';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(userMessage),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        debugPrint('❌ Réponse du backend invalide: $response');
      }
      
      debugPrint('⚠️ Impossible d\'obtenir la route, retour d\'une liste vide');
      return [];
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur lors de la récupération de la route: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du calcul de l\'itinéraire: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return [];
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
            debugPrint('⚠️ Fin de chaîne inattendue lors du décodage de la latitude à l\'index $index');
            return points;
          }
          byte = encoded.codeUnitAt(index++) - 63;
          if (byte < 0 || byte > 127) {
            debugPrint('⚠️ Byte invalide lors du décodage de la latitude: $byte');
            return points;
          }
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20);
        
        // Décoder le delta de latitude (gestion correcte des valeurs négatives avec complément à deux)
        int dlat;
        if ((result & 1) != 0) {
          // Valeur négative : complément à deux
          // En Dart, ~(result >> 1) peut donner un nombre très grand si result est grand
          // On doit convertir en int signé correctement
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
            debugPrint('⚠️ Fin de chaîne inattendue lors du décodage de la longitude à l\'index $index');
            return points;
          }
          byte = encoded.codeUnitAt(index++) - 63;
          if (byte < 0 || byte > 127) {
            debugPrint('⚠️ Byte invalide lors du décodage de la longitude: $byte');
            return points;
          }
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20);
        
        // Décoder le delta de longitude (gestion correcte des valeurs négatives avec complément à deux)
        int dlng;
        if ((result & 1) != 0) {
          // Valeur négative : complément à deux
          // En Dart, ~(result >> 1) peut donner un nombre très grand si result est grand
          // On doit convertir en int signé correctement
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
          debugPrint('⚠️ Point invalide ignoré: lat=$decodedLat, lng=$decodedLng');
          debugPrint('⚠️ Valeurs brutes: lat=$lat, lng=$lng, dlat=$dlat, dlng=$dlng');
          debugPrint('⚠️ Index: $index/${encoded.length}');
          // Arrêter le décodage si on obtient des coordonnées invalides
          break;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur lors du décodage de la polyligne: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('❌ Index: $index, Longueur: ${encoded.length}');
    }

    if (points.isEmpty) {
      debugPrint('⚠️ Aucun point valide décodé de la polyligne');
    } else if (points.length < 2) {
      debugPrint('⚠️ Moins de 2 points décodés, impossible de tracer une ligne');
    }

    return points;
  }


  Future<void> _updateMarkersAndPolylines() async {
    _markers.clear();
    _polylines.clear();

    // Ajouter les marqueurs
    for (int i = 0; i < _waypoints.length; i++) {
      final waypoint = _waypoints[i];
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

    // Obtenir le tracé de la route qui suit les routes réelles
    if (_waypoints.length >= 2) {
      final routePoints = await _getRoutePoints();
      
      if (routePoints.isNotEmpty) {
        debugPrint('🔵 Création de la polyligne avec ${routePoints.length} points');
        debugPrint('🔵 Premier point: ${routePoints.first.latitude}, ${routePoints.first.longitude}');
        debugPrint('🔵 Dernier point: ${routePoints.last.latitude}, ${routePoints.last.longitude}');
        
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: Colors.blue,
            width: 5,
            geodesic: false, // Important : false pour suivre les routes, pas les lignes droites
          ),
        );
        debugPrint('✅ Polyligne créée et ajoutée à la carte');
      } else {
        // Si on n'a pas de route, afficher un message mais ne pas tracer de ligne droite
        debugPrint('⚠️ Aucune route disponible, pas de tracé affiché');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de calculer l\'itinéraire. Vérifiez que l\'API Directions est activée.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }

    setState(() {});
  }

  void _removeWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
      // Réorganiser les types pour que l'arrivée soit toujours le dernier
      _reorganizeWaypointTypes();
      _updateMarkersAndPolylines();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date et une heure')),
      );
      return;
    }

    if (_waypoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez ajouter au moins un point de départ et un point d\'arrivée')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      _apiService.setToken(token);

      final dateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Préparer les waypoints pour l'API
      final waypointsJson = _waypoints.map((w) => w.toJson()).toList();

      // Extraire le départ et l'arrivée pour compatibilité
      final depart = _waypoints.first;
      final arrivee = _waypoints.last;

      final createdRide = await _apiService.createRide(
        titre: _titreController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        typeVehicule: _typeVehicule,
        date: dateTime.toIso8601String(),
        heure: '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
        lieuDepart: depart.address,
        lieuArrivee: arrivee.address,
        rayon: 0, // Le rayon n'est plus utilisé lors de la création
        visibilite: _visibilite,
        localisation: {
          'latitude': depart.latitude,
          'longitude': depart.longitude,
        },
        waypoints: waypointsJson,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balade créée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(createdRide);
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une balade'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _submitForm,
              tooltip: 'Créer la balade',
            ),
        ],
      ),
      body: Column(
        children: [
          // Carte
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? const LatLng(46.6034, 1.8883), // Centre de la France par défaut
                    zoom: 10.0,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onTap: (LatLng position) {
                    if (!_isAddressMode) {
                      _addWaypointFromMap(position);
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapToolbarEnabled: false,
                ),
                // Instructions
                if (_waypoints.isEmpty)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Appuyez sur la carte pour ajouter des points ou utilisez la saisie d\'adresse',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Formulaire
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Liste des waypoints
                    if (_waypoints.isNotEmpty) ...[
                      const Text(
                        'Points de passage',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_waypoints.length, (index) {
                        final waypoint = _waypoints[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: waypoint.type == 'depart'
                                  ? Colors.green
                                  : waypoint.type == 'arrivee'
                                      ? Colors.red
                                      : Colors.blue,
                              child: Icon(
                                waypoint.type == 'depart'
                                    ? Icons.play_arrow
                                    : waypoint.type == 'arrivee'
                                        ? Icons.flag
                                        : Icons.location_on,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              waypoint.type == 'depart'
                                  ? 'Départ'
                                  : waypoint.type == 'arrivee'
                                      ? 'Arrivée'
                                      : 'Checkpoint ${index}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              waypoint.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeWaypoint(index),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    // Saisie d'adresse
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Ajouter une adresse',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _isAddressMode
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          _isAddressMode = false;
                                          _addressController.clear();
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onSubmitted: (_) => _addWaypointFromAddress(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isAddressMode
                              ? _addWaypointFromAddress
                              : () {
                                  setState(() {
                                    _isAddressMode = true;
                                  });
                                },
                          icon: Icon(_isAddressMode ? Icons.add : Icons.edit_location),
                          label: Text(_isAddressMode ? 'Ajouter' : 'Adresse'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Formulaire principal
                    TextFormField(
                      controller: _titreController,
                      decoration: const InputDecoration(
                        labelText: 'Titre *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Le titre est requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      maxLength: 2000,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _typeVehicule,
                      decoration: const InputDecoration(
                        labelText: 'Type de véhicule *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_car),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'moto', child: Text('🏍️ Moto')),
                        DropdownMenuItem(value: 'voiture', child: Text('🚗 Voiture')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _typeVehicule = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _selectedDate != null
                                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                                    : 'Sélectionner une date',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: _selectTime,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Heure *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              child: Text(
                                _selectedTime != null
                                    ? _selectedTime!.format(context)
                                    : 'Sélectionner une heure',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _visibilite,
                      decoration: const InputDecoration(
                        labelText: 'Visibilité',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.visibility),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'publique', child: Text('🌐 Publique')),
                        DropdownMenuItem(value: 'privee', child: Text('🔒 Privée')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _visibilite = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Options d'itinéraire
                    const Text(
                      'Options d\'itinéraire',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Éviter les péages'),
                      subtitle: const Text('L\'itinéraire évitera les routes à péage'),
                      value: _avoidTolls,
                      onChanged: (value) {
                        setState(() {
                          _avoidTolls = value;
                          // Recalculer la route si on a déjà des waypoints
                          if (_waypoints.length >= 2) {
                            _updateMarkersAndPolylines();
                          }
                        });
                      },
                      secondary: const Icon(Icons.toll),
                    ),
                    SwitchListTile(
                      title: const Text('Éviter les autoroutes'),
                      subtitle: const Text('L\'itinéraire évitera les autoroutes'),
                      value: _avoidHighways,
                      onChanged: (value) {
                        setState(() {
                          _avoidHighways = value;
                          // Recalculer la route si on a déjà des waypoints
                          if (_waypoints.length >= 2) {
                            _updateMarkersAndPolylines();
                          }
                        });
                      },
                      secondary: const Icon(Icons.highway),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submitForm,
                        icon: const Icon(Icons.check),
                        label: const Text('Créer la balade'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

