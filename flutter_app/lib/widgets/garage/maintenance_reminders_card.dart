import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/maintenance_reminder.dart';
import '../../providers/maintenance_reminder_provider.dart';
import '../../utils/number_formatter.dart';
import '../../screens/garage/maintenance_reminder_list_screen.dart';

class MaintenanceRemindersCard extends StatefulWidget {
  final String vehicleId;

  const MaintenanceRemindersCard({
    super.key,
    required this.vehicleId,
  });

  @override
  State<MaintenanceRemindersCard> createState() => _MaintenanceRemindersCardState();
}

class _MaintenanceRemindersCardState extends State<MaintenanceRemindersCard> {
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
    return Consumer<MaintenanceReminderProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (provider.errorMessage != null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(height: 8),
                  Text(
                    'Erreur',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => provider.loadReminders(vehicleId: widget.vehicleId),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        final reminders = provider.getRemindersForVehicle(widget.vehicleId)
            .where((r) => r.status == 'active')
            .toList();

        if (reminders.isEmpty) {
          return const SizedBox.shrink();
        }

        // Trier par date d'échéance
        reminders.sort((a, b) {
          if (a.nextDueDate != null && b.nextDueDate != null) {
            return a.nextDueDate!.compareTo(b.nextDueDate!);
          } else if (a.nextDueDate != null) {
            return -1;
          } else if (b.nextDueDate != null) {
            return 1;
          }
          return 0;
        });

        final dueReminders = reminders.where((r) {
          if (r.nextDueDate != null) {
            return r.nextDueDate!.isBefore(DateTime.now());
          }
          return false;
        }).toList();

        final upcomingReminders = reminders.where((r) {
          if (r.nextDueDate != null) {
            return !r.nextDueDate!.isBefore(DateTime.now());
          }
          return false;
        }).toList();

        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MaintenanceReminderListScreen(vehicleId: widget.vehicleId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Rappels d\'entretien',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      if (reminders.length > 3)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MaintenanceReminderListScreen(vehicleId: widget.vehicleId),
                              ),
                            );
                          },
                          child: const Text('Voir tout'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Rappels échus
                  if (dueReminders.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${dueReminders.length} rappel${dueReminders.length > 1 ? 's' : ''} échu${dueReminders.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Liste des rappels (max 3)
                  ...reminders.take(3).map((reminder) => _ReminderItem(reminder: reminder)),
                  if (reminders.length > 3) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MaintenanceReminderListScreen(vehicleId: widget.vehicleId),
                          ),
                        );
                      },
                      child: Text('Voir les ${reminders.length - 3} autres...'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReminderItem extends StatelessWidget {
  final MaintenanceReminder reminder;

  const _ReminderItem({
    required this.reminder,
  });

  @override
  Widget build(BuildContext context) {
    final isDue = reminder.nextDueDate != null &&
        reminder.nextDueDate!.isBefore(DateTime.now());
    final color = isDue ? Colors.red : Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForType(reminder.type),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.description ?? reminder.type,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                if (reminder.nextDueDate != null)
                  Text(
                    'Échéance: ${DateFormat('dd/MM/yyyy').format(reminder.nextDueDate!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDue ? Colors.red.shade700 : Colors.grey.shade600,
                        ),
                  )
                else if (reminder.nextDueKm != null)
                  Text(
                    'Échéance: ${NumberFormatter.formatKm(reminder.nextDueKm!)} km',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
              ],
            ),
          ),
        ],
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
}

