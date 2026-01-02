import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/ride.dart';
import '../../models/group.dart';
import '../../config/api_config.dart';

/// Widget pour le header hero de la page d'accueil
/// 
/// Hero section immersive qui occupe 25-30% de l'écran avec :
/// - Overlay gradient vertical pour la lisibilité
/// - Hiérarchie typographique renforcée
/// - Avatar et badge véhicule mis en valeur
/// - Micro-signal d'activité optionnel
class HomeHeroHeader extends StatelessWidget {
  final User? user;
  final String secondaryMessage;
  final Ride? nextRide;
  final List<Group>? groups;
  final int? upcomingRidesCount;

  const HomeHeroHeader({
    super.key,
    required this.user,
    required this.secondaryMessage,
    this.nextRide,
    this.groups,
    this.upcomingRidesCount,
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

  /// Obtient le prénom de l'utilisateur (premier mot du displayName)
  String _getFirstName() {
    if (user?.displayName == null || user!.displayName.isEmpty) {
      return 'Utilisateur';
    }
    final parts = user!.displayName.split(' ');
    return parts.first;
  }

  /// Obtient le nom de famille (reste du displayName)
  String? _getLastName() {
    if (user?.displayName == null || user!.displayName.isEmpty) {
      return null;
    }
    final parts = user!.displayName.split(' ');
    if (parts.length > 1) {
      return parts.sublist(1).join(' ');
    }
    return null;
  }

  /// Génère le micro-signal d'activité
  String? _getActivitySignal() {
    // Priorité 1 : Prochaine balade avec date
    if (nextRide != null) {
      final dateTime = DateTime(
        nextRide!.date.year,
        nextRide!.date.month,
        nextRide!.date.day,
        int.parse(nextRide!.heure.split(':')[0]),
        int.parse(nextRide!.heure.split(':')[1]),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final rideDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
      
      if (rideDate == today) {
        return 'Balade aujourd\'hui';
      } else {
        final daysUntil = rideDate.difference(today).inDays;
        if (daysUntil == 1) {
          return 'Balade demain';
        } else if (daysUntil <= 7) {
          final weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
          return 'Balade ${weekdays[rideDate.weekday - 1]}';
        }
      }
    }
    
    // Priorité 2 : Nombre de balades à venir
    if (upcomingRidesCount != null && upcomingRidesCount! > 0) {
      return '$upcomingRidesCount balade${upcomingRidesCount! > 1 ? 's' : ''} à venir';
    }
    
    // Priorité 3 : Groupes actifs
    if (groups != null && groups!.isNotEmpty) {
      final activeGroups = groups!.where((g) {
        return g.unreadCount != null && g.unreadCount! > 0;
      }).length;
      if (activeGroups > 0) {
        return '$activeGroups groupe${activeGroups > 1 ? 's' : ''} actif${activeGroups > 1 ? 's' : ''}';
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activitySignal = _getActivitySignal();
    final firstName = _getFirstName();
    final lastName = _getLastName();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Overlay gradient vertical pour améliorer la lisibilité
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.4),
            Colors.black.withOpacity(0.6),
          ],
          stops: const [0.0, 0.5, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false, // Ne pas forcer le SafeArea en bas pour éviter les problèmes
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Utiliser les contraintes disponibles plutôt qu'une hauteur fixe
            // Padding adaptatif selon la taille de l'écran
            final screenHeight = MediaQuery.of(context).size.height;
            final isSmallScreen = screenHeight < 700;
            final isVerySmallScreen = screenHeight < 650; // Écrans très petits (Xiaomi)
            
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight, // Respecter strictement la hauteur disponible
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20, 
                  right: 20, 
                  top: isVerySmallScreen ? 8 : 16, 
                  bottom: isVerySmallScreen ? 0 : (isSmallScreen ? 4 : 12), // Encore plus réduit, 0 sur très petits écrans
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min, // Important : ne pas forcer la hauteur
                  children: [
                    // Ligne 1 : Avatar + Badge véhicule
                    Row(
                      children: [
                        // Avatar agrandi (réduit sur petits écrans)
                        Builder(
                          builder: (context) {
                            final hasAvatar = user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty;
                            
                            if (hasAvatar) {
                              return CircleAvatar(
                                radius: isVerySmallScreen ? 28 : 32,
                                backgroundColor: Colors.white.withOpacity(0.25),
                                backgroundImage: NetworkImage(_getAvatarUrl(user!.avatarUrl!)),
                                onBackgroundImageError: (exception, stackTrace) {
                                  debugPrint('Erreur de chargement de l\'avatar: $exception');
                                },
                              );
                            } else {
                              return CircleAvatar(
                                radius: isVerySmallScreen ? 28 : 32,
                                backgroundColor: Colors.white.withOpacity(0.25),
                                child: Text(
                                  firstName.isNotEmpty
                                      ? firstName.substring(0, 1).toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isVerySmallScreen ? 24 : 28,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        const Spacer(),
                        // Badge véhicule
                        Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isVerySmallScreen ? 10 : 12, 
                          vertical: isVerySmallScreen ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getVehicleBadgeColor(user?.vehiclePreference).withOpacity(0.9),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Emoji séparé pour un meilleur alignement
                            Text(
                              _getVehicleBadgeEmoji(user?.vehiclePreference),
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.0, // Hauteur fixe pour l'emoji
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Texte séparé
                            Text(
                              _getVehicleBadgeText(user?.vehiclePreference),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                height: 1.2, // Ajuster la hauteur de ligne pour un meilleur alignement
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ),
                    SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 8 : 12)), // Encore plus réduit
                    // Ligne 2 : Salutation (petit texte secondaire)
                    Text(
                      _getGreeting(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 15), // Encore plus petit
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 2 : (isSmallScreen ? 3 : 5)), // Encore plus réduit
                    // Ligne 3 : Prénom (grand et visible)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            firstName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isVerySmallScreen ? 26 : (isSmallScreen ? 30 : 36), // Encore plus petit
                              fontWeight: FontWeight.bold,
                              height: 1.0, // Réduire la hauteur de ligne
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
                        ),
                        if (lastName != null && lastName.isNotEmpty) ...[
                          SizedBox(width: isVerySmallScreen ? 4 : 8),
                          Flexible(
                            child: Text(
                              lastName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: isVerySmallScreen ? 20 : (isSmallScreen ? 22 : 28), // Encore plus petit
                                fontWeight: FontWeight.w600,
                                height: 1.0, // Réduire la hauteur de ligne
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
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: isVerySmallScreen ? 3 : (isSmallScreen ? 5 : 7)), // Encore plus réduit
                    // Ligne 4 : Sous-texte (bien lisible mais secondaire)
                    Text(
                      secondaryMessage,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 16), // Encore plus petit
                        fontWeight: FontWeight.w500,
                        height: isVerySmallScreen ? 1.1 : 1.2, // Réduire la hauteur de ligne
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      maxLines: isVerySmallScreen ? 1 : 2, // Limiter à 1 ligne sur très petits écrans
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Ligne 5 : Micro-signal d'activité (optionnel, très léger)
                    // Masqué sur très petits écrans pour éviter l'overflow
                    if (activitySignal != null && !isVerySmallScreen) ...[
                      SizedBox(height: isSmallScreen ? 3 : 5), // Réduire encore plus sur petits écrans
                      Text(
                        activitySignal,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

