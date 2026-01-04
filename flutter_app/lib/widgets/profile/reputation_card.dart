import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reputation.dart';
import '../../services/auth_service.dart';
import '../../config/api_config.dart';
import '../../screens/profile/achievements_screen.dart';
import 'dart:convert';

class ReputationCard extends StatefulWidget {
  final String userId;

  const ReputationCard({
    super.key,
    required this.userId,
  });

  @override
  State<ReputationCard> createState() => _ReputationCardState();
}

class _ReputationCardState extends State<ReputationCard> {
  Reputation? _reputation;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReputation();
  }

  Future<void> _loadReputation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = authService.apiService;
      final token = await authService.storage.read(key: 'token');
      apiService.setToken(token);

      final uri = Uri.parse('${ApiConfig.apiUrl}/reputation/${widget.userId}');
      final response = await apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _reputation = Reputation.fromJson(data['data']['reputation']);
          _isLoading = false;
        });
      } else {
        throw Exception('Erreur lors de la récupération de la réputation');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'bronze':
        return Colors.brown.shade400;
      case 'silver':
        return Colors.grey.shade400;
      case 'gold':
        return Colors.amber.shade600;
      case 'platinum':
        return Colors.blueGrey.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'bronze':
        return Icons.workspace_premium;
      case 'silver':
        return Icons.workspace_premium;
      case 'gold':
        return Icons.workspace_premium;
      case 'platinum':
        return Icons.workspace_premium;
      default:
        return Icons.workspace_premium;
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
            ],
          ),
        ),
      );
    }

    if (_reputation == null) {
      return const SizedBox.shrink();
    }

    final levelColor = _getLevelColor(_reputation!.level);
    final levelIcon = _getLevelIcon(_reputation!.level);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AchievementsScreen(userId: widget.userId),
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
                      Icon(levelIcon, color: levelColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Confiance',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: levelColor, width: 1.5),
                    ),
                    child: Text(
                      _reputation!.levelDisplayName,
                      style: TextStyle(
                        color: levelColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Score
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Score',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${_reputation!.score}/100',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Barre de progression
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _reputation!.score / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
              // Statistiques
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    icon: Icons.directions_bike,
                    label: 'Balades',
                    value: '${_reputation!.rideCount}',
                  ),
                  _StatItem(
                    icon: Icons.feedback,
                    label: 'Avis',
                    value: '${_reputation!.feedbackCount}',
                  ),
                  _StatItem(
                    icon: Icons.access_time,
                    label: 'Ponctualité',
                    value: '${_reputation!.punctualityScore}%',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Lien vers les badges
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AchievementsScreen(userId: widget.userId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('Voir mes badges'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 24),
        const SizedBox(height: 4),
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

