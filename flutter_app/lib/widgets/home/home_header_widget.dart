import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../config/api_config.dart';

/// Widget pour le header de la page d'accueil
class HomeHeaderWidget extends StatelessWidget {
  final User? user;
  final String secondaryMessage;

  const HomeHeaderWidget({
    super.key,
    required this.user,
    required this.secondaryMessage,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Bonjour';
    } else if (hour < 18) {
      return 'Bon après-midi';
    } else {
      return 'Bonsoir';
    }
  }

  String _getAvatarUrl(String avatarUrl) {
    return ApiConfig.getFileUrl(avatarUrl);
  }

  String _getVehicleBadgeText(String? preference) {
    switch (preference) {
      case 'moto':
        return '🏍️ Moto';
      case 'voiture':
        return '🚗 Voiture';
      case 'les deux':
        return '🏍️🚗 Moto & Voiture';
      default:
        return '🏍️ Moto';
    }
  }

  Color _getVehicleBadgeColor(String? preference) {
    switch (preference) {
      case 'moto':
        return Colors.orange.shade700;
      case 'voiture':
        return Colors.blue.shade700;
      case 'les deux':
        return Colors.purple.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Builder(
                builder: (context) {
                  final hasAvatar = user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty;
                  
                  if (hasAvatar) {
                    return CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: NetworkImage(_getAvatarUrl(user!.avatarUrl!)),
                      onBackgroundImageError: (exception, stackTrace) {
                        debugPrint('Erreur de chargement de l\'avatar: $exception');
                      },
                    );
                  } else {
                    return CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: Text(
                        user?.displayName != null && user!.displayName.isNotEmpty
                            ? user!.displayName.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 12),
              // Message de bienvenue
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_getGreeting()}, ${user?.displayName ?? "Utilisateur"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      secondaryMessage,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Badge véhicule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getVehicleBadgeColor(user?.vehiclePreference).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getVehicleBadgeText(user?.vehiclePreference),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

