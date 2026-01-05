import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/maintenance_reminder.dart';
import '../repositories/maintenance_reminder_repository.dart';
import '../services/api_service.dart';

class MaintenanceReminderProvider extends ChangeNotifier {
  final MaintenanceReminderRepository _repository;

  // État
  bool _isLoading = false;
  String? _errorMessage;
  final Map<String, List<MaintenanceReminder>> _remindersByVehicle = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  MaintenanceReminderProvider({required ApiService apiService})
      : _repository = MaintenanceReminderRepository(apiService: apiService);

  /// Obtenir les rappels d'un véhicule
  List<MaintenanceReminder> getRemindersForVehicle(String vehicleId) {
    return _remindersByVehicle[vehicleId] ?? [];
  }

  /// Charger les rappels d'un véhicule
  Future<void> loadReminders({
    required String vehicleId,
    String? status,
    bool? active,
    bool useCache = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final reminders = await _repository.getReminders(
        vehicleId: vehicleId,
        status: status,
        active: active,
        useCache: useCache,
      );

      _remindersByVehicle[vehicleId] = reminders;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[MaintenanceReminderProvider] Erreur loadReminders: $e');
    }
  }

  /// Créer un rappel
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final reminder = await _repository.createReminder(
        vehicleId: vehicleId,
        reminderType: reminderType,
        category: category,
        label: label,
        dueDate: dueDate,
        dueKm: dueKm,
        priority: priority,
        notes: notes,
      );

      // Recharger les rappels pour ce véhicule
      await loadReminders(vehicleId: vehicleId, useCache: false);

      _isLoading = false;
      notifyListeners();
      return reminder;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[MaintenanceReminderProvider] Erreur createReminder: $e');
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final reminder = await _repository.updateReminder(
        reminderId: reminderId,
        dueDate: dueDate,
        dueKm: dueKm,
        status: status,
        priority: priority,
        notes: notes,
        active: active,
      );

      // Recharger tous les rappels (on ne connaît pas le vehicleId ici)
      _remindersByVehicle.clear();
      _isLoading = false;
      notifyListeners();
      return reminder;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[MaintenanceReminderProvider] Erreur updateReminder: $e');
      rethrow;
    }
  }

  /// Marquer comme terminé
  Future<MaintenanceReminder> markAsDone({
    required String reminderId,
    DateTime? completedDate,
    double? completedKm,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final reminder = await _repository.markAsDone(
        reminderId: reminderId,
        completedDate: completedDate,
        completedKm: completedKm,
      );

      // Recharger tous les rappels
      _remindersByVehicle.clear();
      _isLoading = false;
      notifyListeners();
      return reminder;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[MaintenanceReminderProvider] Erreur markAsDone: $e');
      rethrow;
    }
  }

  /// Supprimer un rappel
  Future<void> deleteReminder(String reminderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteReminder(reminderId);

      // Recharger tous les rappels
      _remindersByVehicle.clear();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[MaintenanceReminderProvider] Erreur deleteReminder: $e');
      rethrow;
    }
  }

  /// Réinitialiser l'état
  void reset() {
    _remindersByVehicle.clear();
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Nettoyer le cache
  void clearCache() {
    _repository.clearCache();
  }
}




