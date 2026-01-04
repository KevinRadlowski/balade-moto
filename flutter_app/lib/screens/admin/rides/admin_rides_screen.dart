import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/admin/admin_ride.dart';
import '../../../services/admin/admin_rides_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/snackbar_helper.dart';

class AdminRidesScreen extends StatefulWidget {
  const AdminRidesScreen({super.key});

  @override
  State<AdminRidesScreen> createState() => _AdminRidesScreenState();
}

class _AdminRidesScreenState extends State<AdminRidesScreen> {
  late final AdminRidesService _service;
  final TextEditingController _searchController = TextEditingController();

  List<AdminRide> _rides = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  final int _limit = 50;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AdminRidesService(apiService: authService.apiService);
    _loadRides();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRides({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _rides = [];
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getRides(
        page: _currentPage,
        limit: _limit,
        query: _searchQuery.isEmpty ? null : _searchQuery,
      );

      final newRides = (result['rides'] as List<AdminRide>);
      final pagination = result['pagination'] as Map<String, dynamic>?;

      setState(() {
        _rides.addAll(newRides);
        _currentPage++;
        _hasMore = pagination?['pages'] != null &&
            _currentPage <= (pagination!['pages'] as int);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors du chargement');
      }
    }
  }

  Future<void> _deleteRide(AdminRide ride) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la balade'),
        content: Text('Voulez-vous supprimer "${ride.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteRide(ride.id);
      setState(() {
        _rides.removeWhere((r) => r.id == ride.id);
      });
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Balade supprimée');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors de la suppression');
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _loadRides(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modération des balades'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Rechercher (titre)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadRides(refresh: true),
              child: _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Erreur: $_error'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadRides(refresh: true),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : _rides.isEmpty && !_isLoading
                      ? const Center(child: Text('Aucune balade'))
                      : ListView.builder(
                          itemCount: _rides.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _rides.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : ElevatedButton(
                                          onPressed: () => _loadRides(),
                                          child: const Text('Charger plus'),
                                        ),
                                ),
                              );
                            }

                            final ride = _rides[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                title: Text(ride.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Date: ${ride.date}'),
                                    Text('Type: ${ride.typeVehicule}'),
                                    if (ride.createdByEmail != null)
                                      Text('Par: ${ride.createdByEmail}'),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteRide(ride),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

