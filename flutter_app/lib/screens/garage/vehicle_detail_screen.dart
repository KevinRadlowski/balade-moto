import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../models/maintenance_item.dart';
import '../../models/maintenance_log.dart';
import '../../models/vehicle_document.dart';
import '../../services/garage_service.dart';
import '../../controllers/photo_gallery_controller.dart';
import '../../utils/vehicle_icon_helper.dart';
import '../../utils/number_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/confirmation_dialog.dart';
import '../../widgets/garage/section_card.dart';
import '../../widgets/garage/empty_state.dart';
import '../../widgets/garage/photo_grid_item.dart';
import '../../config/api_config.dart';
import 'add_odometer_screen.dart';
import 'maintenance_dashboard_screen.dart';
import 'add_maintenance_log_screen.dart';
import 'edit_maintenance_item_screen.dart';
import 'add_vehicle_screen.dart';
import 'add_document_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final String vehicleId;

  const VehicleDetailScreen({
    super.key,
    required this.vehicleId,
  });

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final GarageService _garageService = GarageService();
  late final PhotoGalleryController _photoController;
  final ScrollController _scrollController = ScrollController();

  Vehicle? _vehicle;
  List<MaintenanceItem> _dueItems = [];
  List<MaintenanceItem> _upcomingItems = [];
  List<MaintenanceLog> _recentLogs = [];
  List<VehicleDocument> _documents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _photoController = PhotoGalleryController(vehicleId: widget.vehicleId);
    _scrollController.addListener(_onScroll);
    _loadData();
    // Charger la première page de photos après un court délai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _photoController.loadFirstPage();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Ne pas disposer le controller ici car il est géré par Provider.value
    // Le controller sera disposé automatiquement quand il n'y aura plus de listeners
    super.dispose();
  }

  void _onScroll() {
    // Infinite scroll : charger la page suivante quand on approche de la fin
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _photoController.loadNextPage();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vehicle = await _garageService.getVehicle(widget.vehicleId);
      final dashboard = await _garageService.getMaintenanceDashboard(widget.vehicleId);
      final logsResult = await _garageService.listMaintenanceLogs(
        widget.vehicleId,
        page: 1,
        limit: 5,
      );
      final documentsResult = await _garageService.listDocuments(
        widget.vehicleId,
        page: 1,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _vehicle = vehicle;
          _dueItems = dashboard['due'] as List<MaintenanceItem>;
          _upcomingItems = dashboard['upcoming'] as List<MaintenanceItem>;
          _recentLogs = logsResult['maintenanceLogs'] as List<MaintenanceLog>;
          _documents = documentsResult['documents'] as List<VehicleDocument>;
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

  Future<void> _refreshData() async {
    await _loadData();
  }

  Future<void> _navigateToAddOdometer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddOdometerScreen(vehicleId: widget.vehicleId),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _navigateToMaintenanceDashboard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaintenanceDashboardScreen(vehicleId: widget.vehicleId),
      ),
    );
    _refreshData();
  }

  Future<void> _navigateToAddMaintenanceLog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMaintenanceLogScreen(vehicleId: widget.vehicleId),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _navigateToAddDocument() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDocumentScreen(vehicleId: widget.vehicleId),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _openDocument(VehicleDocument document) async {
    try {
      final uri = Uri.parse(document.fileUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          SnackBarHelper.showError(context, 'Impossible d\'ouvrir le document');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Erreur lors de l\'ouverture du document: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _addPhotos() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      
      if (images.isEmpty) {
        return;
      }

      // Limiter à 10 photos maximum par sélection
      const maxPhotos = 10;
      List<XFile> selectedImages = images;
      
      if (images.length > maxPhotos) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Vous ne pouvez sélectionner que $maxPhotos photos maximum à la fois. Seules les $maxPhotos premières photos seront ajoutées.',
          );
        }
        selectedImages = images.take(maxPhotos).toList();
      }

      if (mounted) {
        // Afficher un indicateur de chargement
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      try {
        final updatedVehicle = await _garageService.addVehiclePhotos(widget.vehicleId, selectedImages);
        
        if (mounted) {
          Navigator.pop(context); // Fermer le dialog de chargement
          SnackBarHelper.showSuccess(context, '${selectedImages.length} photo(s) ajoutée(s) avec succès');
          
          // Rafraîchir la galerie de photos
          _photoController.refresh();
          
          // Mettre à jour le véhicule localement
          setState(() {
            _vehicle = updatedVehicle;
          });
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Fermer le dialog de chargement
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors de la sélection des photos: ${e.toString()}');
      }
    }
  }

  Future<void> _deletePhoto(int photoIndex) async {
    final confirmed = await ConfirmationDialog.showDeleteConfirmation(
      context,
      title: 'Supprimer la photo',
      content: 'Êtes-vous sûr de vouloir supprimer cette photo ? Cette action est irréversible.',
    );

    if (confirmed) {
      // Suppression optimiste
      final removedIndex = _photoController.removeLocalByIndex(photoIndex);
      
      try {
        await _garageService.deleteVehiclePhoto(widget.vehicleId, photoIndex);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Photo supprimée avec succès');
          // Rafraîchir pour s'assurer que l'état est cohérent
          _photoController.refresh();
        }
      } catch (e) {
        // Rollback en cas d'erreur
        if (removedIndex != null && _photoController.photos.length > removedIndex) {
          // La photo a déjà été supprimée de la liste, on rafraîchit
          _photoController.refresh();
        }
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _deleteDocument(VehicleDocument document) async {
    final confirmed = await ConfirmationDialog.showDeleteConfirmation(
      context,
      title: 'Supprimer le document',
      content: 'Êtes-vous sûr de vouloir supprimer "${document.label}" ? Cette action est irréversible.',
    );

    if (confirmed) {
      try {
        await _garageService.deleteDocument(widget.vehicleId, document.id);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Document supprimé avec succès');
          _refreshData();
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _editVehicle() async {
    if (_vehicle == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleScreen(vehicle: _vehicle),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _deleteVehicle() async {
    if (_vehicle == null) return;

    final confirmed = await ConfirmationDialog.showDeleteConfirmation(
      context,
      title: 'Supprimer le véhicule',
      content: 'Êtes-vous sûr de vouloir supprimer ${_vehicle!.displayName} ? Cette action est irréversible.',
    );

    if (confirmed) {
      try {
        await _garageService.deleteVehicle(widget.vehicleId);
        if (mounted) {
          Navigator.pop(context, true);
          SnackBarHelper.showSuccess(context, 'Véhicule supprimé avec succès');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PhotoGalleryController>.value(
      value: _photoController,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_vehicle?.displayName ?? 'Véhicule'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editVehicle,
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteVehicle,
              tooltip: 'Supprimer',
            ),
          ],
        ),
        body: _buildBody(),
      ),
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
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_vehicle == null) {
      return const Center(child: Text('Véhicule non trouvé'));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildHeader(),
            ),
          ),
          
          // Kilométrage
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildOdometerCard(),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          
          // Entretiens à faire
          if (_dueItems.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSectionTitle('À faire', Colors.red),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < _dueItems.length && index < 3) {
                      return _buildMaintenanceItemCard(_dueItems[index]);
                    } else if (index == 3 && _dueItems.length > 3) {
                      return TextButton(
                        onPressed: _navigateToMaintenanceDashboard,
                        child: Text('Voir les ${_dueItems.length - 3} autres...'),
                      );
                    }
                    return null;
                  },
                  childCount: _dueItems.length > 3 ? 4 : _dueItems.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
          
          // Entretiens à venir
          if (_upcomingItems.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSectionTitle('À venir', Colors.orange),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < _upcomingItems.length && index < 3) {
                      return _buildMaintenanceItemCard(_upcomingItems[index]);
                    } else if (index == 3 && _upcomingItems.length > 3) {
                      return TextButton(
                        onPressed: _navigateToMaintenanceDashboard,
                        child: Text('Voir les ${_upcomingItems.length - 3} autres...'),
                      );
                    }
                    return null;
                  },
                  childCount: _upcomingItems.length > 3 ? 4 : _upcomingItems.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
          
          // Bouton dashboard
          if (_dueItems.isNotEmpty || _upcomingItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: _navigateToMaintenanceDashboard,
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Voir tout le dashboard'),
                ),
              ),
            ),
          
          if (_dueItems.isNotEmpty || _upcomingItems.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          
          // Historique entretiens
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSectionTitle('Historique entretiens'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _recentLogs.isEmpty
                ? SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.build_outlined,
                      title: 'Aucun entretien enregistré',
                      message: 'Ajoutez votre premier entretien pour commencer à suivre la maintenance de votre véhicule',
                      actionLabel: 'Ajouter un entretien',
                      onAction: _navigateToAddMaintenanceLog,
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < _recentLogs.length) {
                          return _buildMaintenanceLogCard(_recentLogs[index]);
                        } else if (index == _recentLogs.length && _recentLogs.length >= 5) {
                          return TextButton(
                            onPressed: _navigateToMaintenanceDashboard,
                            child: const Text('Voir tout l\'historique'),
                          );
                        }
                        return null;
                      },
                      childCount: _recentLogs.length >= 5 ? _recentLogs.length + 1 : _recentLogs.length,
                    ),
                  ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          
          // Documents
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSectionTitle('Documents', null, _navigateToAddDocument),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _documents.isEmpty
                ? SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.description_outlined,
                      title: 'Aucun document',
                      message: 'Ajoutez des documents importants pour votre véhicule (assurance, contrôle technique, factures...)',
                      actionLabel: 'Ajouter un document',
                      onAction: _navigateToAddDocument,
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < _documents.length) {
                          return _buildDocumentCard(_documents[index]);
                        } else if (index == _documents.length && _documents.length >= 10) {
                          return TextButton(
                            onPressed: _navigateToAddDocument,
                            child: const Text('Voir tous les documents'),
                          );
                        }
                        return null;
                      },
                      childCount: _documents.length >= 10 ? _documents.length + 1 : _documents.length,
                    ),
                  ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          
          // GALERIE PHOTOS EN BAS (après tout le reste)
          _buildPhotosSliver(),
          _buildPhotosGrid(),
          
          // Footer pour l'infinite scroll
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Consumer<PhotoGalleryController>(
                builder: (context, controller, _) {
                  if (controller.isLoading && controller.photos.isNotEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (!controller.hasMore && controller.photos.isNotEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Toutes les photos ont été chargées',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final icon = getVehicleIcon(_vehicle!.type);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _vehicle!.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (_vehicle!.year != null || _vehicle!.make != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (_vehicle!.year != null) _vehicle!.year.toString(),
                        if (_vehicle!.make != null) _vehicle!.make,
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOdometerCard() {
    return SectionCard(
      title: 'Kilométrage actuel',
      trailing: TextButton.icon(
        onPressed: _navigateToAddOdometer,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Ajouter un relevé'),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              NumberFormatter.formatKmNumber(_vehicle!.odometerCurrentKm.toDouble()),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(width: 4),
            Text(
              'km',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, [Color? color, VoidCallback? onAdd]) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
        ),
        if (onAdd != null || title == 'Historique entretiens')
          const Spacer(),
        if (title == 'Historique entretiens')
          TextButton.icon(
            onPressed: _navigateToAddMaintenanceLog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter'),
          )
        else if (onAdd != null)
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter'),
          ),
      ],
    );
  }

  Widget _buildMaintenanceItemCard(MaintenanceItem item) {
    final isDue = item.isDue;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDue 
          ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
          : null,
      child: InkWell(
        onTap: () => _editMaintenanceItem(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    if (item.dueAtKm != null)
                      Text(
                        'Échéance: ${item.dueAtKm} km',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (item.dueAtDate != null)
                      Text(
                        'Échéance: ${DateFormat('dd/MM/yyyy').format(item.dueAtDate!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenanceLogCard(MaintenanceLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.build,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(log.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${DateFormat('dd/MM/yyyy').format(log.date)} • ${NumberFormatter.formatKm(log.kmAtService.toDouble())}'),
            if (log.garageName != null && log.garageName!.isNotEmpty)
              Text(log.garageName!),
            if (log.invoiceFileUrl != null && log.invoiceFileUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Document joint',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (log.invoiceFileUrl != null && log.invoiceFileUrl!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () => _openMaintenanceDocument(log.invoiceFileUrl!),
                tooltip: 'Ouvrir le document',
              ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ],
                  ),
                  onTap: () async {
                    await Future.delayed(const Duration(milliseconds: 100));
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddMaintenanceLogScreen(
                          vehicleId: widget.vehicleId,
                          maintenanceLog: log,
                        ),
                      ),
                    );
                    if (result == true) {
                      _refreshData();
                    }
                  },
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        'Supprimer',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ),
                  onTap: () {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _deleteMaintenanceLog(log);
                    });
                  },
                ),
              ],
            ),
            if (log.cost > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  NumberFormatter.formatCurrency(log.cost),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMaintenanceLog(MaintenanceLog log) async {
    final confirmed = await ConfirmationDialog.showDeleteConfirmation(
      context,
      title: 'Supprimer l\'entretien',
      content: 'Êtes-vous sûr de vouloir supprimer "${log.label}" ? Cette action est irréversible.',
    );

    if (confirmed) {
      try {
        await _garageService.deleteMaintenanceLog(widget.vehicleId, log.id);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Entretien supprimé avec succès');
          _refreshData();
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _openMaintenanceDocument(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          SnackBarHelper.showError(context, 'Impossible d\'ouvrir le document');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Erreur lors de l\'ouverture du document: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _editMaintenanceItem(MaintenanceItem item) async {
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
      _refreshData();
    }
  }

  Widget _buildDocumentCard(VehicleDocument document) {
    IconData iconData;
    Color iconColor;
    
    switch (document.type) {
      case 'ASSURANCE':
        iconData = Icons.shield;
        iconColor = Colors.blue;
        break;
      case 'CT':
        iconData = Icons.verified;
        iconColor = Colors.green;
        break;
      case 'FACTURE':
        iconData = Icons.receipt;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.description;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(document.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document.typeLabel),
            Text(DateFormat('dd/MM/yyyy').format(document.date)),
            if (document.notes != null && document.notes!.isNotEmpty)
              Text(
                document.notes!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.open_in_new, size: 20),
                  SizedBox(width: 8),
                  Text('Ouvrir'),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _openDocument(document);
                });
              },
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Modifier'),
                ],
              ),
              onTap: () async {
                await Future.delayed(const Duration(milliseconds: 100));
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddDocumentScreen(
                      vehicleId: widget.vehicleId,
                      document: {
                        'id': document.id,
                        'type': document.type,
                        'label': document.label,
                        'fileUrl': document.fileUrl,
                        'date': document.date.toIso8601String(),
                        'notes': document.notes,
                      },
                    ),
                  ),
                );
                if (result == true) {
                  _refreshData();
                }
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Supprimer',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _deleteDocument(document);
                });
              },
            ),
          ],
        ),
        onTap: () {
          _openDocument(document);
        },
      ),
    );
  }

  Widget _buildPhotosSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SectionCard(
          title: 'Photos',
          trailing: TextButton.icon(
            onPressed: _addPhotos,
            icon: const Icon(Icons.add_photo_alternate, size: 18),
            label: const Text('Ajouter'),
          ),
          children: [
            Consumer<PhotoGalleryController>(
              builder: (context, controller, _) {
                if (controller.isLoading && controller.photos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                
                if (controller.error != null && controller.photos.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Erreur: ${controller.error}',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => controller.loadFirstPage(),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                }
                
                if (controller.isEmpty) {
                  return EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'Aucune photo',
                    message: 'Ajoutez des photos de votre véhicule pour le personnaliser',
                    actionLabel: 'Ajouter des photos',
                    onAction: _addPhotos,
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPhotosGrid() {
    return Consumer<PhotoGalleryController>(
      builder: (context, controller, _) {
        if (controller.photos.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        
        // Calculer la taille de cache basée sur la largeur de l'écran
        final screenWidth = MediaQuery.of(context).size.width;
        final crossAxisCount = 3;
        final spacing = 8.0;
        final itemSize = (screenWidth - 32 - (spacing * (crossAxisCount - 1))) / crossAxisCount;
        
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= controller.photos.length) {
                  return null;
                }
                
                final photo = controller.photos[index];
                return PhotoGridItem(
                  photo: photo,
                  size: itemSize,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _PhotoViewerScreen(
                          photos: controller.photos,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  onDelete: () => _deletePhoto(index),
                );
              },
              childCount: controller.photos.length,
            ),
          ),
        );
      },
    );
  }
}

// Écran pour visualiser les photos en plein écran
class _PhotoViewerScreen extends StatelessWidget {
  final List<VehiclePhoto> photos;
  final int initialIndex;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${initialIndex + 1} / ${photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                ApiConfig.getFileUrl(photos[index].url),
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

