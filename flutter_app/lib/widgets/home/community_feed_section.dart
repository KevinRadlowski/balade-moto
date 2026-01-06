import 'package:flutter/material.dart';
import '../../models/community_feed_item.dart';
import '../../models/ride.dart';
import '../../models/group.dart';
import '../../screens/ride/ride_detail_screen.dart';
import '../../screens/groups/group_detail_screen.dart';
import '../../constants/home_style_constants.dart';
import 'package:intl/intl.dart';

/// Section du feed communautaire
/// 
/// Affiche un feed d'activité avec des cartes pour :
/// - Nouvelles balades proposées
/// - Nouveaux groupes créés
/// - Participants qui rejoignent des balades
/// - Likes sur des balades
/// 
/// TODO: Connecter au backend pour récupérer les vraies données d'activité
class CommunityFeedSection extends StatelessWidget {
  final List<CommunityFeedItem>? feedItems;
  final List<Ride>? recentRides;
  final List<Group>? recentGroups;

  const CommunityFeedSection({
    super.key,
    this.feedItems,
    this.recentRides,
    this.recentGroups,
  });

  /// Génère des items de feed mockés à partir des données disponibles
  List<CommunityFeedItem> _generateFeedItems() {
    final items = <CommunityFeedItem>[];
    final now = DateTime.now();

    // Si on a des feedItems fournis, les utiliser
    if (feedItems != null && feedItems!.isNotEmpty) {
      return feedItems!;
    }

    // Sinon, générer des items mockés à partir des rides et groupes récents
    if (recentRides != null) {
      for (final ride in recentRides!.take(3)) {
        items.add(CommunityFeedItem(
          id: 'feed_ride_${ride.id}',
          type: 'new_ride',
          title: 'Nouvelle balade proposée : ${ride.titre}',
          subtitle: 'Par ${ride.organisateur.pseudo ?? ride.organisateur.displayName}',
          targetId: ride.id,
          targetType: 'ride',
          createdAt: ride.date,
        ));
      }
    }

    if (recentGroups != null) {
      for (final group in recentGroups!.take(2)) {
        items.add(CommunityFeedItem(
          id: 'feed_group_${group.id}',
          type: 'new_group',
          title: 'Nouveau groupe créé : ${group.nom}',
          subtitle: '${group.membres.length} membre${group.membres.length > 1 ? 's' : ''}',
          targetId: group.id,
          targetType: 'group',
          createdAt: group.lastMessageAt ?? now, // Utiliser lastMessageAt comme approximation
        ));
      }
    }

    // Si aucune donnée, créer des placeholders
    if (items.isEmpty) {
      items.addAll([
        CommunityFeedItem(
          id: 'feed_placeholder_1',
          type: 'new_ride',
          title: 'Nouvelle balade proposée : Balade en montagne',
          subtitle: 'Par Rider123',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        CommunityFeedItem(
          id: 'feed_placeholder_2',
          type: 'new_group',
          title: 'Nouveau groupe créé : Moto Club Paris',
          subtitle: '12 membres',
          createdAt: now.subtract(const Duration(hours: 5)),
        ),
        CommunityFeedItem(
          id: 'feed_placeholder_3',
          type: 'ride_joined',
          title: '5 personnes participent à "Balade côtière"',
          subtitle: 'Il y a 1 heure',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ]);
    }

    // Trier par date (plus récent en premier)
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return items.take(5).toList(); // Limiter à 5 items
  }

  @override
  Widget build(BuildContext context) {
    final items = _generateFeedItems();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: HomeStyleConstants.cardPadding,
      decoration: HomeStyleConstants.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dynamic_feed, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              const Text(
                'Fil communautaire',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _FeedItemCard(
                item: item,
                onTap: () => _handleItemTap(context, item),
              )),
        ],
      ),
    );
  }

  void _handleItemTap(BuildContext context, CommunityFeedItem item) {
    if (item.targetId == null) return;

    if (item.targetType == 'ride') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideDetailScreen(rideId: item.targetId!),
        ),
      );
    } else if (item.targetType == 'group') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(groupId: item.targetId!),
        ),
      );
    }
  }
}

/// Carte d'un item du feed
class _FeedItemCard extends StatelessWidget {
  final CommunityFeedItem item;
  final VoidCallback onTap;

  const _FeedItemCard({
    required this.item,
    required this.onTap,
  });

  IconData _getIcon() {
    switch (item.type) {
      case 'new_ride':
        return Icons.directions_bike;
      case 'new_group':
        return Icons.group_add;
      case 'ride_joined':
        return Icons.people;
      case 'ride_liked':
        return Icons.favorite;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor() {
    switch (item.type) {
      case 'new_ride':
        return Colors.blue.shade700;
      case 'new_group':
        return Colors.purple.shade700;
      case 'ride_joined':
        return Colors.green.shade700;
      case 'ride_liked':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final diff = now.difference(item.createdAt);

    if (diff.inMinutes < 1) {
      return 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays}j';
    } else {
      return DateFormat('d MMM', 'fr_FR').format(item.createdAt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: HomeStyleConstants.innerCardDecoration,
      child: InkWell(
        onTap: item.targetId != null ? onTap : null,
        borderRadius: BorderRadius.circular(HomeStyleConstants.innerCardRadius),
        child: Padding(
          padding: HomeStyleConstants.innerCardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getIconColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIcon(),
                  size: 20,
                  color: _getIconColor(),
                ),
              ),
              const SizedBox(width: 12),
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _getTimeAgo(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.targetId != null)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
