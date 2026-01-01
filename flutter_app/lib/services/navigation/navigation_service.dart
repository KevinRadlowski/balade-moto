import '../../models/waypoint.dart';
import 'providers/navigation_provider.dart';
import 'providers/google_maps_provider.dart';
import 'providers/waze_provider.dart';
import 'providers/apple_plans_provider.dart';
import 'providers/generic_provider.dart';

/// Service centralisé pour la navigation avec support multi-providers
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final Map<String, NavigationProvider> _providers = {
    'google_maps': GoogleMapsProvider(),
    'waze': WazeProvider(),
    'apple_plans': ApplePlansProvider(),
    'generic': GenericProvider(),
  };

  /// Normalise les waypoints (enlève doublons, limite le nombre, trie)
  List<Waypoint> normalizeWaypoints(List<Waypoint> waypoints, {int? maxWaypoints}) {
    if (waypoints.isEmpty) return [];

    // Trier par ordre
    final sorted = List<Waypoint>.from(waypoints)
      ..sort((a, b) => a.order.compareTo(b.order));

    // Enlever les doublons (même lat/lng)
    final unique = <String, Waypoint>{};
    for (final wp in sorted) {
      final key = '${wp.latitude.toStringAsFixed(6)}_${wp.longitude.toStringAsFixed(6)}';
      if (!unique.containsKey(key)) {
        unique[key] = wp;
      }
    }

    final result = unique.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // Limiter le nombre si nécessaire
    if (maxWaypoints != null && result.length > maxWaypoints) {
      // Garder départ, arrivée, et les premiers checkpoints
      final departure = result.firstWhere(
        (w) => w.type == 'depart',
        orElse: () => result.first,
      );
      final arrival = result.firstWhere(
        (w) => w.type == 'arrivee',
        orElse: () => result.last,
      );
      final checkpoints = result
          .where((w) => w.type == 'checkpoint')
          .take(maxWaypoints - 2)
          .toList();

      return [departure, ...checkpoints, arrival];
    }

    return result;
  }

  /// Extrait départ, checkpoints et arrivée d'une liste de waypoints
  NavigationRoute extractRoute(List<Waypoint> waypoints) {
    if (waypoints.isEmpty) {
      throw ArgumentError('La liste de waypoints ne peut pas être vide');
    }
    
    final normalized = normalizeWaypoints(waypoints);
    
    // Trier par ordre pour s'assurer que l'ordre est correct
    final sorted = List<Waypoint>.from(normalized)
      ..sort((a, b) => a.order.compareTo(b.order));
    
    final departure = sorted.firstWhere(
      (w) => w.type == 'depart',
      orElse: () => sorted.first,
    );
    final arrival = sorted.firstWhere(
      (w) => w.type == 'arrivee',
      orElse: () => sorted.last,
    );
    final checkpoints = sorted
        .where((w) => w.type == 'checkpoint')
        .toList();

    return NavigationRoute(
      departure: departure,
      checkpoints: checkpoints,
      arrival: arrival,
    );
  }

  /// Obtient un provider par son ID
  NavigationProvider? getProvider(String providerId) {
    return _providers[providerId];
  }

  /// Liste tous les providers disponibles
  List<NavigationProvider> getAllProviders() {
    return _providers.values.toList();
  }

  /// Génère une URL de navigation pour un provider donné
  Future<String?> generateNavigationUrl(
    String providerId,
    NavigationRoute route,
  ) async {
    final provider = getProvider(providerId);
    if (provider == null) return null;

    return provider.generateUrl(route);
  }

  /// Vérifie si un provider supporte les waypoints multiples
  bool supportsMultiWaypoints(String providerId) {
    final provider = getProvider(providerId);
    return provider?.supportsMultiWaypoints ?? false;
  }

  /// Obtient les capacités d'un provider
  NavigationCapabilities getCapabilities(String providerId) {
    final provider = getProvider(providerId);
    return provider?.getCapabilities() ?? NavigationCapabilities.none();
  }
}

/// Représente un itinéraire de navigation
class NavigationRoute {
  final Waypoint departure;
  final List<Waypoint> checkpoints;
  final Waypoint arrival;

  NavigationRoute({
    required this.departure,
    required this.checkpoints,
    required this.arrival,
  });

  List<Waypoint> get allWaypoints => [
        departure,
        ...checkpoints,
        arrival,
      ];

  int get totalPoints => 1 + checkpoints.length + 1;
}

/// Capacités d'un provider de navigation
class NavigationCapabilities {
  final bool supportsMultiWaypoints;
  final bool supportsStepByStep;
  final int? maxWaypoints;
  final bool supportsGPXImport;

  NavigationCapabilities({
    required this.supportsMultiWaypoints,
    required this.supportsStepByStep,
    this.maxWaypoints,
    required this.supportsGPXImport,
  });

  factory NavigationCapabilities.none() {
    return NavigationCapabilities(
      supportsMultiWaypoints: false,
      supportsStepByStep: false,
      supportsGPXImport: false,
    );
  }

  factory NavigationCapabilities.full() {
    return NavigationCapabilities(
      supportsMultiWaypoints: true,
      supportsStepByStep: false,
      maxWaypoints: null, // Illimité
      supportsGPXImport: false,
    );
  }
}

