class PlanUsage {
  final int vehiclesTotal;
  final Map<String, int> vehiclesByType;
  final int photosTotal;
  final int privateGroupsCreated;
  final int privateRidesCreatedThisMonth;

  PlanUsage({
    required this.vehiclesTotal,
    required this.vehiclesByType,
    required this.photosTotal,
    required this.privateGroupsCreated,
    required this.privateRidesCreatedThisMonth,
  });

  factory PlanUsage.fromJson(Map<String, dynamic> json) {
    return PlanUsage(
      vehiclesTotal: (json['vehiclesTotal'] as num?)?.toInt() ?? 0,
      vehiclesByType: (json['vehiclesByType'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(
                    key,
                    (value as num?)?.toInt() ?? 0,
                  )) ??
          {'moto': 0, 'voiture': 0},
      photosTotal: (json['photosTotal'] as num?)?.toInt() ?? 0,
      privateGroupsCreated: (json['privateGroupsCreated'] as num?)?.toInt() ?? 0,
      privateRidesCreatedThisMonth:
          (json['privateRidesCreatedThisMonth'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehiclesTotal': vehiclesTotal,
      'vehiclesByType': vehiclesByType,
      'photosTotal': photosTotal,
      'privateGroupsCreated': privateGroupsCreated,
      'privateRidesCreatedThisMonth': privateRidesCreatedThisMonth,
    };
  }

  /// Récupère le nombre de véhicules d'un type donné
  int getVehiclesByType(String type) {
    return vehiclesByType[type] ?? 0;
  }
}


