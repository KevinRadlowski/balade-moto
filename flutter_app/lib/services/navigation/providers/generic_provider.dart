import 'navigation_provider.dart';
import 'google_maps_provider.dart';
import '../navigation_service.dart';

/// Provider générique pour les autres apps de navigation
class GenericProvider extends NavigationProvider {
  @override
  String get id => 'generic';

  @override
  String get displayName => 'Autre application';

  @override
  String get iconName => 'phone_android';

  @override
  bool get supportsMultiWaypoints => false;

  @override
  NavigationCapabilities getCapabilities() {
    return NavigationCapabilities(
      supportsMultiWaypoints: false,
      supportsStepByStep: false,
      maxWaypoints: null,
      supportsGPXImport: false,
    );
  }

  @override
  Future<String?> generateUrl(NavigationRoute route) async {
    try {
      // Utiliser le format geo: universel
      // Format: geo:lat,lng?q=lat,lng(label)
      final lat = route.arrival.latitude;
      final lng = route.arrival.longitude;
      final address = route.arrival.address;
      
      return 'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(address)})';
    } catch (e) {
      // Fallback: utiliser Google Maps
      final googleMapsProvider = GoogleMapsProvider();
      return googleMapsProvider.generateUrl(route);
    }
  }
}

