import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/feedback.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class FeedbackRepository {
  final ApiService _apiService;
  
  // Cache léger en mémoire
  final Map<String, List<Feedback>> _feedbacksCache = {};
  final Map<String, AverageRating> _ratingsCache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};

  FeedbackRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Créer un feedback post-balade
  Future<Feedback> createFeedback({
    required String rideId,
    required String feedbackType,
    int? rating,
    String? comment,
    List<String>? categories,
    String? priority,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/feedback/rides/$rideId');
      
      final body = <String, dynamic>{
        'feedbackType': feedbackType,
        if (rating != null) 'rating': rating,
        if (comment != null) 'comment': comment,
        if (categories != null) 'categories': categories,
        if (priority != null) 'priority': priority,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final feedback = Feedback.fromJson(data['data']);
          
          // Invalider le cache
          _feedbacksCache.remove(rideId);
          _ratingsCache.remove(rideId);
          
          return feedback;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la création du feedback');
      }
    } catch (e) {
      debugPrint('[FeedbackRepository] Erreur createFeedback: $e');
      rethrow;
    }
  }

  /// Obtenir les feedbacks d'une balade
  Future<List<Feedback>> getRideFeedbacks({
    required String rideId,
    String? feedbackType,
    String? status,
    bool useCache = true,
  }) async {
    try {
      final cacheKey = '$rideId-$feedbackType-$status';
      
      // Vérifier le cache
      if (useCache && _feedbacksCache.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey];
        if (cacheTime != null && 
            DateTime.now().difference(cacheTime) < _cacheTtl) {
          return _feedbacksCache[cacheKey]!;
        }
      }

      final queryParams = <String, String>{};
      if (feedbackType != null) queryParams['feedbackType'] = feedbackType;
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('${ApiConfig.apiUrl}/feedback/rides/$rideId')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final feedbacks = (data['data'] as List)
              .map((f) => Feedback.fromJson(f))
              .toList();
          
          // Mettre en cache
          _feedbacksCache[cacheKey] = feedbacks;
          _cacheTimestamps[cacheKey] = DateTime.now();
          
          return feedbacks;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des feedbacks');
      }
    } catch (e) {
      debugPrint('[FeedbackRepository] Erreur getRideFeedbacks: $e');
      rethrow;
    }
  }

  /// Obtenir la note moyenne d'une balade
  Future<AverageRating> getAverageRating({
    required String rideId,
    bool useCache = true,
  }) async {
    try {
      // Vérifier le cache
      if (useCache && _ratingsCache.containsKey(rideId)) {
        final cacheTime = _cacheTimestamps['rating-$rideId'];
        if (cacheTime != null && 
            DateTime.now().difference(cacheTime) < _cacheTtl) {
          return _ratingsCache[rideId]!;
        }
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}/feedback/rides/$rideId/rating');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final rating = AverageRating.fromJson(data['data']);
          
          // Mettre en cache
          _ratingsCache[rideId] = rating;
          _cacheTimestamps['rating-$rideId'] = DateTime.now();
          
          return rating;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération de la note moyenne');
      }
    } catch (e) {
      debugPrint('[FeedbackRepository] Erreur getAverageRating: $e');
      rethrow;
    }
  }

  /// Nettoyer le cache
  void clearCache() {
    _feedbacksCache.clear();
    _ratingsCache.clear();
    _cacheTimestamps.clear();
  }
}

