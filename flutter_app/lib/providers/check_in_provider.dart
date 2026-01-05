import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/check_in_status.dart';
import '../repositories/check_in_repository.dart';
import '../services/api_service.dart';

class CheckInProvider extends ChangeNotifier {
  final CheckInRepository _repository;

  // État
  bool _isLoading = false;
  String? _errorMessage;
  CheckInStatus? _status;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  CheckInStatus? get status => _status;
  bool get isActive => _status?.isActive ?? false;

  CheckInProvider({required ApiService apiService})
      : _repository = CheckInRepository(apiService: apiService);

  /// Charger le statut de check-in
  Future<void> loadStatus({bool useCache = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await _repository.getStatus(useCache: useCache);
      _status = status;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[CheckInProvider] Erreur loadStatus: $e');
    }
  }

  /// Envoyer un heartbeat
  Future<void> sendHeartbeat({
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _repository.sendHeartbeat(
        latitude: latitude,
        longitude: longitude,
      );

      // Recharger le statut après l'envoi
      await loadStatus(useCache: false);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      debugPrint('[CheckInProvider] Erreur sendHeartbeat: $e');
      rethrow;
    }
  }

  /// Réinitialiser l'état
  void reset() {
    _status = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Nettoyer le cache
  void clearCache() {
    _repository.clearCache();
  }
}



