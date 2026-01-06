import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../config/api_config.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/ride/create_ride_with_map_screen.dart';
import '../../screens/groups/groups_screen.dart';

/// Header communautaire immersif pour la page d'accueil
/// 
/// Affiche :
/// - Avatar utilisateur (cliquable → Profil)
/// - Salutation dynamique selon l'heure
/// - Pseudo très visible
/// - Badge véhicule préféré
/// - Mini-statistiques communautaires
/// - Boutons CTA (Créer une balade, Rejoindre un groupe)
class HomeCommunityHeader extends StatelessWidget {
  final User? user;
  final int? ridesThisMonth;
  final int? activeGroups;
  final VoidCallback? onCreateRide;
  final VoidCallback? onJoinGroup;

  const HomeCommunityHeader({
    super.key,
    required this.user,
    this.ridesThisMonth,
    this.activeGroups,
    this.onCreateRide,
    this.onJoinGroup,
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

  String _getVehicleBadgeText(String? preference) {
    switch (preference) {
      case 'moto':
        return 'Moto';
      case 'voiture':
        return 'Voiture';
      case 'les deux':
        return 'Moto & Voiture';
      default:
        return 'Moto';
    }
  }

  String _getVehicleBadgeEmoji(String? preference) {
    switch (preference) {
      case 'moto':
        return '🏍️';
      case 'voiture':
        return '🚗';
      case 'les deux':
        return '🏍️🚗';
      default:
        return '🏍️';
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

  String _getAvatarUrl(String avatarUrl) {
    return ApiConfig.getFileUrl(avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 650;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.6),
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: isVerySmallScreen ? 8 : 16,
              bottom: isVerySmallScreen ? 12 : 24,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
              // Ligne 1 : Avatar + Badge véhicule
              Row(
                children: [
                  // Avatar cliquable
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: isVerySmallScreen ? 28 : 32,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: user?.avatarUrl != null &&
                                user!.avatarUrl!.isNotEmpty
                            ? NetworkImage(_getAvatarUrl(user!.avatarUrl!))
                            : null,
                        child: user?.avatarUrl == null ||
                                user!.avatarUrl!.isEmpty
                            ? Text(
                                (user?.pseudo?.substring(0, 1).toUpperCase() ??
                                        'U'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isVerySmallScreen ? 24 : 28,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Badge véhicule
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isVerySmallScreen ? 10 : 12,
                      vertical: isVerySmallScreen ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getVehicleBadgeColor(user?.vehiclePreference)
                          .withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getVehicleBadgeEmoji(user?.vehiclePreference),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getVehicleBadgeText(user?.vehiclePreference),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
                          SizedBox(height: isVerySmallScreen ? 12 : 20),
                          // Ligne 2 : Salutation
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: isVerySmallScreen ? 14 : 18,
                              fontWeight: FontWeight.w500,
                              shadows: const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isVerySmallScreen ? 4 : 8),
                          // Ligne 3 : Pseudo (très visible)
                          Text(
                            user?.pseudo ?? user?.displayName ?? 'Utilisateur',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isVerySmallScreen ? 32 : (isSmallScreen ? 40 : 48),
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isVerySmallScreen ? 16 : 24),
                          // Ligne 4 : Statistiques communautaires
                          _buildCommunityStats(context, isVerySmallScreen),
                          SizedBox(height: isVerySmallScreen ? 16 : 24),
                          // Ligne 5 : Boutons CTA
                          _buildActionButtons(context, isVerySmallScreen),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityStats(BuildContext context, bool isVerySmall) {
    // Calculer les statistiques à partir des données disponibles
    final stats = [
      {
        'label': 'balades',
        'value': ridesThisMonth ?? 0,
        'icon': Icons.directions_bike,
      },
      {
        'label': 'groupes',
        'value': activeGroups ?? 0,
        'icon': Icons.group,
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: stats.asMap().entries.map((entry) {
        final index = entry.key;
        final stat = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == 0 ? (isVerySmall ? 8 : 12) : 0, // Marge à droite pour la première carte
              left: index == stats.length - 1 ? (isVerySmall ? 8 : 12) : 0, // Marge à gauche pour la dernière carte
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isVerySmall ? 8 : 12,
                vertical: isVerySmall ? 10 : 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    stat['icon'] as IconData,
                    size: isVerySmall ? 20 : 24,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  SizedBox(height: isVerySmall ? 4 : 6),
                  Text(
                    '${stat['value']}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isVerySmall ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isVerySmall ? 2 : 4),
                  Text(
                    stat['label'] as String,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: isVerySmall ? 12 : 14,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isVerySmall) {
    return Row(
      children: [
        // Bouton primaire : Créer une balade
        Expanded(
          child: _ActionButton(
            icon: Icons.add_circle_outline,
            label: 'Créer une balade',
            onTap: onCreateRide ?? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateRideWithMapScreen(),
                ),
              );
            },
            isPrimary: true,
            isSmall: isVerySmall,
          ),
        ),
        const SizedBox(width: 12),
        // Bouton secondaire : Rejoindre un groupe
        Expanded(
          child: _ActionButton(
            icon: Icons.group_add,
            label: 'Rejoindre un groupe',
            onTap: onJoinGroup ?? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GroupsScreen(),
                ),
              );
            },
            isPrimary: false,
            isSmall: isVerySmall,
          ),
        ),
      ],
    );
  }
}

/// Bouton d'action stylisé pour le header communautaire
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isSmall;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary
          ? Colors.white.withOpacity(0.25)
          : Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 12 : 16,
              vertical: isSmall ? 12 : 16,
            ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isSmall ? 18 : 20,
                color: Colors.white,
              ),
              SizedBox(width: isSmall ? 6 : 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmall ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
