import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../models/waypoint.dart';
import '../navigation/navigation_service.dart';

/// Service pour gérer la navigation par étapes (Waze, Apple Plans, etc.)
class StepByStepNavigationService {
  static const String _prefsKeyPrefix = 'step_nav_';
  static const String _currentStepKey = 'current_step';
  static const String _routeKey = 'route';
  static const String _providerKey = 'provider';

  /// Démarre une navigation par étapes
  Future<void> startStepNavigation({
    required String rideId,
    required NavigationRoute route,
    required String providerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Sauvegarder la route
    final routeJson = {
      'departure': {
        'type': route.departure.type,
        'address': route.departure.address,
        'latitude': route.departure.latitude,
        'longitude': route.departure.longitude,
        'order': route.departure.order,
      },
      'checkpoints': route.checkpoints.map((w) => {
        'type': w.type,
        'address': w.address,
        'latitude': w.latitude,
        'longitude': w.longitude,
        'order': w.order,
      }).toList(),
      'arrival': {
        'type': route.arrival.type,
        'address': route.arrival.address,
        'latitude': route.arrival.latitude,
        'longitude': route.arrival.longitude,
        'order': route.arrival.order,
      },
    };

    await prefs.setString('$_prefsKeyPrefix$rideId$_routeKey', jsonEncode(routeJson));
    await prefs.setString('$_prefsKeyPrefix$rideId$_providerKey', providerId);
    await prefs.setInt('$_prefsKeyPrefix$rideId$_currentStepKey', 0);
  }

  /// Récupère la navigation par étapes en cours pour une balade
  Future<StepNavigationState?> getStepNavigation(String rideId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final routeJsonStr = prefs.getString('$_prefsKeyPrefix$rideId$_routeKey');
    final providerId = prefs.getString('$_prefsKeyPrefix$rideId$_providerKey');
    final currentStep = prefs.getInt('$_prefsKeyPrefix$rideId$_currentStepKey');

    if (routeJsonStr == null || providerId == null || currentStep == null) {
      return null;
    }

    try {
      final routeJson = jsonDecode(routeJsonStr) as Map<String, dynamic>;
      
      final departureJson = routeJson['departure'] as Map<String, dynamic>;
      final departure = Waypoint(
        type: departureJson['type'] as String,
        address: departureJson['address'] as String,
        latitude: (departureJson['latitude'] as num).toDouble(),
        longitude: (departureJson['longitude'] as num).toDouble(),
        order: departureJson['order'] as int,
      );

      final checkpointsJson = routeJson['checkpoints'] as List;
      final checkpoints = checkpointsJson
          .map((w) {
            final wpJson = w as Map<String, dynamic>;
            return Waypoint(
              type: wpJson['type'] as String,
              address: wpJson['address'] as String,
              latitude: (wpJson['latitude'] as num).toDouble(),
              longitude: (wpJson['longitude'] as num).toDouble(),
              order: wpJson['order'] as int,
            );
          })
          .toList();

      final arrivalJson = routeJson['arrival'] as Map<String, dynamic>;
      final arrival = Waypoint(
        type: arrivalJson['type'] as String,
        address: arrivalJson['address'] as String,
        latitude: (arrivalJson['latitude'] as num).toDouble(),
        longitude: (arrivalJson['longitude'] as num).toDouble(),
        order: arrivalJson['order'] as int,
      );

      final route = NavigationRoute(
        departure: departure,
        checkpoints: checkpoints,
        arrival: arrival,
      );

      return StepNavigationState(
        rideId: rideId,
        route: route,
        providerId: providerId,
        currentStepIndex: currentStep,
      );
    } catch (e) {
      // En cas d'erreur, nettoyer les données corrompues
      debugPrint('Erreur lors de la récupération de la navigation par étapes: $e');
      return null;
    }
  }

  /// Passe à l'étape suivante
  Future<void> nextStep(String rideId) async {
    final state = await getStepNavigation(rideId);
    if (state == null) return;

    final prefs = await SharedPreferences.getInstance();
    final totalSteps = state.route.allWaypoints.length;
    
    if (state.currentStepIndex < totalSteps - 1) {
      await prefs.setInt('$_prefsKeyPrefix$rideId$_currentStepKey', state.currentStepIndex + 1);
    }
  }

  /// Revient à l'étape précédente
  Future<void> previousStep(String rideId) async {
    final state = await getStepNavigation(rideId);
    if (state == null) return;

    final prefs = await SharedPreferences.getInstance();
    
    if (state.currentStepIndex > 0) {
      await prefs.setInt('$_prefsKeyPrefix$rideId$_currentStepKey', state.currentStepIndex - 1);
    }
  }

  /// Réinitialise la navigation par étapes
  Future<void> resetStepNavigation(String rideId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsKeyPrefix$rideId$_routeKey');
    await prefs.remove('$_prefsKeyPrefix$rideId$_providerKey');
    await prefs.remove('$_prefsKeyPrefix$rideId$_currentStepKey');
  }

  /// Obtient le waypoint actuel pour la navigation par étapes
  Future<Waypoint?> getCurrentWaypoint(String rideId) async {
    final state = await getStepNavigation(rideId);
    if (state == null) return null;

    final allWaypoints = state.route.allWaypoints;
    if (state.currentStepIndex >= 0 && state.currentStepIndex < allWaypoints.length) {
      return allWaypoints[state.currentStepIndex];
    }
    return null;
  }

  /// Obtient le waypoint suivant
  Future<Waypoint?> getNextWaypoint(String rideId) async {
    final state = await getStepNavigation(rideId);
    if (state == null) return null;

    final allWaypoints = state.route.allWaypoints;
    final nextIndex = state.currentStepIndex + 1;
    if (nextIndex < allWaypoints.length) {
      return allWaypoints[nextIndex];
    }
    return null;
  }

  /// Vérifie si la navigation par étapes est terminée
  Future<bool> isCompleted(String rideId) async {
    final state = await getStepNavigation(rideId);
    if (state == null) return false;

    final totalSteps = state.route.allWaypoints.length;
    return state.currentStepIndex >= totalSteps - 1;
  }
}

/// État de la navigation par étapes
class StepNavigationState {
  final String rideId;
  final NavigationRoute route;
  final String providerId;
  final int currentStepIndex;

  StepNavigationState({
    required this.rideId,
    required this.route,
    required this.providerId,
    required this.currentStepIndex,
  });

  List<Waypoint> get allWaypoints => route.allWaypoints;
  Waypoint? get currentWaypoint {
    if (currentStepIndex >= 0 && currentStepIndex < allWaypoints.length) {
      return allWaypoints[currentStepIndex];
    }
    return null;
  }

  Waypoint? get nextWaypoint {
    final nextIndex = currentStepIndex + 1;
    if (nextIndex < allWaypoints.length) {
      return allWaypoints[nextIndex];
    }
    return null;
  }

  bool get isCompleted => currentStepIndex >= allWaypoints.length - 1;
  bool get hasPrevious => currentStepIndex > 0;
  bool get hasNext => currentStepIndex < allWaypoints.length - 1;
}

