class Waypoint {
  final String type; // 'depart', 'checkpoint', 'arrivee'
  final String address;
  final double latitude;
  final double longitude;
  final int order;

  Waypoint({
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.order,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'address': address,
      'coordinates': {
        'type': 'Point',
        'coordinates': [longitude, latitude] // [longitude, latitude] pour GeoJSON
      },
      'order': order,
    };
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
      type: json['type'] ?? 'checkpoint',
      address: json['address'] ?? '',
      latitude: lat,
      longitude: lng,
      order: json['order'] ?? 0,
    );
  }
}

