class CatalogProposal {
  final String id;
  final String type; // 'voiture' ou 'moto'
  final int year;
  final String make;
  final String model;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final String? reason;
  final String? createdByEmail;
  final String? createdByPseudo;
  final String? reviewedByEmail;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  CatalogProposal({
    required this.id,
    required this.type,
    required this.year,
    required this.make,
    required this.model,
    required this.status,
    this.reason,
    this.createdByEmail,
    this.createdByPseudo,
    this.reviewedByEmail,
    required this.createdAt,
    this.reviewedAt,
  });

  factory CatalogProposal.fromJson(Map<String, dynamic> json) {
    return CatalogProposal(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? '',
      year: json['year'] ?? 0,
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      status: json['status'] ?? 'PENDING',
      reason: json['reason'],
      createdByEmail: json['createdByUserId']?['email'],
      createdByPseudo: json['createdByUserId']?['pseudo'],
      reviewedByEmail: json['reviewedByUserId']?['email'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'])
          : null,
    );
  }

  String get displayName => '$make $model ($year)';
}

