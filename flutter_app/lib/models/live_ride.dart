import 'user.dart';

class LiveRideState {
  final RideInfo ride;
  final List<ParticipantPosition> participantPositions;
  final RideEvent? lastEvent;

  LiveRideState({
    required this.ride,
    required this.participantPositions,
    this.lastEvent,
  });

  factory LiveRideState.fromJson(Map<String, dynamic> json) {
    return LiveRideState(
      ride: RideInfo.fromJson(json['ride'] ?? {}),
      participantPositions: json['participantPositions'] != null
          ? (json['participantPositions'] as List)
              .map((p) => ParticipantPosition.fromJson(p))
              .toList()
          : [],
      lastEvent: json['lastEvent'] != null
          ? RideEvent.fromJson(json['lastEvent'])
          : null,
    );
  }
}

class RideInfo {
  final String id;
  final String titre;
  final String status;
  final User? organisateur;
  final List<User> participants;

  RideInfo({
    required this.id,
    required this.titre,
    required this.status,
    this.organisateur,
    required this.participants,
  });

  factory RideInfo.fromJson(Map<String, dynamic> json) {
    // Gérer le cas où organisateur est un string (ID) ou un objet
    User? organisateur;
    if (json['organisateur'] != null) {
      if (json['organisateur'] is Map<String, dynamic>) {
        organisateur = User.fromJson(json['organisateur']);
      } else {
        // Si c'est un string (ID), créer un User minimal
        organisateur = User(
          id: json['organisateur'].toString(),
          email: '',
          role: 'MEMBER',
          roles: ['MEMBER'],
          emailVerified: false,
          isTwoFactorEnabled: false,
        );
      }
    }
    
    // Gérer le cas où participants est une liste de strings (IDs) ou d'objets
    List<User> participants = [];
    if (json['participants'] != null) {
      final participantsList = json['participants'] as List;
      participants = participantsList.map((p) {
        if (p is Map<String, dynamic>) {
          return User.fromJson(p);
        } else {
          // Si c'est un string (ID), créer un User minimal
          return User(
            id: p.toString(),
            email: '',
            role: 'MEMBER',
            roles: ['MEMBER'],
            emailVerified: false,
            isTwoFactorEnabled: false,
          );
        }
      }).toList();
    }
    
    return RideInfo(
      id: json['_id'] ?? json['id'] ?? '',
      titre: json['titre'] ?? '',
      status: json['status'] ?? 'scheduled',
      organisateur: organisateur,
      participants: participants,
    );
  }
}

class ParticipantPosition {
  final String userId;
  final LiveRideLocation? location;
  final DateTime lastUpdate;

  ParticipantPosition({
    required this.userId,
    this.location,
    required this.lastUpdate,
  });

  factory ParticipantPosition.fromJson(Map<String, dynamic> json) {
    return ParticipantPosition(
      userId: json['userId']?.toString() ?? '',
      location: json['location'] != null
          ? LiveRideLocation.fromJson(json['location'])
          : null,
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'])
          : DateTime.now(),
    );
  }
}

class LiveRideLocation {
  final String type;
  final List<double> coordinates; // [longitude, latitude]

  LiveRideLocation({
    required this.type,
    required this.coordinates,
  });

  factory LiveRideLocation.fromJson(Map<String, dynamic> json) {
    return LiveRideLocation(
      type: json['type'] ?? 'Point',
      coordinates: json['coordinates'] != null
          ? List<double>.from(json['coordinates'].map((c) => c.toDouble()))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
    };
  }

  // Helpers pour faciliter l'utilisation
  double get longitude => coordinates.isNotEmpty ? coordinates[0] : 0.0;
  double get latitude => coordinates.length > 1 ? coordinates[1] : 0.0;
}

class RideEvent {
  final String type;
  final String? userId;
  final LiveRideLocation? location;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  RideEvent({
    required this.type,
    this.userId,
    this.location,
    this.metadata,
    required this.timestamp,
  });

  factory RideEvent.fromJson(Map<String, dynamic> json) {
    return RideEvent(
      type: json['type'] ?? '',
      userId: json['userId']?.toString(),
      location: json['location'] != null
          ? LiveRideLocation.fromJson(json['location'])
          : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

