import 'dart:io';
import 'navigation_provider.dart';
import '../navigation_service.dart';
import '../../../models/waypoint.dart';

/// Provider pour Apple Plans (iOS uniquement)
class ApplePlansProvider extends NavigationProvider {
  @override
  String get id => 'apple_plans';

  @override
  String get displayName => 'Plans';

  @override
  String get iconName => 'map';

  @override
  bool get supportsMultiWaypoints => false;

  @override
  NavigationCapabilities getCapabilities() {
    return NavigationCapabilities(
      supportsMultiWaypoints: false,
      supportsStepByStep: true,
      maxWaypoints: null,
      supportsGPXImport: false,
    );
  }

  @override
  Future<bool> isAppInstalled() async {
    // Apple Plans est toujours disponible sur iOS
    return Platform.isIOS;
  }

  @override
  Future<String?> generateUrl(NavigationRoute route) async {
    if (!Platform.isIOS) return null;

    try {
      // Apple Plans utilise le format maps://
      // Format: maps://?daddr=lat,lng
      // Note: Apple Plans ne supporte pas les waypoints multiples dans l'URL
      final lat = route.arrival.latitude;
      final lng = route.arrival.longitude;
      return 'maps://?daddr=$lat,$lng&dirflg=d'; // dirflg=d = en voiture
    } catch (e) {
      return null;
    }
  }

  /// Génère une URL pour un waypoint spécifique (pour le mode par étapes)
  Future<String?> generateUrlForWaypoint(Waypoint waypoint) async {
    if (!Platform.isIOS) return null;

    try {
      final lat = waypoint.latitude;
      final lng = waypoint.longitude;
      return 'maps://?daddr=$lat,$lng&dirflg=d';
    } catch (e) {
      return null;
    }
  }
}

