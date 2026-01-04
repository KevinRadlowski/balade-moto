import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../config/api_config.dart';
import '../api_service.dart';
import '../../models/admin/admin_ride.dart';

class AdminRidesService {
  final ApiService _apiService;

  AdminRidesService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Récupère la liste des balades avec pagination et recherche
  Future<Map<String, dynamic>> getRides({
    int page = 1,
    int limit = 50,
    String? query,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (query != null && query.isNotEmpty) {
        queryParams['query'] = query;
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/rides')
          .replace(queryParameters: queryParams);

      debugPrint('[AdminRidesService] GET $uri');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ridesList = (data['data']?['rides'] as List<dynamic>?)
                ?.map((json) => AdminRide.fromJson(json))
                .toList() ??
            [];

        return {
          'rides': ridesList,
          'pagination': data['data']?['pagination'] ?? {},
        };
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminRidesService] Erreur getRides: $e');
      rethrow;
    }
  }

  /// Supprime une balade
  Future<void> deleteRide(String rideId) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/rides/$rideId');

      debugPrint('[AdminRidesService] DELETE $uri');

      final response = await _apiService.delete(uri);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminRidesService] Erreur deleteRide: $e');
      rethrow;
    }
  }
}

