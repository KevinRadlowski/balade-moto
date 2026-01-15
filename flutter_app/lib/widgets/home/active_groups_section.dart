import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../screens/groups/group_detail_screen.dart';
import '../../screens/groups/groups_screen.dart';
import '../../constants/home_style_constants.dart';
import 'package:intl/intl.dart';

/// Section des groupes actifs
/// 
/// Affiche un carousel horizontal de groupes actifs avec :
/// - Nom du groupe
/// - Nombre de membres
/// - Activité récente (si disponible)
/// - CTA pour voir tous les groupes
class ActiveGroupsSection extends StatelessWidget {
  final List<Group> groups;
  final VoidCallback? onDataReload;

  const ActiveGroupsSection({
    super.key,
    required this.groups,
    this.onDataReload,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.group, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'Groupes actifs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GroupsScreen(),
                    ),
                  );
                },
                child: const Text('Voir tout'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: groups.length,
              itemBuilder: (context, index) {
                return _GroupCard(
                  group: groups[index],
                  onTap: () async {
                    // Ouvrir le groupe
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(
                          groupId: groups[index].id,
                        ),
                      ),
                    );
                    // Recharger les données pour mettre à jour le badge
                    onDataReload?.call();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'un groupe dans le carousel
class _GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.onTap,
  });

  String _getActivityText() {
    // TODO: Récupérer l'activité récente depuis le backend
    // Pour l'instant, on utilise lastMessageAt si disponible
    if (group.lastMessageAt != null) {
      final now = DateTime.now();
      final diff = now.difference(group.lastMessageAt!);
      
      if (diff.inMinutes < 1) {
        return 'À l\'instant';
      } else if (diff.inMinutes < 60) {
        return 'Il y a ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        return 'Il y a ${diff.inHours}h';
      } else {
        return DateFormat('d MMM', 'fr_FR').format(group.lastMessageAt!);
      }
    }
    return '${group.membres.length} membre${group.membres.length > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: HomeStyleConstants.innerCardDecoration,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeStyleConstants.innerCardRadius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(HomeStyleConstants.innerCardRadius),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nom du groupe
                Text(
                  group.nom,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Nombre de membres
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${group.membres.length} membre${group.membres.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Activité récente
                Text(
                  _getActivityText(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Badge non lus si disponible
                if (group.unreadCount != null && group.unreadCount! > 0) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${group.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
