import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_stats_provider.dart';
import '../../models/vehicle_stats.dart';
import '../../utils/number_formatter.dart';

class VehicleStatsCard extends StatefulWidget {
  final String vehicleId;

  const VehicleStatsCard({
    super.key,
    required this.vehicleId,
  });

  @override
  State<VehicleStatsCard> createState() => _VehicleStatsCardState();
}

class _VehicleStatsCardState extends State<VehicleStatsCard> {
  VehicleStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats(useCache: false); // Toujours recharger depuis le serveur pour avoir les données à jour
  }

  @override
  void didUpdateWidget(VehicleStatsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recharger les stats si le vehicleId change
    if (oldWidget.vehicleId != widget.vehicleId) {
      _loadStats(useCache: false);
    }
  }

  Future<void> _loadStats({bool useCache = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<VehicleStatsProvider>(context, listen: false);
      // Nettoyer le cache pour forcer le rechargement
      provider.clearCacheForVehicle(widget.vehicleId);
      final stats = await provider.getVehicleStats(
        vehicleId: widget.vehicleId,
        useCache: false, // Toujours recharger depuis le serveur
      );
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errorMessage != null) {
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
                onPressed: _loadStats,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stats == null) {
      return const SizedBox.shrink();
    }

    final stats = _stats!;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Statistiques',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Grille de statistiques (2x3)
                // Première ligne : Balades - Dernière balade
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.directions_bike,
                        label: 'Balades',
                        value: '${stats.rideCount}',
                        color: Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.route,
                        label: 'Dernière balade',
                        value: NumberFormatter.formatRelativeDate(stats.lastRideDate),
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Deuxième ligne : Entretiens - Dernier entretien
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.build,
                        label: 'Entretiens',
                        value: '${stats.maintenanceCount}',
                        color: Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.calendar_today,
                        label: 'Dernier entretien',
                        value: NumberFormatter.formatRelativeDate(stats.lastMaintenanceDate),
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Troisième ligne : Coût total - Km depuis dernier entretien
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.euro,
                        label: 'Coût total',
                        value: '${NumberFormatter.formatCurrency(stats.totalCost)}',
                        color: Colors.purple,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.speed,
                        label: 'Depuis dernier entretien',
                        value: NumberFormatter.formatKmOptional(stats.kmSinceLastMaintenance),
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }
}

