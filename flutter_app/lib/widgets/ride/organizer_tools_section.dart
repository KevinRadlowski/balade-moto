import 'package:flutter/material.dart';
import '../../models/ride.dart';
import '../../services/api_service.dart';
import '../../constants/app_theme.dart';
import '../../utils/snackbar_helper.dart';

/// Section "Outils organisateur" pour les balades
/// Affiche les 5 outils : Validation manuelle, Liste d'attente, Limite participants,
/// Message automatique, Balades récurrentes
class OrganizerToolsSection extends StatefulWidget {
  final Ride ride;
  final ApiService apiService;
  final VoidCallback onRideUpdated;

  const OrganizerToolsSection({
    super.key,
    required this.ride,
    required this.apiService,
    required this.onRideUpdated,
  });

  @override
  State<OrganizerToolsSection> createState() => _OrganizerToolsSectionState();
}

class _OrganizerToolsSectionState extends State<OrganizerToolsSection> {
  bool _isExpanded = false;
  bool _isLoading = false;

  // État local des paramètres
  late bool _requiresApproval;
  late bool _enableWaitlist;
  late int? _maxParticipants;
  late bool _autoReminderEnabled;
  late int _autoReminderHours;
  late String? _autoReminderMessage;
  late bool _recurrenceEnabled;
  late String _recurrenceFrequency;
  late int? _recurrenceDayOfWeek;
  late DateTime? _recurrenceEndDate;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    _requiresApproval = widget.ride.requiresApproval;
    _enableWaitlist = widget.ride.enableWaitlist;
    _maxParticipants = widget.ride.maxParticipants;
    _autoReminderEnabled = widget.ride.autoReminder?.enabled ?? false;
    _autoReminderHours = widget.ride.autoReminder?.hoursBefore ?? 24;
    _autoReminderMessage = widget.ride.autoReminder?.message;
    _recurrenceEnabled = widget.ride.recurrence?.enabled ?? false;
    _recurrenceFrequency = widget.ride.recurrence?.frequency ?? 'weekly';
    _recurrenceDayOfWeek = widget.ride.recurrence?.dayOfWeek;
    _recurrenceEndDate = widget.ride.recurrence?.endDate;
  }

  @override
  void didUpdateWidget(OrganizerToolsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride != widget.ride) {
      _initializeState();
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    
    try {
      await widget.apiService.updateOrganizerSettings(
        widget.ride.id,
        requiresApproval: _requiresApproval,
        maxParticipants: _maxParticipants ?? 0,
        enableWaitlist: _enableWaitlist,
        autoReminder: {
          'enabled': _autoReminderEnabled,
          'hoursBefore': _autoReminderHours,
          'message': _autoReminderMessage,
        },
        recurrence: {
          'enabled': _recurrenceEnabled,
          'frequency': _recurrenceFrequency,
          'dayOfWeek': _recurrenceDayOfWeek,
          'endDate': _recurrenceEndDate?.toIso8601String(),
        },
      );

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Paramètres sauvegardés');
        widget.onRideUpdated();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header avec toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Outils organisateur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Contenu expandable
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 1. Validation manuelle des participants
                  _buildToolItem(
                    icon: Icons.verified_user,
                    title: 'Validation manuelle des participants',
                    subtitle: 'Approuve ou refuse les demandes d\'inscription',
                    trailing: Switch(
                      value: _requiresApproval,
                      onChanged: (value) {
                        setState(() => _requiresApproval = value);
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: _requiresApproval ? _showPendingRequests : null,
                    badge: widget.ride.pendingRequestsCount > 0
                        ? '${widget.ride.pendingRequestsCount}'
                        : null,
                  ),

                  const Divider(height: 24),

                  // 2. Liste d'attente
                  _buildToolItem(
                    icon: Icons.format_list_numbered,
                    title: 'Liste d\'attente',
                    subtitle: 'Gère automatiquement les participants en attente',
                    trailing: Switch(
                      value: _enableWaitlist,
                      onChanged: (value) {
                        setState(() => _enableWaitlist = value);
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: _enableWaitlist ? _showWaitlist : null,
                    badge: widget.ride.waitlistCount > 0
                        ? '${widget.ride.waitlistCount}'
                        : null,
                  ),

                  const Divider(height: 24),

                  // 3. Limite de participants + gestion automatique
                  _buildToolItem(
                    icon: Icons.group,
                    title: 'Limite de participants + gestion automatique',
                    subtitle: 'Définis une limite et laisse le système gérer les inscriptions',
                    trailing: SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: _maxParticipants?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '∞',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _maxParticipants = int.tryParse(value);
                          });
                        },
                      ),
                    ),
                  ),

                  const Divider(height: 24),

                  // 4. Message automatique avant la balade
                  _buildToolItem(
                    icon: Icons.notifications_active,
                    title: 'Message automatique avant la balade',
                    subtitle: 'Envoie un rappel automatique aux participants',
                    trailing: Switch(
                      value: _autoReminderEnabled,
                      onChanged: (value) {
                        setState(() => _autoReminderEnabled = value);
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: _autoReminderEnabled ? _showAutoReminderSettings : null,
                  ),

                  const Divider(height: 24),

                  // 5. Balades récurrentes
                  _buildToolItem(
                    icon: Icons.repeat,
                    title: 'Balades récurrentes',
                    subtitle: 'Crée des balades hebdomadaires ou mensuelles automatiques',
                    trailing: Switch(
                      value: _recurrenceEnabled,
                      onChanged: (value) {
                        setState(() => _recurrenceEnabled = value);
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    onTap: _recurrenceEnabled ? _showRecurrenceSettings : null,
                  ),

                  const SizedBox(height: 16),

                  // Bouton sauvegarder
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveSettings,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Sauvegarde...' : 'Sauvegarder les paramètres'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 22),
                ),
                if (badge != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  void _showPendingRequests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PendingRequestsSheet(
        ride: widget.ride,
        apiService: widget.apiService,
        onUpdated: widget.onRideUpdated,
      ),
    );
  }

  void _showWaitlist() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WaitlistSheet(
        ride: widget.ride,
        apiService: widget.apiService,
        onUpdated: widget.onRideUpdated,
      ),
    );
  }

  void _showAutoReminderSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AutoReminderSheet(
        initialHours: _autoReminderHours,
        initialMessage: _autoReminderMessage,
        onSave: (hours, message) {
          setState(() {
            _autoReminderHours = hours;
            _autoReminderMessage = message;
          });
        },
      ),
    );
  }

  void _showRecurrenceSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecurrenceSheet(
        initialFrequency: _recurrenceFrequency,
        initialDayOfWeek: _recurrenceDayOfWeek,
        initialEndDate: _recurrenceEndDate,
        onSave: (frequency, dayOfWeek, endDate) {
          setState(() {
            _recurrenceFrequency = frequency;
            _recurrenceDayOfWeek = dayOfWeek;
            _recurrenceEndDate = endDate;
          });
        },
      ),
    );
  }
}

// ========== SHEETS ==========

class _PendingRequestsSheet extends StatefulWidget {
  final Ride ride;
  final ApiService apiService;
  final VoidCallback onUpdated;

  const _PendingRequestsSheet({
    required this.ride,
    required this.apiService,
    required this.onUpdated,
  });

  @override
  State<_PendingRequestsSheet> createState() => _PendingRequestsSheetState();
}

class _PendingRequestsSheetState extends State<_PendingRequestsSheet> {
  List<PendingRequest> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final response = await widget.apiService.getPendingRequests(widget.ride.id);
      if (mounted) {
        setState(() {
          _requests = (response['data']['pendingRequests'] as List)
              .map((r) => PendingRequest.fromJson(r))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveRequest(String userId) async {
    try {
      await widget.apiService.approveJoinRequest(widget.ride.id, userId);
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Demande approuvée');
        _loadRequests();
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _rejectRequest(String userId) async {
    try {
      await widget.apiService.rejectJoinRequest(widget.ride.id, userId);
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Demande refusée');
        _loadRequests();
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions, color: Colors.orange),
                    const SizedBox(width: 12),
                    Text(
                      'Demandes en attente (${_requests.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text('Erreur: $_error'))
                        : _requests.isEmpty
                            ? const Center(
                                child: Text(
                                  'Aucune demande en attente',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _requests.length,
                                itemBuilder: (context, index) {
                                  final request = _requests[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                      child: Text(
                                        request.displayName[0].toUpperCase(),
                                        style: TextStyle(color: AppTheme.primaryColor),
                                      ),
                                    ),
                                    title: Text(request.displayName),
                                    subtitle: request.message != null
                                        ? Text(
                                            request.message!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: Colors.green),
                                          onPressed: () => _approveRequest(request.userId),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, color: Colors.red),
                                          onPressed: () => _rejectRequest(request.userId),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaitlistSheet extends StatefulWidget {
  final Ride ride;
  final ApiService apiService;
  final VoidCallback onUpdated;

  const _WaitlistSheet({
    required this.ride,
    required this.apiService,
    required this.onUpdated,
  });

  @override
  State<_WaitlistSheet> createState() => _WaitlistSheetState();
}

class _WaitlistSheetState extends State<_WaitlistSheet> {
  List<WaitlistEntry> _waitlist = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWaitlist();
  }

  Future<void> _loadWaitlist() async {
    try {
      final response = await widget.apiService.getWaitlist(widget.ride.id);
      if (mounted) {
        setState(() {
          _waitlist = (response['data']['waitlist'] as List)
              .map((w) => WaitlistEntry.fromJson(w))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _promoteUser(String userId) async {
    try {
      await widget.apiService.promoteFromWaitlist(widget.ride.id, userId);
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Participant promu');
        _loadWaitlist();
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _removeUser(String userId) async {
    try {
      await widget.apiService.removeFromWaitlist(widget.ride.id, userId);
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Retiré de la liste d\'attente');
        _loadWaitlist();
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.format_list_numbered, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text(
                      'Liste d\'attente (${_waitlist.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text('Erreur: $_error'))
                        : _waitlist.isEmpty
                            ? const Center(
                                child: Text(
                                  'Liste d\'attente vide',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _waitlist.length,
                                itemBuilder: (context, index) {
                                  final entry = _waitlist[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.withOpacity(0.1),
                                      child: Text(
                                        '${entry.position}',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(entry.displayName),
                                    subtitle: entry.vehicleNickname != null
                                        ? Text(entry.vehicleNickname!)
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.arrow_upward, color: Colors.green),
                                          tooltip: 'Promouvoir',
                                          onPressed: () => _promoteUser(entry.userId),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          tooltip: 'Retirer',
                                          onPressed: () => _removeUser(entry.userId),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AutoReminderSheet extends StatefulWidget {
  final int initialHours;
  final String? initialMessage;
  final void Function(int hours, String? message) onSave;

  const _AutoReminderSheet({
    required this.initialHours,
    this.initialMessage,
    required this.onSave,
  });

  @override
  State<_AutoReminderSheet> createState() => _AutoReminderSheetState();
}

class _AutoReminderSheetState extends State<_AutoReminderSheet> {
  late int _hours;
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialHours;
    _messageController = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Paramètres du rappel automatique',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text('Envoyer le rappel :'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _hours,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 heure avant')),
                  DropdownMenuItem(value: 2, child: Text('2 heures avant')),
                  DropdownMenuItem(value: 6, child: Text('6 heures avant')),
                  DropdownMenuItem(value: 12, child: Text('12 heures avant')),
                  DropdownMenuItem(value: 24, child: Text('24 heures avant')),
                  DropdownMenuItem(value: 48, child: Text('48 heures avant')),
                  DropdownMenuItem(value: 72, child: Text('3 jours avant')),
                  DropdownMenuItem(value: 168, child: Text('1 semaine avant')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _hours = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('Message personnalisé (optionnel) :'),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Laissez vide pour un message par défaut',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSave(
                      _hours,
                      _messageController.text.isEmpty ? null : _messageController.text,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurrenceSheet extends StatefulWidget {
  final String initialFrequency;
  final int? initialDayOfWeek;
  final DateTime? initialEndDate;
  final void Function(String frequency, int? dayOfWeek, DateTime? endDate) onSave;

  const _RecurrenceSheet({
    required this.initialFrequency,
    this.initialDayOfWeek,
    this.initialEndDate,
    required this.onSave,
  });

  @override
  State<_RecurrenceSheet> createState() => _RecurrenceSheetState();
}

class _RecurrenceSheetState extends State<_RecurrenceSheet> {
  late String _frequency;
  late int? _dayOfWeek;
  late DateTime? _endDate;

  final List<String> _days = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];

  @override
  void initState() {
    super.initState();
    _frequency = widget.initialFrequency;
    _dayOfWeek = widget.initialDayOfWeek;
    _endDate = widget.initialEndDate;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Paramètres de récurrence',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text('Fréquence :'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _frequency,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'weekly', child: Text('Hebdomadaire')),
                  DropdownMenuItem(value: 'biweekly', child: Text('Toutes les 2 semaines')),
                  DropdownMenuItem(value: 'monthly', child: Text('Mensuelle')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _frequency = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('Jour de la semaine (optionnel) :'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: _dayOfWeek,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Même jour que la balade')),
                  ...List.generate(7, (index) => DropdownMenuItem(
                    value: index,
                    child: Text(_days[index]),
                  )),
                ],
                onChanged: (value) {
                  setState(() => _dayOfWeek = value);
                },
              ),
              const SizedBox(height: 16),
              const Text('Date de fin (optionnel) :'),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now().add(const Duration(days: 90)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _endDate != null
                              ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                              : 'Pas de date de fin',
                          style: TextStyle(
                            color: _endDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                      if (_endDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => setState(() => _endDate = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSave(_frequency, _dayOfWeek, _endDate);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


