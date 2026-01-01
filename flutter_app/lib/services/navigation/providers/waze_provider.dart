import 'navigation_provider.dart';
import '../navigation_service.dart';
import '../../../models/waypoint.dart';

/// Provider pour Waze (ne supporte pas les waypoints multiples dans l'URL)
class WazeProvider extends NavigationProvider {
  @override
  String get id => 'waze';

  @override
  String get displayName => 'Waze';

  @override
  String get iconName => 'navigation';

  @override
  bool get supportsMultiWaypoints => false;

  @override
  NavigationCapabilities getCapabilities() {
    return NavigationCapabilities(
      supportsMultiWaypoints: false,
      supportsStepByStep: true, // Mode par étapes recommandé
      maxWaypoints: null,
      supportsGPXImport: false,
    );
  }

  @override
  Future<String?> generateUrl(NavigationRoute route) async {
    // Waze ne supporte qu'une seule destination dans l'URL
    // On retourne l'URL vers l'arrivée
    // Le mode par étapes sera géré par StepByStepNavigationService
    try {
      final lat = route.arrival.latitude;
      final lng = route.arrival.longitude;

      // Essayer plusieurs formats (le premier est le plus fiable)
      return 'waze://?ll=$lat,$lng&navigate=yes';
    } catch (e) {
      return null;
    }
  }

  /// Génère une URL pour un waypoint spécifique (pour le mode par étapes)
  Future<String?> generateUrlForWaypoint(Waypoint waypoint) async {
    try {
      final lat = waypoint.latitude;
      final lng = waypoint.longitude;
      return 'waze://?ll=$lat,$lng&navigate=yes';
    } catch (e) {
      return null;
    }
  }

  @override
  String? getStoreUrl() {
    // URLs des stores pour Waze
    return 'https://www.waze.com/get';
  }
}

