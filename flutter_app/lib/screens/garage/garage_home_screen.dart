import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../services/garage_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/garage/vehicle_card.dart';
import '../../widgets/garage/empty_state.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/premium/premium_upsell_modal.dart';
import '../../utils/background_helper.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

class GarageHomeScreen extends StatefulWidget {
  const GarageHomeScreen({super.key});

  @override
  State<GarageHomeScreen> createState() => _GarageHomeScreenState();
}

class _GarageHomeScreenState extends State<GarageHomeScreen> {
  final GarageService _garageService = GarageService();
  final ScrollController _scrollController = ScrollController();

  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreVehicles();
    }
  }

  Future<void> _loadVehicles({bool refresh = false}) async {
    if (!mounted) return;

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _vehicles = [];
        _hasMore = true;
      });
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _garageService.listVehicles(
        page: _currentPage,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _vehicles = result['vehicles'] as List<Vehicle>;
          } else {
            _vehicles.addAll(result['vehicles'] as List<Vehicle>);
          }
          final pagination = result['pagination'] as Map<String, dynamic>;
          _hasMore = _currentPage < (pagination['pages'] as int);
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

  Future<void> _loadMoreVehicles() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    setState(() {
      _currentPage++;
    });

    try {
      final result = await _garageService.listVehicles(
        page: _currentPage,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _vehicles.addAll(result['vehicles'] as List<Vehicle>);
          final pagination = result['pagination'] as Map<String, dynamic>;
          _hasMore = _currentPage < (pagination['pages'] as int);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPage--; // Revenir à la page précédente en cas d'erreur
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshVehicles() async {
    await _loadVehicles(refresh: true);
  }

  void _navigateToAddVehicle() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
    );

    if (result == true) {
      _refreshVehicles();
      // Rafraîchir le plan pour mettre à jour les quotas
      final planProvider = Provider.of<PlanProvider>(context, listen: false);
      planProvider.loadPlan(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;
    final customGarageBackground = user?.customBackgrounds?['garage'];
    final globalBackground = user?.customBackgrounds?['global'];
    final backgroundImage = (customGarageBackground != null && customGarageBackground.isNotEmpty)
        ? customGarageBackground
        : (globalBackground != null && globalBackground.isNotEmpty)
            ? globalBackground
            : getGarageBackgroundImageName(user?.vehiclePreference);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Garage'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/images/logo.png',
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: backgroundImage.startsWith('http') || backgroundImage.startsWith('/uploads')
                ? NetworkImage(backgroundImage) as ImageProvider
                : AssetImage(backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: _buildBody(),
      ),
      floatingActionButton: Consumer<PlanProvider>(
        builder: (context, planProvider, _) {
          final isPremium = planProvider.isPremium;
          final plan = planProvider.plan;
          
          // Si premium, toujours autoriser
          // Si plan pas encore chargé, autoriser (on vérifiera côté backend)
          // Si plan chargé et FREE, vérifier les limites
          final canAddVehicle = isPremium || 
              plan == null || 
              plan.remainingVehiclesTotal > 0;
          
          return FloatingActionButton.extended(
            onPressed: canAddVehicle ? _navigateToAddVehicle : () {
              showPremiumUpsellModal(
                context,
                reason: 'Limite de véhicules atteinte. Passez en Premium pour ajouter un nombre illimité de véhicules.',
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un véhicule'),
            tooltip: canAddVehicle ? null : 'Limite de véhicules atteinte',
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _vehicles.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _vehicles.isEmpty) {
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
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _refreshVehicles,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_vehicles.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshVehicles,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _vehicles.length + (_hasMore && !_isLoadingMore ? 1 : 0) + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _vehicles.length && _isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (index == _vehicles.length && _hasMore && !_isLoadingMore) {
            return _buildLoadMoreButton();
          }
          return _buildVehicleCard(_vehicles[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.garage_outlined,
      title: 'Aucun véhicule',
      message: 'Commencez par ajouter votre premier véhicule',
      actionLabel: 'Ajouter un véhicule',
      onAction: _navigateToAddVehicle,
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    return VehicleCard(
      vehicle: vehicle,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VehicleDetailScreen(vehicleId: vehicle.id),
          ),
        ).then((result) {
          if (result == true) {
            _refreshVehicles();
            // Rafraîchir le plan pour mettre à jour les quotas
            final planProvider = Provider.of<PlanProvider>(context, listen: false);
            planProvider.loadPlan(silent: true);
          }
        });
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: TextButton(
          onPressed: _loadMoreVehicles,
          child: const Text('Charger plus'),
        ),
      ),
    );
  }
}

