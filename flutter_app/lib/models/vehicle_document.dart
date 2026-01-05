class VehicleDocument {
  final String id;
  final String vehicleId;
  final String type; // ASSURANCE, CT, FACTURE, AUTRE
  final String label;
  final String fileUrl;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleDocument({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.label,
    required this.fileUrl,
    required this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleDocument.fromJson(Map<String, dynamic> json) {
    return VehicleDocument(
      id: json['_id'] ?? json['id'] ?? '',
      vehicleId: json['vehicleId'] ?? json['vehicle'] ?? '',
      type: json['type'] ?? '',
      label: json['label'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      notes: json['notes'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'label': label,
      'fileUrl': fileUrl,
      'date': date.toIso8601String(),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  String get typeLabel {
    switch (type) {
      case 'ASSURANCE':
        return 'Assurance';
      case 'CT':
        return 'Contrôle technique';
      case 'FACTURE':
        return 'Facture';
      case 'AUTRE':
        return 'Autre';
      default:
        return type;
    }
  }
}





