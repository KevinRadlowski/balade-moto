import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/live_ride.dart';
import '../repositories/live_ride_repository.dart';
import '../services/api_service.dart';

class LiveRideProvider extends ChangeNotifier {
  final LiveRideRepository _repository;

  // État
  bool _isLoading = false;
  String? _errorMessage;
  LiveRideState? _currentState;
  String? _activeRideId;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  LiveRideState? get currentState => _currentState;
  String? get activeRideId => _activeRideId;
  bool get isActive => _currentState != null && _activeRideId != null;
  
  /// Vérifier si la balade est en pause (dernier événement = 'paused')
  bool get isPaused {
    if (_currentState == null) return false;
    final lastEvent = _currentState!.lastEvent;
    return lastEvent != null && lastEvent.type == 'paused';
  }

  LiveRideProvider({required ApiService apiService})
      : _repository = LiveRideRepository(apiService: apiService);

  /// Démarrer une balade en direct
  Future<LiveRideState> startLiveRide({
    required String rideId,
    Map<String, dynamic>? location,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final state = await _repository.startLiveRide(
        rideId: rideId,
        location: location,
      );

      _currentState = state;
      _activeRideId = rideId;
      _isLoading = false;
      notifyListeners();
      return state;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[LiveRideProvider] Erreur startLiveRide: $e');
      rethrow;
    }
  }

  /// Mettre en pause
  Future<LiveRideState> pauseLiveRide({
    Map<String, dynamic>? location,
  }) async {
    if (_activeRideId == null) {
      throw Exception('Aucune balade active');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final state = await _repository.pauseLiveRide(
        rideId: _activeRideId!,
        location: location,
      );

      _currentState = state;
      _isLoading = false;
      notifyListeners();
      return state;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[LiveRideProvider] Erreur pauseLiveRide: $e');
      rethrow;
    }
  }

  /// Reprendre une balade en pause
  Future<LiveRideState> resumeLiveRide({
    Map<String, dynamic>? location,
  }) async {
    if (_activeRideId == null) {
      throw Exception('Aucune balade active');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final state = await _repository.resumeLiveRide(
        rideId: _activeRideId!,
        location: location,
      );

      _currentState = state;
      _isLoading = false;
      notifyListeners();
      return state;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[LiveRideProvider] Erreur resumeLiveRide: $e');
      rethrow;
    }
  }

  /// Terminer la balade
  Future<LiveRideState> endLiveRide({
    Map<String, dynamic>? location,
    Map<String, dynamic>? summary,
  }) async {
    if (_activeRideId == null) {
      throw Exception('Aucune balade active');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final state = await _repository.endLiveRide(
        rideId: _activeRideId!,
        location: location,
        summary: summary,
      );

      _currentState = state;
      _isLoading = false;
      notifyListeners();
      return state;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[LiveRideProvider] Erreur endLiveRide: $e');
      rethrow;
    }
  }

  /// Signaler un incident
  Future<LiveRideState> reportIncident({
    required String incidentType,
    Map<String, dynamic>? location,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    if (_activeRideId == null) {
      throw Exception('Aucune balade active');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final state = await _repository.reportIncident(
        rideId: _activeRideId!,
        incidentType: incidentType,
        location: location,
        description: description,
        metadata: metadata,
      );

      _currentState = state;
      _isLoading = false;
      notifyListeners();
      return state;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[LiveRideProvider] Erreur reportIncident: $e');
      rethrow;
    }
  }

  /// Obtenir l'état actuel
  Future<void> refreshStatus({bool useCache = true, String? rideId}) async {
    final targetRideId = rideId ?? _activeRideId;
    
    if (targetRideId == null) {
      return;
    }

    try {
      final state = await _repository.getLiveRideStatus(
        rideId: targetRideId,
        useCache: useCache,
      );

      _currentState = state;
      // Si on a fourni un rideId et qu'il n'y avait pas d'activeRideId, le définir
      if (rideId != null && _activeRideId == null) {
        _activeRideId = rideId;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[LiveRideProvider] Erreur refreshStatus: $e');
      rethrow; // Re-lancer l'erreur pour que l'appelant puisse la gérer
    }
  }

  /// Envoyer un heartbeat
  Future<void> sendHeartbeat({
    Map<String, dynamic>? location,
  }) async {
    if (_activeRideId == null) return;

    try {
      await _repository.sendHeartbeat(
        rideId: _activeRideId!,
        location: location,
      );
    } catch (e) {
      debugPrint('[LiveRideProvider] Erreur sendHeartbeat: $e');
    }
  }

  /// Réinitialiser l'état
  void reset() {
    _currentState = null;
    _activeRideId = null;
    _errorMessage = null;
    _isLoading = false;
    _repository.clearCache();
    notifyListeners();
  }
}

