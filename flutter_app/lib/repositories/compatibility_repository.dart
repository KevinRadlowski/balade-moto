import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/compatibility.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class CompatibilityRepository {
  final ApiService _apiService;
  
  // Cache léger
  final Map<String, Compatibility> _compatibilityCache = {};
  static const Duration _cacheTtl = Duration(minutes: 10);
  final Map<String, DateTime> _cacheTimestamps = {};

  CompatibilityRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Vérifier la compatibilité entre deux utilisateurs
  Future<Compatibility> checkCompatibility({
    required String userId1,
    required String userId2,
    String? rideId,
    bool useCache = true,
  }) async {
    try {
      final cacheKey = '$userId1-$userId2-${rideId ?? ''}';
      
      // Vérifier le cache
      if (useCache && _compatibilityCache.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey];
        if (cacheTime != null && 
            DateTime.now().difference(cacheTime) < _cacheTtl) {
          return _compatibilityCache[cacheKey]!;
        }
      }

      final queryParams = <String, String>{
        'userId1': userId1,
        'userId2': userId2,
      };
      if (rideId != null) queryParams['rideId'] = rideId;

      final uri = Uri.parse('${ApiConfig.apiUrl}/compatibility/check')
          .replace(queryParameters: queryParams);

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final compatibility = Compatibility.fromJson(data['data']);
          
          // Mettre en cache
          _compatibilityCache[cacheKey] = compatibility;
          _cacheTimestamps[cacheKey] = DateTime.now();
          
          return compatibility;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la vérification de compatibilité');
      }
    } catch (e) {
      debugPrint('[CompatibilityRepository] Erreur checkCompatibility: $e');
      rethrow;
    }
  }

  /// Nettoyer le cache
  void clearCache() {
    _compatibilityCache.clear();
    _cacheTimestamps.clear();
  }
}


