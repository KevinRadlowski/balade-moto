import 'waypoint.dart';

class Ride {
  final String id;
  final String titre;
  final String? description;
  final String typeVehicule;
  final DateTime date;
  final String heure;
  final dynamic lieuDepart;
  final dynamic lieuArrivee;
  final List<Waypoint>? waypoints; // Nouveau système de waypoints
  final double rayon;
  final UserOrganisateur organisateur;
  final String visibilite;
  final List<UserParticipant> participants;
  final List<String> likes;
  final double noteMoyenne;
  final String? url;
  final String? icsUrl;
  final int? totalLikes;
  final bool? hasUserLiked;
  final String status; // Statut de la balade: scheduled, in_progress, completed, cancelled, postponed
  final String? ridingStyle; // Style de conduite: calme, modere, sportif, mixte

  Ride({
    required this.id,
    required this.titre,
    this.description,
    required this.typeVehicule,
    required this.date,
    required this.heure,
    required this.lieuDepart,
    required this.lieuArrivee,
    this.waypoints,
    required this.rayon,
    required this.organisateur,
    required this.visibilite,
    required this.participants,
    required this.likes,
    required this.noteMoyenne,
    this.url,
    this.icsUrl,
    this.totalLikes,
    this.hasUserLiked,
    this.status = 'scheduled',
    this.ridingStyle,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] ?? json['_id'] ?? '',
      titre: json['titre'] ?? '',
      description: json['description'],
      typeVehicule: json['typeVehicule'] ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      heure: json['heure'] ?? '',
      lieuDepart: json['lieuDepart'],
      lieuArrivee: json['lieuArrivee'],
      waypoints: json['waypoints'] != null
          ? (json['waypoints'] as List)
              .map((w) => Waypoint.fromJson(w))
              .toList()
          : null,
      rayon: (json['rayon'] ?? 0).toDouble(),
      organisateur: UserOrganisateur.fromJson(
        json['organisateur'] is Map 
            ? json['organisateur'] 
            : {'_id': json['organisateur']}
      ),
      visibilite: json['visibilite'] ?? 'publique',
      participants: json['participants'] != null
          ? (json['participants'] as List)
              .map((p) => UserParticipant.fromJson(p))
              .toList()
          : [],
      likes: json['likes'] != null 
          ? List<String>.from(json['likes'].map((l) => l.toString()))
          : [],
      noteMoyenne: (json['noteMoyenne'] ?? 0).toDouble(),
      url: json['url'],
      icsUrl: json['icsUrl'],
      totalLikes: json['totalLikes'],
      hasUserLiked: json['hasUserLiked'],
      status: json['status'] ?? 'scheduled',
      ridingStyle: json['ridingStyle'],
    );
  }

  bool get isLikedByCurrentUser => false; // Sera géré par le state
  bool get isParticipant => false; // Sera géré par le state
}

class UserOrganisateur {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? pseudo;
  final String email;

  UserOrganisateur({
    required this.id,
    this.firstName,
    this.lastName,
    this.pseudo,
    required this.email,
  });

  factory UserOrganisateur.fromJson(Map<String, dynamic> json) {
    return UserOrganisateur(
      id: json['id'] ?? json['_id'] ?? '',
      firstName: json['firstName'],
      lastName: json['lastName'],
      pseudo: json['pseudo'],
      email: json['email'] ?? '',
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (pseudo != null) {
      return pseudo!;
    }
    return email;
  }
}

class UserParticipant {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? pseudo;

  UserParticipant({
    required this.id,
    this.firstName,
    this.lastName,
    this.pseudo,
  });

  factory UserParticipant.fromJson(Map<String, dynamic> json) {
    return UserParticipant(
      id: json['id'] ?? json['_id'] ?? '',
      firstName: json['firstName'],
      lastName: json['lastName'],
      pseudo: json['pseudo'],
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (pseudo != null) {
      return pseudo!;
    }
    return 'Utilisateur';
  }
}

