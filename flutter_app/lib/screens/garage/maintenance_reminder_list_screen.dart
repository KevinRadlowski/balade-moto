import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/maintenance_reminder.dart';
import '../../providers/maintenance_reminder_provider.dart';
import '../../utils/snackbar_helper.dart';

class MaintenanceReminderListScreen extends StatefulWidget {
  final String vehicleId;

  const MaintenanceReminderListScreen({
    super.key,
    required this.vehicleId,
  });

  @override
  State<MaintenanceReminderListScreen> createState() => _MaintenanceReminderListScreenState();
}

class _MaintenanceReminderListScreenState extends State<MaintenanceReminderListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MaintenanceReminderProvider>(context, listen: false);
      provider.loadReminders(vehicleId: widget.vehicleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rappels d\'entretien'),
      ),
      body: Consumer<MaintenanceReminderProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadReminders(vehicleId: widget.vehicleId),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final reminders = provider.getRemindersForVehicle(widget.vehicleId);

          if (reminders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun rappel',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aucun rappel d\'entretien configuré pour ce véhicule',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadReminders(vehicleId: widget.vehicleId, useCache: false),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final reminder = reminders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(_getIconForType(reminder.type)),
                    title: Text(reminder.description ?? reminder.type),
                    subtitle: Text(_getSubtitle(reminder)),
                    trailing: reminder.status == 'active'
                        ? IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () async {
                              try {
                                await provider.markAsDone(
                                  reminderId: reminder.id,
                                  completedDate: DateTime.now(),
                                );
                                // Recharger les rappels après marquage
                                await provider.loadReminders(vehicleId: widget.vehicleId, useCache: false);
                                if (mounted) {
                                  SnackBarHelper.showSuccess(
                                    context,
                                    'Rappel marqué comme terminé',
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  SnackBarHelper.showError(context, e.toString());
                                }
                              }
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'oil':
        return Icons.opacity;
      case 'tire':
        return Icons.settings;
      case 'brake':
        return Icons.stop_circle;
      case 'inspection':
        return Icons.search;
      case 'filter':
        return Icons.filter_alt;
      case 'battery':
        return Icons.battery_charging_full;
      case 'coolant':
        return Icons.water_drop;
      default:
        return Icons.build;
    }
  }

  String _getSubtitle(MaintenanceReminder reminder) {
    final parts = <String>[];
    if (reminder.nextDueDate != null) {
      parts.add('Échéance: ${reminder.nextDueDate!.toString().split(' ')[0]}');
    }
    if (reminder.nextDueKm != null) {
      parts.add('${reminder.nextDueKm} km');
    }
    parts.add('Statut: ${reminder.status}');
    return parts.join(' • ');
  }
}

