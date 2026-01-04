import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/emergency_contact.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class EmergencyContactRepository {
  final ApiService _apiService;
  
  // Cache léger
  EmergencyContact? _cachedContact;
  DateTime? _lastFetch;
  static const Duration _cacheTtl = Duration(minutes: 10);

  EmergencyContactRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Créer ou mettre à jour le contact d'urgence
  Future<EmergencyContact> createOrUpdateContact({
    required String name,
    required String phone,
    String? relationship,
    String? notes,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/user/emergency-contact');
      
      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        if (relationship != null) 'relationship': relationship,
        if (notes != null) 'notes': notes,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Le backend retourne { data: { contact: {...} } }
          final dataObj = data['data'];
          final contactData = dataObj is Map && dataObj.containsKey('contact')
              ? dataObj['contact']
              : dataObj;
          final contact = EmergencyContact.fromJson(contactData);
          _cachedContact = contact;
          _lastFetch = DateTime.now();
          return contact;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la sauvegarde du contact');
      }
    } catch (e) {
      debugPrint('[EmergencyContactRepository] Erreur createOrUpdateContact: $e');
      rethrow;
    }
  }

  /// Obtenir le contact d'urgence
  Future<EmergencyContact> getContact({bool useCache = true}) async {
    try {
      // Vérifier le cache
      if (useCache && 
          _cachedContact != null && 
          _lastFetch != null &&
          DateTime.now().difference(_lastFetch!) < _cacheTtl) {
        return _cachedContact!;
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}/user/emergency-contact');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Le backend retourne { data: { contact: {...} } }
          final dataObj = data['data'];
          final contactData = dataObj is Map && dataObj.containsKey('contact')
              ? dataObj['contact']
              : dataObj;
          if (contactData == null) {
            throw Exception('Contact non trouvé');
          }
          final contact = EmergencyContact.fromJson(contactData);
          _cachedContact = contact;
          _lastFetch = DateTime.now();
          return contact;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération du contact');
      }
    } catch (e) {
      debugPrint('[EmergencyContactRepository] Erreur getContact: $e');
      rethrow;
    }
  }

  /// Mettre à jour le contact d'urgence
  Future<EmergencyContact> updateContact({
    String? name,
    String? phone,
    String? relationship,
    String? notes,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/user/emergency-contact');
      
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (relationship != null) 'relationship': relationship,
        if (notes != null) 'notes': notes,
      };

      final response = await _apiService.patch(uri, body: jsonEncode(body));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Le backend retourne { data: { contact: {...} } }
          final dataObj = data['data'];
          final contactData = dataObj is Map && dataObj.containsKey('contact')
              ? dataObj['contact']
              : dataObj;
          if (contactData == null) {
            // Pas de contact configuré
            _cachedContact = null;
            _lastFetch = DateTime.now();
            throw Exception('Contact non configuré');
          }
          final contact = EmergencyContact.fromJson(contactData);
          _cachedContact = contact;
          _lastFetch = DateTime.now();
          return contact;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour du contact');
      }
    } catch (e) {
      debugPrint('[EmergencyContactRepository] Erreur updateContact: $e');
      rethrow;
    }
  }

  /// Supprimer le contact d'urgence
  Future<void> deleteContact() async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/user/emergency-contact');

      final response = await _apiService.delete(uri);

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la suppression du contact');
      }
      
      _cachedContact = null;
      _lastFetch = null;
    } catch (e) {
      debugPrint('[EmergencyContactRepository] Erreur deleteContact: $e');
      rethrow;
    }
  }

  /// Déclencher une alerte d'urgence
  Future<void> triggerEmergencyAlert({
    required String rideId,
    required String reason,
    Map<String, dynamic>? location,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/user/emergency-contact/trigger-alert');
      
      final body = <String, dynamic>{
        'reason': reason,
        if (location != null) 'location': location,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors du déclenchement de l\'alerte');
      }
    } catch (e) {
      debugPrint('[EmergencyContactRepository] Erreur triggerEmergencyAlert: $e');
      rethrow;
    }
  }

  /// Nettoyer le cache
  void clearCache() {
    _cachedContact = null;
    _lastFetch = null;
  }
}

