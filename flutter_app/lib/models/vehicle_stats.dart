class VehicleStats {
  final String id;
  final String vehicleId;
  final double totalKm;
  final double totalCost;
  final int rideCount;
  final int maintenanceCount;
  final FuelConsumption? fuelConsumption;
  final List<MonthlyStat> monthlyStats;
  final MaintenancePrediction? nextMaintenance;

  VehicleStats({
    required this.id,
    required this.vehicleId,
    required this.totalKm,
    required this.totalCost,
    required this.rideCount,
    required this.maintenanceCount,
    this.fuelConsumption,
    required this.monthlyStats,
    this.nextMaintenance,
  });

  factory VehicleStats.fromJson(Map<String, dynamic> json) {
    return VehicleStats(
      id: json['_id'] ?? json['id'] ?? '',
      vehicleId: json['vehicleId'] ?? '',
      totalKm: (json['totalKm'] ?? 0.0).toDouble(),
      totalCost: (json['totalCost'] ?? 0.0).toDouble(),
      rideCount: json['rideCount'] ?? 0,
      maintenanceCount: json['maintenanceCount'] ?? 0,
      fuelConsumption: json['fuelConsumption'] != null
          ? FuelConsumption.fromJson(json['fuelConsumption'])
          : null,
      monthlyStats: (json['monthlyStats'] as List<dynamic>?)
              ?.map((m) => MonthlyStat.fromJson(m))
              .toList() ??
          [],
      nextMaintenance: json['nextMaintenance'] != null
          ? MaintenancePrediction.fromJson(json['nextMaintenance'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'totalKm': totalKm,
      'totalCost': totalCost,
      'rideCount': rideCount,
      'maintenanceCount': maintenanceCount,
      if (fuelConsumption != null) 'fuelConsumption': fuelConsumption!.toJson(),
      'monthlyStats': monthlyStats.map((m) => m.toJson()).toList(),
      if (nextMaintenance != null) 'nextMaintenance': nextMaintenance!.toJson(),
    };
  }
}

class FuelConsumption {
  final double averageLitersPer100Km;
  final double? lastLitersPer100Km;

  FuelConsumption({
    required this.averageLitersPer100Km,
    this.lastLitersPer100Km,
  });

  factory FuelConsumption.fromJson(Map<String, dynamic> json) {
    return FuelConsumption(
      averageLitersPer100Km: (json['averageLitersPer100Km'] ?? 0.0).toDouble(),
      lastLitersPer100Km: json['lastLitersPer100Km']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'averageLitersPer100Km': averageLitersPer100Km,
      if (lastLitersPer100Km != null) 'lastLitersPer100Km': lastLitersPer100Km,
    };
  }
}

class MonthlyStat {
  final String month; // Format: "YYYY-MM"
  final double km;
  final double cost;
  final int rides;

  MonthlyStat({
    required this.month,
    required this.km,
    required this.cost,
    required this.rides,
  });

  factory MonthlyStat.fromJson(Map<String, dynamic> json) {
    return MonthlyStat(
      month: json['month'] ?? '',
      km: (json['km'] ?? 0.0).toDouble(),
      cost: (json['cost'] ?? 0.0).toDouble(),
      rides: json['rides'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'km': km,
      'cost': cost,
      'rides': rides,
    };
  }
}

class MaintenancePrediction {
  final String type;
  final DateTime? predictedDate;
  final double? predictedKm;
  final String? reason;

  MaintenancePrediction({
    required this.type,
    this.predictedDate,
    this.predictedKm,
    this.reason,
  });

  factory MaintenancePrediction.fromJson(Map<String, dynamic> json) {
    return MaintenancePrediction(
      type: json['type'] ?? '',
      predictedDate: json['predictedDate'] != null
          ? DateTime.parse(json['predictedDate'])
          : null,
      predictedKm: json['predictedKm']?.toDouble(),
      reason: json['reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (predictedDate != null) 'predictedDate': predictedDate!.toIso8601String(),
      if (predictedKm != null) 'predictedKm': predictedKm,
      if (reason != null) 'reason': reason,
    };
  }
}


