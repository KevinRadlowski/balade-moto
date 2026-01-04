class AdminGroup {
  final String id;
  final String name;
  final String? description;
  final String visibilite; // 'publique' ou 'privee'
  final String? createdByEmail;
  final String? createdByPseudo;
  final int? membersCount;
  final DateTime createdAt;

  AdminGroup({
    required this.id,
    required this.name,
    this.description,
    required this.visibilite,
    this.createdByEmail,
    this.createdByPseudo,
    this.membersCount,
    required this.createdAt,
  });

  factory AdminGroup.fromJson(Map<String, dynamic> json) {
    return AdminGroup(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['nom'] ?? json['name'] ?? '',
      description: json['description'],
      visibilite: json['visibilite'] ?? json['visibility'] ?? 'publique',
      createdByEmail: json['createdBy']?['email'],
      createdByPseudo: json['createdBy']?['pseudo'],
      membersCount: json['membersCount'] ?? json['members']?.length,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  String get displayName => name;
  bool get isPublic => visibilite == 'publique';
}

