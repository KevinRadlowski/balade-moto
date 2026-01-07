import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/plan/user_plan.dart';
import '../services/api_service.dart';

class PlanProvider extends ChangeNotifier {
  final ApiService _apiService;

  // État
  UserPlan? _plan;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserPlan? get plan => _plan;
  bool get isLoading => _isLoading;
  String? get error => _error;

  PlanProvider({required ApiService apiService}) : _apiService = apiService;

  /// Charge le plan de l'utilisateur
  /// [silent] : si true, n'affiche pas d'erreur UI (juste met error)
  Future<void> loadPlan({bool silent = false}) async {
    _isLoading = true;
    if (!silent) {
      _error = null;
    }
    notifyListeners();

    try {
      final plan = await _apiService.getMyPlan();
      _plan = plan;
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('[PlanProvider] Erreur loadPlan: $e');
      
      // Si silent, on ne relance pas l'exception
      if (!silent) {
        rethrow;
      }
    }
  }

  /// Rafraîchit le plan (alias de loadPlan)
  Future<void> refreshPlan() async {
    await loadPlan(silent: false);
  }

  /// Nettoie le plan (appelé lors du logout)
  void clear() {
    _plan = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // ==================== HELPERS ====================

  /// Vérifie si l'utilisateur a un plan premium actif
  bool get isPremium {
    if (_plan == null) return false; // Par sécurité, considérer FREE
    return _plan!.isPremiumActive;
  }

  /// Vérifie si l'utilisateur peut créer une balade privée
  bool get canCreatePrivateRide {
    if (_plan == null) {
      // Par sécurité UX, considérer FREE (pas de balades privées)
      return false;
    }
    return _plan!.remainingPrivateRidesThisMonth > 0;
  }

  /// Vérifie si l'utilisateur peut créer un groupe privé
  bool get canCreatePrivateGroup {
    if (_plan == null) {
      // Par sécurité UX, considérer FREE (pas de groupes privés)
      return false;
    }
    return _plan!.remainingPrivateGroups > 0;
  }

  /// Vérifie si l'utilisateur peut ajouter un véhicule du type spécifié
  /// Vérifie à la fois la limite totale et la limite par type
  bool canAddVehicle(String type) {
    if (_plan == null) {
      // Par sécurité UX, considérer FREE (limite basse, généralement 0)
      return false;
    }

    // Si illimité, toujours autoriser
    if (_plan!.unlimited) {
      return true;
    }

    // Vérifier la limite totale
    if (_plan!.remainingVehiclesTotal <= 0) {
      return false;
    }

    // Vérifier la limite par type
    final normalizedType = type.toLowerCase();
    if (normalizedType == 'moto') {
      return _plan!.remainingVehiclesMoto > 0;
    } else if (normalizedType == 'voiture') {
      return _plan!.remainingVehiclesVoiture > 0;
    }

    // Type inconnu, utiliser la limite totale
    return _plan!.remainingVehiclesTotal > 0;
  }

  /// Vérifie si l'utilisateur peut ajouter un certain nombre de photos
  /// Note: Cette méthode vérifie la limite par véhicule
  bool canAddPhotos(int howMany) {
    if (_plan == null) {
      // Par sécurité UX, considérer FREE (limite basse)
      return false;
    }

    if (_plan!.unlimited) {
      return true;
    }

    final limit = _plan!.limits?.maxPhotosTotal;
    if (limit == null) {
      // Pas de limite définie = illimité
      return true;
    }

    // Vérifier si on peut ajouter le nombre demandé
    // Note: L'usage réel par véhicule n'est pas stocké dans plan.usage
    // Cette vérification devrait être faite côté backend avec le véhicule spécifique
    // Pour l'instant, on vérifie juste que la limite existe et est suffisante
    return howMany <= limit;
  }
}

