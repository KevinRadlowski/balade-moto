class MaintenanceReminder {
  final String id;
  final String userId;
  final String? vehicleId;
  final String type;
  final String description;
  final int? intervalKm;
  final int? intervalMonths;
  final double? lastDoneKm;
  final DateTime? lastDoneDate;
  final double? nextDueKm;
  final DateTime? nextDueDate;
  final String status; // 'active', 'snoozed', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  MaintenanceReminder({
    required this.id,
    required this.userId,
    this.vehicleId,
    required this.type,
    required this.description,
    this.intervalKm,
    this.intervalMonths,
    this.lastDoneKm,
    this.lastDoneDate,
    this.nextDueKm,
    this.nextDueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaintenanceReminder.fromJson(Map<String, dynamic> json) {
    return MaintenanceReminder(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      vehicleId: json['vehicleId'],
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      intervalKm: json['intervalKm'],
      intervalMonths: json['intervalMonths'],
      lastDoneKm: json['lastDoneKm']?.toDouble(),
      lastDoneDate: json['lastDoneDate'] != null
          ? DateTime.parse(json['lastDoneDate'])
          : null,
      nextDueKm: json['nextDueKm']?.toDouble(),
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.parse(json['nextDueDate'])
          : null,
      status: json['status'] ?? 'active',
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
      'id': id,
      'userId': userId,
      if (vehicleId != null) 'vehicleId': vehicleId,
      'type': type,
      'description': description,
      if (intervalKm != null) 'intervalKm': intervalKm,
      if (intervalMonths != null) 'intervalMonths': intervalMonths,
      if (lastDoneKm != null) 'lastDoneKm': lastDoneKm,
      if (lastDoneDate != null) 'lastDoneDate': lastDoneDate!.toIso8601String(),
      if (nextDueKm != null) 'nextDueKm': nextDueKm,
      if (nextDueDate != null) 'nextDueDate': nextDueDate!.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ReminderNotification {
  final String reminderId;
  final String type;
  final String message;
  final DateTime sentAt;

  ReminderNotification({
    required this.reminderId,
    required this.type,
    required this.message,
    required this.sentAt,
  });

  factory ReminderNotification.fromJson(Map<String, dynamic> json) {
    return ReminderNotification(
      reminderId: json['reminderId'] ?? '',
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reminderId': reminderId,
      'type': type,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
    };
  }
}





