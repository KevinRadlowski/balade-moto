import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../config/api_config.dart';
import '../api_service.dart';
import '../../models/admin/catalog_proposal.dart';

class AdminCatalogService {
  final ApiService _apiService;

  AdminCatalogService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Récupère la liste des propositions avec pagination
  Future<Map<String, dynamic>> getProposals({
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/catalog/proposals')
          .replace(queryParameters: queryParams);

      debugPrint('[AdminCatalogService] GET $uri');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final proposalsList = (data['data']?['proposals'] as List<dynamic>?)
                ?.map((json) => CatalogProposal.fromJson(json))
                .toList() ??
            [];

        return {
          'proposals': proposalsList,
          'pagination': data['data']?['pagination'] ?? {},
        };
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminCatalogService] Erreur getProposals: $e');
      rethrow;
    }
  }

  /// Approuve une proposition
  Future<void> approveProposal(String proposalId) async {
    try {
      final uri = Uri.parse(
          '${ApiConfig.apiUrl}/admin/catalog/proposals/$proposalId/approve');

      debugPrint('[AdminCatalogService] POST $uri');

      final response = await _apiService.post(uri);

      if (response.statusCode != 200) {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminCatalogService] Erreur approveProposal: $e');
      rethrow;
    }
  }

  /// Rejette une proposition avec une raison
  Future<void> rejectProposal(String proposalId, String reason) async {
    try {
      final uri = Uri.parse(
          '${ApiConfig.apiUrl}/admin/catalog/proposals/$proposalId/reject');

      debugPrint('[AdminCatalogService] POST $uri (reason: $reason)');

      final response = await _apiService.post(
        uri,
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminCatalogService] Erreur rejectProposal: $e');
      rethrow;
    }
  }
}

