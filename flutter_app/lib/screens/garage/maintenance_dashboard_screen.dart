import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/maintenance_item.dart';
import '../../services/garage_service.dart';
import '../../utils/number_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/confirmation_dialog.dart';
import '../../widgets/garage/empty_state.dart';
import 'add_maintenance_log_screen.dart';
import 'edit_maintenance_item_screen.dart';

class MaintenanceDashboardScreen extends StatefulWidget {
  final String vehicleId;

  const MaintenanceDashboardScreen({
    super.key,
    required this.vehicleId,
  });

  @override
  State<MaintenanceDashboardScreen> createState() => _MaintenanceDashboardScreenState();
}

class _MaintenanceDashboardScreenState extends State<MaintenanceDashboardScreen> {
  final GarageService _garageService = GarageService();

  List<MaintenanceItem> _allItems = [];
  List<MaintenanceItem> _dueItems = [];
  List<MaintenanceItem> _upcomingItems = [];
  List<MaintenanceItem> _okItems = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'ALL'; // ALL, DUE, UPCOMING

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dashboard = await _garageService.getMaintenanceDashboard(widget.vehicleId);

      if (mounted) {
        setState(() {
          _dueItems = dashboard['due'] as List<MaintenanceItem>;
          _upcomingItems = dashboard['upcoming'] as List<MaintenanceItem>;
          _okItems = dashboard['ok'] as List<MaintenanceItem>;
          _allItems = [..._dueItems, ..._upcomingItems, ..._okItems];
          _summary = dashboard['summary'] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToAddLog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMaintenanceLogScreen(vehicleId: widget.vehicleId),
      ),
    );

    if (result == true) {
      _loadDashboard();
    }
  }

  Future<void> _editItem(MaintenanceItem item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMaintenanceItemScreen(
          vehicleId: widget.vehicleId,
          maintenanceItem: item,
        ),
      ),
    );

    if (result == true) {
      _loadDashboard();
    }
  }

  Future<void> _deleteItem(MaintenanceItem item) async {
    final confirmed = await ConfirmationDialog.showDeleteConfirmation(
      context,
      title: 'Supprimer l\'élément de maintenance',
      content: 'Êtes-vous sûr de vouloir supprimer "${item.label}" ? Cette action est irréversible.',
    );

    if (confirmed) {
      try {
        await _garageService.deleteMaintenanceItem(widget.vehicleId, item.id);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Élément de maintenance supprimé');
          _loadDashboard();
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  List<MaintenanceItem> get _filteredItems {
    switch (_filter) {
      case 'DUE':
        return _dueItems;
      case 'UPCOMING':
        return _upcomingItems;
      default:
        return _allItems;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenances'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Tous'),
                const SizedBox(width: 8),
                _buildFilterChip('DUE', 'À faire'),
                const SizedBox(width: 8),
                _buildFilterChip('UPCOMING', 'À venir'),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddLog,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un entretien'),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filter = value;
          });
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadDashboard,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allItems.isEmpty) {
      return EmptyState(
        icon: Icons.build_outlined,
        title: 'Aucune maintenance',
        message: 'Ajoutez des éléments de maintenance pour suivre l\'entretien de votre véhicule',
        actionLabel: 'Ajouter un entretien',
        onAction: _navigateToAddLog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_summary != null) _buildSummary(),
          const SizedBox(height: 16),
          if (_filter == 'ALL') ...[
            if (_dueItems.isNotEmpty) ...[
              _buildSectionTitle('À faire', Colors.red),
              const SizedBox(height: 8),
              ..._dueItems.map((item) => _buildItemCard(item, isDue: true)),
              const SizedBox(height: 16),
            ],
            if (_upcomingItems.isNotEmpty) ...[
              _buildSectionTitle('À venir', Colors.orange),
              const SizedBox(height: 8),
              ..._upcomingItems.map((item) => _buildItemCard(item, isDue: false)),
              const SizedBox(height: 16),
            ],
            if (_okItems.isNotEmpty) ...[
              _buildSectionTitle('OK', Colors.green),
              const SizedBox(height: 8),
              ..._okItems.map((item) => _buildItemCard(item, isDue: false)),
            ],
          ] else ...[
            if (_filteredItems.isEmpty)
              EmptyState(
                icon: _filter == 'DUE' ? Icons.warning_outlined : Icons.schedule_outlined,
                title: _filter == 'DUE' ? 'Aucune maintenance à faire' : 'Aucune maintenance à venir',
                message: _filter == 'DUE'
                    ? 'Toutes vos maintenances sont à jour !'
                    : 'Aucune maintenance prévue pour le moment',
              )
            else
              ..._filteredItems.map((item) => _buildItemCard(
                    item,
                    isDue: item.isDue,
                  )),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('Total', _summary!['total'], Colors.blue),
            _buildSummaryItem('À faire', _summary!['due'], Colors.red),
            _buildSummaryItem('À venir', _summary!['upcoming'], Colors.orange),
            _buildSummaryItem('OK', _summary!['ok'], Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
    );
  }

  Widget _buildItemCard(MaintenanceItem item, {required bool isDue}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDue 
          ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
          : null,
      child: InkWell(
        onTap: () => _editItem(item),
        onLongPress: () => _deleteItem(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDue ? Colors.red : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isDue ? Icons.warning : Icons.schedule,
                      color: isDue ? Colors.red : Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (item.dueAtKm != null)
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Text(
                    'Échéance: ${NumberFormatter.formatKm(item.dueAtKm!.toDouble())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (item.dueAtDate != null)
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Text(
                    'Échéance: ${DateFormat('dd/MM/yyyy').format(item.dueAtDate!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Text(
                    item.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

