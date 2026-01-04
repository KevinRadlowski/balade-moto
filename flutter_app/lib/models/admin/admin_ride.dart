class AdminRide {
  final String id;
  final String title;
  final String? description;
  final String date;
  final String? createdByEmail;
  final String? createdByPseudo;
  final String typeVehicule;
  final DateTime createdAt;

  AdminRide({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.createdByEmail,
    this.createdByPseudo,
    required this.typeVehicule,
    required this.createdAt,
  });

  factory AdminRide.fromJson(Map<String, dynamic> json) {
    return AdminRide(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['titre'] ?? json['title'] ?? '',
      description: json['description'],
      date: json['date'] ?? '',
      createdByEmail: json['organisateur']?['email'],
      createdByPseudo: json['organisateur']?['pseudo'],
      typeVehicule: json['typeVehicule'] ?? json['type'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  String get displayName => title;
}

