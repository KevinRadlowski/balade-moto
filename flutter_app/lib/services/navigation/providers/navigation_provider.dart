import '../navigation_service.dart';

/// Interface de base pour un provider de navigation
abstract class NavigationProvider {
  /// ID unique du provider (ex: 'google_maps', 'waze')
  String get id;

  /// Nom affiché du provider
  String get displayName;

  /// Icône du provider (nom de l'icône Material)
  String get iconName;

  /// Génère l'URL de navigation pour l'itinéraire donné
  Future<String?> generateUrl(NavigationRoute route);

  /// Vérifie si le provider supporte les waypoints multiples
  bool get supportsMultiWaypoints;

  /// Obtient les capacités du provider
  NavigationCapabilities getCapabilities();

  /// Vérifie si l'app est installée (si applicable)
  Future<bool> isAppInstalled() async => true;

  /// Obtient l'URL du store pour installer l'app (si applicable)
  String? getStoreUrl() => null;
}

