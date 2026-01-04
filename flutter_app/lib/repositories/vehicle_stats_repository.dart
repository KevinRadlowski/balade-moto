import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/vehicle_stats.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class VehicleStatsRepository {
  final ApiService _apiService;
  
  // Cache léger
  final Map<String, VehicleStats> _statsCache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};

  VehicleStatsRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Obtenir les statistiques d'un véhicule
  Future<VehicleStats> getVehicleStats({
    required String vehicleId,
    bool useCache = true,
  }) async {
    try {
      // Vérifier le cache
      if (useCache && _statsCache.containsKey(vehicleId)) {
        final cacheTime = _cacheTimestamps[vehicleId];
        if (cacheTime != null && 
            DateTime.now().difference(cacheTime) < _cacheTtl) {
          return _statsCache[vehicleId]!;
        }
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}/garage/vehicles/$vehicleId/stats');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Le backend retourne { data: { stats: {...} } }
          final dataObj = data['data'];
          final statsData = dataObj is Map && dataObj.containsKey('stats')
              ? dataObj['stats']
              : dataObj;
          final stats = VehicleStats.fromJson(statsData);
          
          // Mettre en cache
          _statsCache[vehicleId] = stats;
          _cacheTimestamps[vehicleId] = DateTime.now();
          
          return stats;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des statistiques');
      }
    } catch (e) {
      debugPrint('[VehicleStatsRepository] Erreur getVehicleStats: $e');
      rethrow;
    }
  }

  /// Nettoyer le cache pour un véhicule spécifique
  void clearCacheForVehicle(String vehicleId) {
    _statsCache.remove(vehicleId);
    _cacheTimestamps.remove(vehicleId);
  }

  /// Nettoyer tout le cache
  void clearCache() {
    _statsCache.clear();
    _cacheTimestamps.clear();
  }
}

