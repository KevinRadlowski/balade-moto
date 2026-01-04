import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../config/api_config.dart';
import '../api_service.dart';
import '../../models/admin/admin_group.dart';

class AdminGroupsService {
  final ApiService _apiService;

  AdminGroupsService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Récupère la liste des groupes avec pagination et recherche
  Future<Map<String, dynamic>> getGroups({
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

      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/groups')
          .replace(queryParameters: queryParams);

      debugPrint('[AdminGroupsService] GET $uri');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final groupsList = (data['data']?['groups'] as List<dynamic>?)
                ?.map((json) => AdminGroup.fromJson(json))
                .toList() ??
            [];

        return {
          'groups': groupsList,
          'pagination': data['data']?['pagination'] ?? {},
        };
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminGroupsService] Erreur getGroups: $e');
      rethrow;
    }
  }

  /// Supprime un groupe
  Future<void> deleteGroup(String groupId) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/groups/$groupId');

      debugPrint('[AdminGroupsService] DELETE $uri');

      final response = await _apiService.delete(uri);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminGroupsService] Erreur deleteGroup: $e');
      rethrow;
    }
  }
}

