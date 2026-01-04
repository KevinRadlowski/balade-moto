import 'package:flutter/material.dart';
import '../../models/vehicle.dart';
import '../../services/garage_service.dart';
import '../../widgets/garage/vehicle_card.dart';
import '../../widgets/garage/empty_state.dart';
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Garage'),
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
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddVehicle,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un véhicule'),
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

