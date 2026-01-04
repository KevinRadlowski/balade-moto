class MaintenanceItem {
  final String id;
  final String vehicleId;
  final String label;
  final String category;
  final int? intervalKm;
  final int? intervalMonths;
  final int? lastDoneAtKm;
  final DateTime? lastDoneAtDate;
  final int? dueAtKm;
  final DateTime? dueAtDate;
  final String status; // DUE, UPCOMING, DONE, SKIPPED
  final String? notes;
  final bool active;

  MaintenanceItem({
    required this.id,
    required this.vehicleId,
    required this.label,
    required this.category,
    this.intervalKm,
    this.intervalMonths,
    this.lastDoneAtKm,
    this.lastDoneAtDate,
    this.dueAtKm,
    this.dueAtDate,
    required this.status,
    this.notes,
    required this.active,
  });

  factory MaintenanceItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceItem(
      id: json['_id'] ?? json['id'] ?? '',
      vehicleId: json['vehicleId'] ?? json['vehicle'] ?? '',
      label: json['label'] ?? json['name'] ?? '',
      category: json['category'] ?? json['type'] ?? '',
      intervalKm: json['intervalKm'],
      intervalMonths: json['intervalMonths'],
      lastDoneAtKm: json['lastDoneAtKm'],
      lastDoneAtDate: json['lastDoneAtDate'] != null 
          ? DateTime.parse(json['lastDoneAtDate']) 
          : null,
      dueAtKm: json['dueAtKm'],
      dueAtDate: json['dueAtDate'] != null 
          ? DateTime.parse(json['dueAtDate']) 
          : null,
      status: json['status'] ?? 'UPCOMING',
      notes: json['notes'],
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'category': category,
      if (intervalKm != null) 'intervalKm': intervalKm,
      if (intervalMonths != null) 'intervalMonths': intervalMonths,
      if (lastDoneAtKm != null) 'lastDoneAtKm': lastDoneAtKm,
      if (lastDoneAtDate != null) 'lastDoneAtDate': lastDoneAtDate!.toIso8601String(),
      if (dueAtKm != null) 'dueAtKm': dueAtKm,
      if (dueAtDate != null) 'dueAtDate': dueAtDate!.toIso8601String(),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  bool get isDue => status == 'DUE';
  bool get isUpcoming => status == 'UPCOMING';
}



