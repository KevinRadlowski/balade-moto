class OdometerEntry {
  final String id;
  final String vehicleId;
  final DateTime date;
  final int km;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  OdometerEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.km,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OdometerEntry.fromJson(Map<String, dynamic> json) {
    return OdometerEntry(
      id: json['_id'] ?? json['id'] ?? '',
      vehicleId: json['vehicleId'] ?? json['vehicle'] ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      km: json['km'] ?? 0,
      note: json['note'] ?? json['notes'],
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
      'km': km,
      'date': date.toIso8601String(),
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }
}








