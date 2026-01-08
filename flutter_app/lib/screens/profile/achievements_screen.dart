import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/achievement.dart';
import '../../models/reputation.dart';
import '../../services/auth_service.dart';
import '../../config/api_config.dart';
import 'dart:convert';

class AchievementsScreen extends StatefulWidget {
  final String userId;

  const AchievementsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _achievements = [];
  Reputation? _reputation;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
    _loadReputation();
  }

  Future<void> _loadAchievements() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = authService.apiService;
      final token = await authService.storage.read(key: 'token');
      apiService.setToken(token);

      final uri = Uri.parse('${ApiConfig.apiUrl}/reputation/${widget.userId}/achievements');
      final response = await apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final achievements = (data['data']['achievements'] as List)
            .map((a) => Achievement.fromJson(a))
            .toList();
        
        // Trier les badges : obtenus en premier, puis non obtenus
        achievements.sort((a, b) {
          if (a.isEarned && !b.isEarned) return -1;
          if (!a.isEarned && b.isEarned) return 1;
          return 0; // Garder l'ordre original pour les badges du même statut
        });
        
        setState(() {
          _achievements = achievements;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadReputation() async {
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
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getAchievementColor(bool isEarned) {
    return isEarned ? Colors.amber.shade600 : Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Badges'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _loadAchievements();
                          _loadReputation();
                        },
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadAchievements();
                    await _loadReputation();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_reputation != null) ...[
                        // En-tête avec niveau
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Niveau: ${_reputation!.levelDisplayName}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Score: ${_reputation!.score}/100',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.workspace_premium,
                                  size: 48,
                                  color: _getAchievementColor(true),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Liste des badges
                      Text(
                        'Badges (${_achievements.where((a) => a.isEarned).length}/${_achievements.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _achievements.length,
                        itemBuilder: (context, index) {
                          final achievement = _achievements[index];
                          return _AchievementCard(achievement: achievement);
                        },
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const _AchievementCard({
    required this.achievement,
  });

  Color _getColor(bool isEarned) {
    return isEarned ? Colors.amber.shade600 : Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(achievement.isEarned);

    return Card(
      elevation: achievement.isEarned ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              achievement.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              achievement.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (!achievement.isEarned) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: achievement.progressPercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${achievement.progress}/${achievement.target}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Débloqué',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

