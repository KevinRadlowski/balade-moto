import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/feedback.dart';
import '../repositories/feedback_repository.dart';
import '../services/api_service.dart';

class FeedbackProvider extends ChangeNotifier {
  final FeedbackRepository _repository;

  // État
  bool _isLoading = false;
  String? _errorMessage;
  List<Feedback> _feedbacks = [];
  AverageRating? _averageRating;
  String? _currentRideId;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Feedback> get feedbacks => _feedbacks;
  AverageRating? get averageRating => _averageRating;
  String? get currentRideId => _currentRideId;

  FeedbackProvider({required ApiService apiService})
      : _repository = FeedbackRepository(apiService: apiService);

  /// Créer un feedback
  Future<Feedback> createFeedback({
    required String rideId,
    required String feedbackType,
    int? rating,
    String? comment,
    List<String>? categories,
    String? priority,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final feedback = await _repository.createFeedback(
        rideId: rideId,
        feedbackType: feedbackType,
        rating: rating,
        comment: comment,
        categories: categories,
        priority: priority,
      );

      // Recharger les feedbacks si c'est pour la même balade
      if (_currentRideId == rideId) {
        await loadFeedbacks(rideId: rideId);
        await loadAverageRating(rideId: rideId);
      }

      _isLoading = false;
      notifyListeners();
      return feedback;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Charger les feedbacks d'une balade
  Future<void> loadFeedbacks({
    required String rideId,
    String? feedbackType,
    String? status,
    bool useCache = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _currentRideId = rideId;
    notifyListeners();

    try {
      final feedbacks = await _repository.getRideFeedbacks(
        rideId: rideId,
        feedbackType: feedbackType,
        status: status,
        useCache: useCache,
      );

      _feedbacks = feedbacks;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[FeedbackProvider] Erreur loadFeedbacks: $e');
    }
  }

  /// Charger la note moyenne
  Future<void> loadAverageRating({
    required String rideId,
    bool useCache = true,
  }) async {
    try {
      final rating = await _repository.getAverageRating(
        rideId: rideId,
        useCache: useCache,
      );

      _averageRating = rating;
      notifyListeners();
    } catch (e) {
      debugPrint('[FeedbackProvider] Erreur loadAverageRating: $e');
    }
  }

  /// Réinitialiser l'état
  void reset() {
    _feedbacks = [];
    _averageRating = null;
    _currentRideId = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Nettoyer le cache
  void clearCache() {
    _repository.clearCache();
  }
}







