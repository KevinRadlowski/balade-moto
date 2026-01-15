import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../config/api_config.dart';
import '../api_service.dart';
import '../../models/admin/promo_code.dart';

class AdminPromoCodesService {
  final ApiService _apiService;

  AdminPromoCodesService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Génère des codes promotionnels
  /// POST /api/admin/promo-codes/generate
  Future<List<GeneratedPromoCode>> adminGeneratePromoCodes(
    AdminGeneratePromoCodesRequest req,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/promo-codes/generate');

      debugPrint('[AdminPromoCodesService] POST $uri');

      final response = await _apiService.post(
        uri,
        body: jsonEncode(req.toJson()),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final codesList = (data['data']?['codes'] as List<dynamic>?)
                ?.map((json) => GeneratedPromoCode.fromJson(json))
                .toList() ??
            [];

        return codesList;
      } else {
        final errorData = jsonDecode(response.body);
        final message = errorData['message'] ?? 'Erreur lors de la génération des codes';
        final errors = errorData['errors'] as List?;
        if (errors != null && errors.isNotEmpty) {
          final errorMessages = errors.map((e) => e['message'] ?? '').join(', ');
          throw Exception(errorMessages);
        }
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('[AdminPromoCodesService] Erreur adminGeneratePromoCodes: $e');
      rethrow;
    }
  }

  /// Liste les codes promotionnels avec pagination et filtres
  /// GET /api/admin/promo-codes
  Future<PromoCodesPage> adminListPromoCodes({
    bool? active,
    String? type,
    int? limit,
    int? skip,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (active != null) {
        queryParams['active'] = active.toString();
      }
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }
      if (skip != null) {
        queryParams['skip'] = skip.toString();
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/promo-codes')
          .replace(queryParameters: queryParams);

      debugPrint('[AdminPromoCodesService] GET $uri');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PromoCodesPage.fromJson(data['data'] ?? {});
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminPromoCodesService] Erreur adminListPromoCodes: $e');
      rethrow;
    }
  }

  /// Désactive un code promotionnel
  /// PATCH /api/admin/promo-codes/:id/deactivate
  Future<void> adminDeactivatePromoCode(String id) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/promo-codes/$id/deactivate');

      debugPrint('[AdminPromoCodesService] PATCH $uri');

      final response = await _apiService.patch(uri, body: null);

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final message = errorData['message'] ?? 'Erreur lors de la désactivation du code';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('[AdminPromoCodesService] Erreur adminDeactivatePromoCode: $e');
      rethrow;
    }
  }
}







