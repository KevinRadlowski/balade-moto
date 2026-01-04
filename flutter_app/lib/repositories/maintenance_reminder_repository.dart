import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/maintenance_reminder.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class MaintenanceReminderRepository {
  final ApiService _apiService;
  
  // Cache léger
  final Map<String, List<MaintenanceReminder>> _remindersCache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};

  MaintenanceReminderRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Créer un rappel d'entretien
  Future<MaintenanceReminder> createReminder({
    required String vehicleId,
    required String reminderType,
    required String category,
    required String label,
    DateTime? dueDate,
    double? dueKm,
    String? priority,
    String? notes,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/garage/maintenance-reminders');
      
      final body = <String, dynamic>{
        'vehicleId': vehicleId,
        'reminderType': reminderType,
        'category': category,
        'label': label,
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
        if (dueKm != null) 'dueKm': dueKm,
        if (priority != null) 'priority': priority,
        if (notes != null) 'notes': notes,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final reminder = MaintenanceReminder.fromJson(data['data']);
          
          // Invalider le cache pour ce véhicule
          _remindersCache.remove(vehicleId);
          _cacheTimestamps.remove(vehicleId);
          
          return reminder;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la création du rappel');
      }
    } catch (e) {
      debugPrint('[MaintenanceReminderRepository] Erreur createReminder: $e');
      rethrow;
    }
  }

  /// Obtenir les rappels d'entretien d'un véhicule
  Future<List<MaintenanceReminder>> getReminders({
    required String vehicleId,
    String? status,
    bool? active,
    bool useCache = true,
  }) async {
    try {
      final cacheKey = '$vehicleId-$status-$active';
      
      // Vérifier le cache
      if (useCache && _remindersCache.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey];
        if (cacheTime != null && 
            DateTime.now().difference(cacheTime) < _cacheTtl) {
          return _remindersCache[cacheKey]!;
        }
      }

      final queryParams = <String, String>{
        'vehicleId': vehicleId,
      };
      if (status != null) queryParams['status'] = status;
      if (active != null) queryParams['active'] = active.toString();

      final uri = Uri.parse('${ApiConfig.apiUrl}/garage/maintenance-reminders')
          .replace(queryParameters: queryParams);

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Le backend retourne { data: { reminders: [...] } }
          final dataObj = data['data'];
          final remindersList = dataObj is Map && dataObj.containsKey('reminders')
              ? (dataObj['reminders'] as List)
              : (dataObj is List ? dataObj : []);
          final reminders = remindersList
              .map((r) => MaintenanceReminder.fromJson(r))
              .toList();
          
          // Mettre en cache
          _remindersCache[cacheKey] = reminders;
          _cacheTimestamps[cacheKey] = DateTime.now();
          
          return reminders;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des rappels');
      }
    } catch (e) {
      debugPrint('[MaintenanceReminderRepository] Erreur getReminders: $e');
      rethrow;
    }
  }

  /// Obtenir un rappel par ID
  Future<MaintenanceReminder> getReminderById(String reminderId) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/garage/maintenance-reminders/$reminderId');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return MaintenanceReminder.fromJson(data['data']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération du rappel');
      }
    } catch (e) {
      debugPrint('[MaintenanceReminderRepository] Erreur getReminderById: $e');
      rethrow;
    }
  }

  /// Mettre à jour un rappel
  Future<MaintenanceReminder> updateReminder({
    required String reminderId,
    DateTime? dueDate,
    double? dueKm,
    String? status,
    String? priority,
    String? notes,
    bool? active,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/garage/maintenance-reminders/$reminderId');
      
      final body = <String, dynamic>{
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
        if (dueKm != null) 'dueKm': dueKm,
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (notes != null) 'notes': notes,
        if (active != null) 'active': active,
      };

      final response = await _apiService.patch(uri, body: jsonEncode(body));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final reminder = MaintenanceReminder.fromJson(data['data']);
          
          // Invalider le cache
          _remindersCache.clear();
          _cacheTimestamps.clear();
          
          return reminder;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour du rappel');
      }
    } catch (e) {
      debugPrint('[MaintenanceReminderRepository] Erreur updateReminder: $e');
      rethrow;
    }
  }

  /// Marquer un rappel comme terminé
  Future<MaintenanceReminder> markAsDone({
    required String reminderId,
    DateTime? completedDate,
    double? completedKm,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/garage/maintenance-reminders/$reminderId/done');
      
      final body = <String, dynamic>{
        if (completedDate != null) 'completedDate': completedDate.toIso8601String(),
        if (completedKm != null) 'completedKm': completedKm,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final reminder = MaintenanceReminder.fromJson(data['data']);
          
          // Invalider le cache
          _remindersCache.clear();
          _cacheTimestamps.clear();
          
          return reminder;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors du marquage comme terminé');
      }
    } catch (e) {
      debugPrint('[MaintenanceReminderRepository] Erreur markAsDone: $e');
      rethrow;
    }
  }

  /// Supprimer un rappel
  Future<void> deleteReminder(String reminderId) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/garage/maintenance-reminders/$reminderId');

      final response = await _apiService.delete(uri);

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la suppression du rappel');
      }
      
      // Invalider le cache
      _remindersCache.clear();
      _cacheTimestamps.clear();
    } catch (e) {
      debugPrint('[MaintenanceReminderRepository] Erreur deleteReminder: $e');
      rethrow;
    }
  }

  /// Nettoyer le cache
  void clearCache() {
    _remindersCache.clear();
    _cacheTimestamps.clear();
  }
}

