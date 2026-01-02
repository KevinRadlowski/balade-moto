import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../screens/groups/group_detail_screen.dart';
import '../../utils/date_helper.dart';
import '../../constants/home_style_constants.dart';

/// Widget pour la carte d'un groupe favori
/// 
/// Affiche un indicateur d'activité intelligent :
/// - Si unreadCount > 0 : "{unreadCount} nouveau(x)" + point vert
/// - Sinon si lastMessageAt dispo : "Dernier msg: il y a X min/h"
/// - Sinon : rien
class FavoriteGroupsCard extends StatelessWidget {
  final Group group;
  final VoidCallback onDataReload;

  const FavoriteGroupsCard({
    super.key,
    required this.group,
    required this.onDataReload,
  });

  String? _getActivityIndicator() {
    // Priorité 1 : unreadCount
    if (group.unreadCount != null && group.unreadCount! > 0) {
      final count = group.unreadCount!;
      return '$count nouveau${count > 1 ? 'x' : ''}';
    }
    
    // Priorité 2 : lastMessageAt
    if (group.lastMessageAt != null) {
      return 'Dernier msg: ${DateHelper.formatTimeAgo(group.lastMessageAt!)}';
    }
    
    // Aucun indicateur
    return null;
  }

  bool _hasUnreadMessages() {
    return group.unreadCount != null && group.unreadCount! > 0;
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = group.visibilite == 'publique';
    final activityText = _getActivityIndicator();
    final hasUnread = _hasUnreadMessages();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: HomeStyleConstants.innerCardDecoration,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(groupId: group.id),
            ),
          ).then((_) => onDataReload());
        },
        borderRadius: BorderRadius.circular(HomeStyleConstants.innerCardRadius),
        child: Padding(
          padding: HomeStyleConstants.innerCardPadding,
          child: Row(
            children: [
              // Icône groupe avec indicateur d'activité
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (isPublic ? Colors.green : Colors.orange).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPublic ? Icons.public : Icons.lock,
                      color: isPublic ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Infos groupe
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.nom,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (activityText != null && hasUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              activityText,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group.membres.length} membre${group.membres.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isPublic ? Colors.green : Colors.orange).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPublic ? 'Public' : 'Privé',
                            style: TextStyle(
                              fontSize: 10,
                              color: isPublic ? Colors.green.shade700 : Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (activityText != null && !hasUnread) ...[
                          const SizedBox(width: 12),
                          Text(
                            activityText,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

