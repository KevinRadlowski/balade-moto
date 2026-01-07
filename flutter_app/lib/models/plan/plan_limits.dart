class PlanLimits {
  final bool unlimited;
  final int? maxVehiclesTotal;
  final Map<String, int>? maxVehiclesByType;
  final int? maxPhotosTotal;
  final int? maxPrivateGroupsCreated;
  final int? maxPrivateRidesCreatedPerMonth;

  PlanLimits({
    required this.unlimited,
    this.maxVehiclesTotal,
    this.maxVehiclesByType,
    this.maxPhotosTotal,
    this.maxPrivateGroupsCreated,
    this.maxPrivateRidesCreatedPerMonth,
  });

  factory PlanLimits.fromJson(Map<String, dynamic> json) {
    // Si unlimited est true, toutes les limites sont null
    if (json['unlimited'] == true) {
      return PlanLimits(unlimited: true);
    }

    // Parser maxVehiclesByType (Map<String, int>)
    Map<String, int>? vehiclesByType;
    if (json['maxVehiclesByType'] != null) {
      final byTypeJson = json['maxVehiclesByType'] as Map<String, dynamic>;
      vehiclesByType = byTypeJson.map((key, value) => MapEntry(key, value as int));
    }

    return PlanLimits(
      unlimited: false,
      maxVehiclesTotal: json['maxVehiclesTotal'] as int?,
      maxVehiclesByType: vehiclesByType,
      maxPhotosTotal: json['maxPhotosTotal'] as int?,
      maxPrivateGroupsCreated: json['maxPrivateGroupsCreated'] as int?,
      maxPrivateRidesCreatedPerMonth: json['maxPrivateRidesCreatedPerMonth'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    if (unlimited) {
      return {'unlimited': true};
    }

    return {
      'unlimited': false,
      if (maxVehiclesTotal != null) 'maxVehiclesTotal': maxVehiclesTotal,
      if (maxVehiclesByType != null) 'maxVehiclesByType': maxVehiclesByType,
      if (maxPhotosTotal != null) 'maxPhotosTotal': maxPhotosTotal,
      if (maxPrivateGroupsCreated != null) 'maxPrivateGroupsCreated': maxPrivateGroupsCreated,
      if (maxPrivateRidesCreatedPerMonth != null) 'maxPrivateRidesCreatedPerMonth': maxPrivateRidesCreatedPerMonth,
    };
  }

  // Getters de compatibilité pour faciliter l'accès
  int? get vehiclesMoto => maxVehiclesByType?['moto'];
  int? get vehiclesVoiture => maxVehiclesByType?['voiture'];
}

