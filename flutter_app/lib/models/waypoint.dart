class Waypoint {
  final String? id; // _id du waypoint (pour modifications)
  final String type; // 'depart', 'checkpoint', 'arrivee'
  final String address;
  final double latitude;
  final double longitude;
  final int order;
  // NOUVEAUX CHAMPS
  final String waypointType; // 'normal', 'fuel', 'coffee', 'danger', 'viewpoint'
  final bool isMandatoryStop;
  final String? note;
  final String? createdBy;
  final DateTime? createdAt;

  Waypoint({
    this.id,
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.order,
    this.waypointType = 'normal',
    this.isMandatoryStop = false,
    this.note,
    this.createdBy,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'type': type,
      'address': address,
      'coordinates': {
        'type': 'Point',
        'coordinates': [longitude, latitude] // [longitude, latitude] pour GeoJSON
      },
      'order': order,
      'waypointType': waypointType,
      'isMandatoryStop': isMandatoryStop,
    };
    
    if (id != null) {
      json['_id'] = id as Object;
    }
    if (note != null && note!.isNotEmpty) {
      json['note'] = note as Object;
    }
    if (createdBy != null) {
      json['createdBy'] = createdBy as Object;
    }
    
    return json;
  }

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    double lat = 0.0;
    double lng = 0.0;

    // Essayer d'abord latitude/longitude directement (format simple)
    if (json['latitude'] != null && json['longitude'] != null) {
      lat = json['latitude'].toDouble();
      lng = json['longitude'].toDouble();
    } else if (json['coordinates'] != null) {
      // Format GeoJSON du backend: coordinates.coordinates = [longitude, latitude]
      if (json['coordinates'] is Map && json['coordinates']['coordinates'] != null) {
        final coords = json['coordinates']['coordinates'] as List;
        if (coords.length >= 2) {
          lng = coords[0].toDouble(); // Longitude en premier
          lat = coords[1].toDouble(); // Latitude en second
        }
      } else if (json['coordinates'] is List) {
        // Format direct: [longitude, latitude]
        final coords = json['coordinates'] as List;
        if (coords.length >= 2) {
          lng = coords[0].toDouble();
          lat = coords[1].toDouble();
        }
      }
    }

    return Waypoint(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      type: json['type'] ?? 'checkpoint',
      address: json['address'] ?? '',
      latitude: lat,
      longitude: lng,
      order: json['order'] ?? 0,
      waypointType: json['waypointType'] ?? 'normal',
      isMandatoryStop: json['isMandatoryStop'] ?? false,
      note: json['note'],
      createdBy: json['createdBy']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  // Helper pour obtenir l'icône selon le type
  String getIcon() {
    switch (waypointType) {
      case 'fuel':
        return '⛽';
      case 'coffee':
        return '☕';
      case 'danger':
        return '⚠️';
      case 'viewpoint':
        return '🏔️';
      default:
        return '📍';
    }
  }

  // Helper pour obtenir le nom du type
  String getTypeName() {
    switch (waypointType) {
      case 'fuel':
        return 'Pause carburant';
      case 'coffee':
        return 'Pause café';
      case 'danger':
        return 'Danger';
      case 'viewpoint':
        return 'Point de vue';
      default:
        return 'Point de passage';
    }
  }
}

