class CheckInStatus {
  final String id;
  final String userId;
  final DateTime? lastCheckIn;
  final CheckInLocation? lastLocation;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CheckInStatus({
    required this.id,
    required this.userId,
    this.lastCheckIn,
    this.lastLocation,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
    return CheckInStatus(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      lastCheckIn: json['lastCheckIn'] != null
          ? DateTime.parse(json['lastCheckIn'])
          : null,
      lastLocation: json['lastLocation'] != null
          ? CheckInLocation.fromJson(json['lastLocation'])
          : null,
      isActive: json['isActive'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      if (lastCheckIn != null) 'lastCheckIn': lastCheckIn!.toIso8601String(),
      if (lastLocation != null) 'lastLocation': lastLocation!.toJson(),
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}

class CheckInLocation {
  final double latitude;
  final double longitude;
  final String? address;

  CheckInLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory CheckInLocation.fromJson(Map<String, dynamic> json) {
    return CheckInLocation(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
    };
  }
}




