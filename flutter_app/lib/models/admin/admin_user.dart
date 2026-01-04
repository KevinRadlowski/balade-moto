class AdminUser {
  final String id;
  final String email;
  final String? pseudo;
  final String role; // 'MEMBER' ou 'ADMIN'
  final DateTime createdAt;
  final bool? banned;

  AdminUser({
    required this.id,
    required this.email,
    this.pseudo,
    required this.role,
    required this.createdAt,
    this.banned,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['_id'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      pseudo: json['pseudo'],
      role: json['role'] ?? 'MEMBER',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      banned: json['banned'],
    );
  }

  String get displayName => pseudo ?? email;
}

