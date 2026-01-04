import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/check_in_status.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class CheckInRepository {
  final ApiService _apiService;
  
  // Cache léger
  CheckInStatus? _cachedStatus;
  DateTime? _lastFetch;
  static const Duration _cacheTtl = Duration(seconds: 30);

  CheckInRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Envoyer un heartbeat de check-in
  Future<void> sendHeartbeat({
    double? latitude,
    double? longitude,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/check-in/heartbeat');
      
      final body = <String, dynamic>{
        if (latitude != null && longitude != null)
          'location': {
            'latitude': latitude,
            'longitude': longitude,
          },
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de l\'envoi du heartbeat');
      }
      
      // Invalider le cache pour forcer un refresh
      _cachedStatus = null;
      _lastFetch = null;
    } catch (e) {
      debugPrint('[CheckInRepository] Erreur sendHeartbeat: $e');
      rethrow;
    }
  }

  /// Obtenir le statut de check-in
  Future<CheckInStatus> getStatus({bool useCache = true}) async {
    try {
      // Vérifier le cache
      if (useCache && 
          _cachedStatus != null && 
          _lastFetch != null &&
          DateTime.now().difference(_lastFetch!) < _cacheTtl) {
        return _cachedStatus!;
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}/check-in/status');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final status = CheckInStatus.fromJson(data['data']);
          _cachedStatus = status;
          _lastFetch = DateTime.now();
          return status;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération du statut');
      }
    } catch (e) {
      debugPrint('[CheckInRepository] Erreur getStatus: $e');
      rethrow;
    }
  }

  /// Nettoyer le cache
  void clearCache() {
    _cachedStatus = null;
    _lastFetch = null;
  }
}

