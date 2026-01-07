/// Modèle pour un élément du feed communautaire
/// 
/// TODO: Connecter au backend pour récupérer les vraies données d'activité
class CommunityFeedItem {
  final String id;
  final String type; // 'new_ride', 'new_group', 'ride_joined', 'ride_liked'
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? targetId; // ID de la balade ou du groupe concerné
  final String? targetType; // 'ride' ou 'group'
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  CommunityFeedItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.targetId,
    this.targetType,
    required this.createdAt,
    this.metadata,
  });

  factory CommunityFeedItem.fromJson(Map<String, dynamic> json) {
    return CommunityFeedItem(
      id: json['id'] ?? json['_id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      imageUrl: json['imageUrl'],
      targetId: json['targetId'],
      targetType: json['targetType'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'targetId': targetId,
      'targetType': targetType,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}
