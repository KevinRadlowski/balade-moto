import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/vehicle_stats.dart';
import '../repositories/vehicle_stats_repository.dart';
import '../services/api_service.dart';

class VehicleStatsProvider extends ChangeNotifier {
  final VehicleStatsRepository _repository;

  // État
  bool _isLoading = false;
  String? _errorMessage;
  final Map<String, VehicleStats> _statsByVehicle = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  VehicleStatsProvider({required ApiService apiService})
      : _repository = VehicleStatsRepository(apiService: apiService);

  /// Obtenir les statistiques d'un véhicule
  Future<VehicleStats> getVehicleStats({
    required String vehicleId,
    bool useCache = true,
  }) async {
    // Retourner depuis le cache si disponible
    if (useCache && _statsByVehicle.containsKey(vehicleId)) {
      return _statsByVehicle[vehicleId]!;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final stats = await _repository.getVehicleStats(
        vehicleId: vehicleId,
        useCache: useCache,
      );

      _statsByVehicle[vehicleId] = stats;
      _isLoading = false;
      notifyListeners();
      return stats;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[VehicleStatsProvider] Erreur getVehicleStats: $e');
      rethrow;
    }
  }

  /// Obtenir les stats depuis le cache
  VehicleStats? getCachedStats(String vehicleId) {
    return _statsByVehicle[vehicleId];
  }

  /// Réinitialiser l'état
  void reset() {
    _statsByVehicle.clear();
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Nettoyer le cache pour un véhicule
  void clearCacheForVehicle(String vehicleId) {
    _statsByVehicle.remove(vehicleId);
    _repository.clearCacheForVehicle(vehicleId);
    notifyListeners();
  }

  /// Nettoyer tout le cache
  void clearCache() {
    _statsByVehicle.clear();
    _repository.clearCache();
    notifyListeners();
  }
}






