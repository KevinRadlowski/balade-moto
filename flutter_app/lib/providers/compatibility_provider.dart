import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/compatibility.dart';
import '../repositories/compatibility_repository.dart';
import '../services/api_service.dart';

class CompatibilityProvider extends ChangeNotifier {
  final CompatibilityRepository _repository;

  // État
  bool _isLoading = false;
  String? _errorMessage;
  Compatibility? _currentCompatibility;
  String? _userId1;
  String? _userId2;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Compatibility? get currentCompatibility => _currentCompatibility;

  CompatibilityProvider({required ApiService apiService})
      : _repository = CompatibilityRepository(apiService: apiService);

  /// Vérifier la compatibilité
  Future<Compatibility> checkCompatibility({
    required String userId1,
    required String userId2,
    String? rideId,
    bool useCache = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _userId1 = userId1;
    _userId2 = userId2;
    notifyListeners();

    try {
      final compatibility = await _repository.checkCompatibility(
        userId1: userId1,
        userId2: userId2,
        rideId: rideId,
        useCache: useCache,
      );

      _currentCompatibility = compatibility;
      _isLoading = false;
      notifyListeners();
      return compatibility;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[CompatibilityProvider] Erreur checkCompatibility: $e');
      rethrow;
    }
  }

  /// Réinitialiser l'état
  void reset() {
    _currentCompatibility = null;
    _userId1 = null;
    _userId2 = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Nettoyer le cache
  void clearCache() {
    _repository.clearCache();
  }
}




