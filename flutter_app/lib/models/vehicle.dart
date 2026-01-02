class Vehicle {
  final String id;
  final String type; // 'moto' ou 'voiture'
  final String? nickname;
  final String? make;
  final String? model;
  final String? trim;
  final int? year;
  final VehicleEngine? engine;
  final int odometerCurrentKm;
  final VehiclePurchase? purchase;
  final VehicleInsurance? insurance;
  final String? notes;
  final String? photoUrl; // Ancien champ (déprécié)
  final List<VehiclePhoto>? photos; // Nouveau champ : galerie de photos
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehicle({
    required this.id,
    required this.type,
    this.nickname,
    this.make,
    this.model,
    this.trim,
    this.year,
    this.engine,
    required this.odometerCurrentKm,
    this.purchase,
    this.insurance,
    this.notes,
    this.photoUrl,
    this.photos,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? '',
      nickname: json['nickname'],
      make: json['make'],
      model: json['model'],
      trim: json['trim'],
      year: json['year'],
      engine: json['engine'] != null ? VehicleEngine.fromJson(json['engine']) : null,
      odometerCurrentKm: json['odometerCurrentKm'] ?? 0,
      purchase: json['purchase'] != null ? VehiclePurchase.fromJson(json['purchase']) : null,
      insurance: json['insurance'] != null ? VehicleInsurance.fromJson(json['insurance']) : null,
      notes: json['notes'],
      photoUrl: json['photoUrl'],
      photos: json['photos'] != null 
          ? (json['photos'] as List).map((p) => VehiclePhoto.fromJson(p)).toList()
          : null,
      active: json['active'] ?? true,
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
      if (nickname != null) 'nickname': nickname,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (trim != null) 'trim': trim,
      if (year != null) 'year': year,
      if (engine != null) 'engine': engine!.toJson(),
      'odometerCurrentKm': odometerCurrentKm,
      if (purchase != null) 'purchase': purchase!.toJson(),
      if (insurance != null) 'insurance': insurance!.toJson(),
      if (notes != null) 'notes': notes,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (photos != null) 'photos': photos!.map((p) => p.toJson()).toList(),
    };
  }

  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) {
      return nickname!;
    }
    final parts = <String>[];
    if (make != null && make!.isNotEmpty) parts.add(make!);
    if (model != null && model!.isNotEmpty) parts.add(model!);
    if (year != null) parts.add(year.toString());
    return parts.isEmpty ? 'Véhicule sans nom' : parts.join(' ');
  }
}

class VehicleEngine {
  final String? fuel;
  final int? displacementCc;
  final int? powerHp;
  final int? powerKw;
  final String? transmission;

  VehicleEngine({
    this.fuel,
    this.displacementCc,
    this.powerHp,
    this.powerKw,
    this.transmission,
  });

  factory VehicleEngine.fromJson(Map<String, dynamic> json) {
    return VehicleEngine(
      fuel: json['fuel'],
      displacementCc: json['displacementCc'],
      powerHp: json['powerHp'],
      powerKw: json['powerKw'],
      transmission: json['transmission'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (fuel != null) 'fuel': fuel,
      if (displacementCc != null) 'displacementCc': displacementCc,
      if (powerHp != null) 'powerHp': powerHp,
      if (powerKw != null) 'powerKw': powerKw,
      if (transmission != null) 'transmission': transmission,
    };
  }
}

class VehiclePurchase {
  final DateTime? date;
  final double? price;
  final String? sellerType;

  VehiclePurchase({
    this.date,
    this.price,
    this.sellerType,
  });

  factory VehiclePurchase.fromJson(Map<String, dynamic> json) {
    return VehiclePurchase(
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      price: json['price']?.toDouble(),
      sellerType: json['sellerType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (date != null) 'date': date!.toIso8601String(),
      if (price != null) 'price': price,
      if (sellerType != null) 'sellerType': sellerType,
    };
  }
}

class VehicleInsurance {
  final String? company;
  final String? policyNumber;
  final DateTime? renewalDate;

  VehicleInsurance({
    this.company,
    this.policyNumber,
    this.renewalDate,
  });

  factory VehicleInsurance.fromJson(Map<String, dynamic> json) {
    return VehicleInsurance(
      company: json['company'],
      policyNumber: json['policyNumber'],
      renewalDate: json['renewalDate'] != null ? DateTime.parse(json['renewalDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (company != null) 'company': company,
      if (policyNumber != null) 'policyNumber': policyNumber,
      if (renewalDate != null) 'renewalDate': renewalDate!.toIso8601String(),
    };
  }
}

class VehiclePhoto {
  final String url;
  final DateTime uploadedAt;
  final int order;

  VehiclePhoto({
    required this.url,
    required this.uploadedAt,
    required this.order,
  });

  factory VehiclePhoto.fromJson(Map<String, dynamic> json) {
    return VehiclePhoto(
      url: json['url'] ?? '',
      uploadedAt: json['uploadedAt'] != null 
          ? DateTime.parse(json['uploadedAt']) 
          : DateTime.now(),
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'uploadedAt': uploadedAt.toIso8601String(),
      'order': order,
    };
  }
}

