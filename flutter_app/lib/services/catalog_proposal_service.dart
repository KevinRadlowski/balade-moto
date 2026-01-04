import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../config/api_config.dart';
import 'api_service.dart';

/// Service pour créer des propositions de catalogue
class CatalogProposalService {
  final ApiService _apiService;

  CatalogProposalService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Crée une proposition de catalogue
  Future<Map<String, dynamic>?> createProposal({
    required String type,
    required int year,
    required String make,
    required String model,
  }) async {
    try {
      final endpoint = '/catalog/proposals';
      final uri = Uri.parse('${ApiConfig.apiUrl}$endpoint');

      debugPrint('[CatalogProposal] Création proposition: type=$type, year=$year, make=$make, model=$model');

      final response = await _apiService.post(
        uri,
        body: jsonEncode({
          'type': type,
          'year': year,
          'make': make,
          'model': model,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[CatalogProposal] Proposition créée: ${data['data']?['status']}');
        return data['data'];
      } else {
        debugPrint('[CatalogProposal] ERREUR HTTP: statusCode=${response.statusCode}, body=${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[CatalogProposal] ERREUR: $e');
      return null;
    }
  }
}

