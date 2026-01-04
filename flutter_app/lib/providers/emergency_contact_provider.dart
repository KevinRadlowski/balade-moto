import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/emergency_contact.dart';
import '../repositories/emergency_contact_repository.dart';
import '../services/api_service.dart';

class EmergencyContactProvider extends ChangeNotifier {
  final EmergencyContactRepository _repository;

  // État
  bool _isLoading = false;
  String? _errorMessage;
  EmergencyContact? _contact;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  EmergencyContact? get contact => _contact;
  bool get hasContact => _contact != null && 
      _contact!.name.isNotEmpty && 
      _contact!.phone.isNotEmpty;

  EmergencyContactProvider({required ApiService apiService})
      : _repository = EmergencyContactRepository(apiService: apiService);

  /// Charger le contact d'urgence
  Future<void> loadContact({bool useCache = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final contact = await _repository.getContact(useCache: useCache);
      _contact = contact;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Si le contact n'est pas configuré, c'est un état normal (pas une erreur)
      if (e.toString().contains('Contact non configuré') || 
          e.toString().contains('Contact non trouvé')) {
        _contact = null;
        _errorMessage = null; // Pas d'erreur, juste pas de contact
        _isLoading = false;
        notifyListeners();
        return;
      }
      // Pour les autres erreurs, afficher le message d'erreur
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[EmergencyContactProvider] Erreur loadContact: $e');
    }
  }

  /// Créer ou mettre à jour le contact
  Future<EmergencyContact> createOrUpdateContact({
    required String name,
    required String phone,
    String? relationship,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final contact = await _repository.createOrUpdateContact(
        name: name,
        phone: phone,
        relationship: relationship,
        notes: notes,
      );

      _contact = contact;
      _isLoading = false;
      notifyListeners();
      return contact;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[EmergencyContactProvider] Erreur createOrUpdateContact: $e');
      rethrow;
    }
  }

  /// Mettre à jour le contact
  Future<EmergencyContact> updateContact({
    String? name,
    String? phone,
    String? relationship,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final contact = await _repository.updateContact(
        name: name,
        phone: phone,
        relationship: relationship,
        notes: notes,
      );

      _contact = contact;
      _isLoading = false;
      notifyListeners();
      return contact;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[EmergencyContactProvider] Erreur updateContact: $e');
      rethrow;
    }
  }

  /// Supprimer le contact
  Future<void> deleteContact() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteContact();
      _contact = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[EmergencyContactProvider] Erreur deleteContact: $e');
      rethrow;
    }
  }

  /// Déclencher une alerte d'urgence
  Future<void> triggerEmergencyAlert({
    required String rideId,
    required String reason,
    Map<String, dynamic>? location,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.triggerEmergencyAlert(
        rideId: rideId,
        reason: reason,
        location: location,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[EmergencyContactProvider] Erreur triggerEmergencyAlert: $e');
      rethrow;
    }
  }

  /// Réinitialiser l'état
  void reset() {
    _contact = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Nettoyer le cache
  void clearCache() {
    _repository.clearCache();
  }
}

