import 'dart:math';
import 'navigation_provider.dart';
import '../navigation_service.dart';

/// Provider pour Google Maps avec support complet des waypoints multiples
class GoogleMapsProvider extends NavigationProvider {
  @override
  String get id => 'google_maps';

  @override
  String get displayName => 'Google Maps';

  @override
  String get iconName => 'map';

  @override
  bool get supportsMultiWaypoints => true;

  @override
  NavigationCapabilities getCapabilities() {
    return NavigationCapabilities(
      supportsMultiWaypoints: true,
      supportsStepByStep: false,
      maxWaypoints: 25, // Limite Google Maps
      supportsGPXImport: false,
    );
  }

  @override
  Future<String?> generateUrl(NavigationRoute route) async {
    try {
      final origin = '${route.departure.latitude},${route.departure.longitude}';
      final destination = '${route.arrival.latitude},${route.arrival.longitude}';

      // Limiter à 25 waypoints (limite Google Maps)
      final limitedCheckpoints = route.checkpoints.take(25).toList();

      if (limitedCheckpoints.isEmpty) {
        // Pas de waypoints intermédiaires
        return 'https://www.google.com/maps/dir/?api=1'
            '&origin=$origin'
            '&destination=$destination'
            '&travelmode=driving';
      }

      // Construire la liste des waypoints
      final waypointsList = limitedCheckpoints
          .map((w) => '${w.latitude},${w.longitude}')
          .join('|');

      // Vérifier la longueur de l'URL (limite ~2000 caractères)
      final url = 'https://www.google.com/maps/dir/?api=1'
          '&origin=$origin'
          '&waypoints=$waypointsList'
          '&destination=$destination'
          '&travelmode=driving';

      if (url.length > 2000) {
        // URL trop longue, réduire les waypoints
        final maxWaypoints = _calculateMaxWaypoints(origin, destination);
        final reducedCheckpoints = limitedCheckpoints.take(maxWaypoints).toList();
        final reducedWaypoints = reducedCheckpoints
            .map((w) => '${w.latitude},${w.longitude}')
            .join('|');

        return 'https://www.google.com/maps/dir/?api=1'
            '&origin=$origin'
            '&waypoints=$reducedWaypoints'
            '&destination=$destination'
            '&travelmode=driving';
      }

      return url;
    } catch (e) {
      return null;
    }
  }

  /// Calcule le nombre maximum de waypoints pour rester sous la limite d'URL
  int _calculateMaxWaypoints(String origin, String destination) {
    // URL de base: ~150 caractères
    const baseUrlLength = 150;
    // Chaque waypoint: ~25 caractères (lat,lng)
    const waypointLength = 25;
    const maxUrlLength = 2000;

    final availableLength = maxUrlLength - baseUrlLength - origin.length - destination.length;
    return max(1, (availableLength / waypointLength).floor());
  }
}


