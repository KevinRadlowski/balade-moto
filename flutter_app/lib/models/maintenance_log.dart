class MaintenanceLog {
  final String id;
  final String vehicleId;
  final String label;
  final String category;
  final DateTime date;
  final int kmAtService;
  final double cost;
  final String? garageName;
  final String? invoiceFileUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaintenanceLog({
    required this.id,
    required this.vehicleId,
    required this.label,
    required this.category,
    required this.date,
    required this.kmAtService,
    required this.cost,
    this.garageName,
    this.invoiceFileUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaintenanceLog.fromJson(Map<String, dynamic> json) {
    return MaintenanceLog(
      id: json['_id'] ?? json['id'] ?? '',
      vehicleId: json['vehicleId'] ?? json['vehicle'] ?? '',
      label: json['label'] ?? json['description'] ?? '',
      category: json['category'] ?? json['type'] ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      kmAtService: json['kmAtService'] ?? json['km'] ?? 0,
      cost: (json['cost'] ?? 0).toDouble(),
      garageName: json['garageName'],
      invoiceFileUrl: json['invoiceFileUrl'],
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
      'label': label,
      'category': category,
      'date': date.toIso8601String(),
      'kmAtService': kmAtService,
      'cost': cost,
      if (garageName != null && garageName!.isNotEmpty) 'garageName': garageName,
      if (invoiceFileUrl != null && invoiceFileUrl!.isNotEmpty) 'invoiceFileUrl': invoiceFileUrl,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}



