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
  final String? secretLink; // Lien secret pour les balades secrètes
  final List<UserParticipant> participants;
  final List<RideInvitation>? invitations;
  final List<String> likes;
  final double noteMoyenne;
  final String? url;
  final String? icsUrl;
  final int? totalLikes;
  final bool? hasUserLiked;
  final bool? isOrganizerPremium; // Indique si l'organisateur est premium
  final String status; // Statut de la balade: scheduled, in_progress, completed, cancelled, postponed
  final String? ridingStyle; // Style de conduite: calme, modere, sportif, mixte

  // ========== OUTILS ORGANISATEUR ==========
  final bool requiresApproval; // Validation manuelle des participants
  final List<PendingRequest>? pendingRequests; // Demandes en attente
  final int? maxParticipants; // Limite de participants
  final bool enableWaitlist; // Liste d'attente activée
  final List<WaitlistEntry>? waitlist; // Liste d'attente
  final AutoReminder? autoReminder; // Message automatique avant la balade
  final RideRecurrence? recurrence; // Balades récurrentes

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
    this.secretLink,
    required this.participants,
    this.invitations,
    required this.likes,
    required this.noteMoyenne,
    this.url,
    this.icsUrl,
    this.totalLikes,
    this.hasUserLiked,
    this.isOrganizerPremium,
    this.status = 'scheduled',
    this.ridingStyle,
    this.requiresApproval = false,
    this.pendingRequests,
    this.maxParticipants,
    this.enableWaitlist = false,
    this.waitlist,
    this.autoReminder,
    this.recurrence,
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
      secretLink: json['secretLink'],
      participants: json['participants'] != null
          ? (json['participants'] as List)
              .map((p) {
                // Gérer la nouvelle structure avec userId comme sous-document
                if (p is Map && p.containsKey('userId')) {
                  // Si userId est un objet (populé), utiliser ses données
                  final userId = p['userId'];
                  if (userId is Map) {
                    return UserParticipant.fromJson({
                      'id': userId['_id'] ?? userId['id'] ?? '',
                      'firstName': userId['firstName'],
                      'lastName': userId['lastName'],
                      'pseudo': userId['pseudo'],
                    });
                  } else {
                    // Si userId est juste un ID, utiliser l'ID
                    return UserParticipant.fromJson({
                      'id': userId.toString(),
                    });
                  }
                }
                // Ancienne structure (participant direct)
                return UserParticipant.fromJson(p);
              })
              .toList()
          : [],
      invitations: json['invitations'] != null
          ? (json['invitations'] as List)
              .map((inv) => RideInvitation.fromJson(inv))
              .toList()
          : null,
      likes: json['likes'] != null 
          ? List<String>.from(json['likes'].map((l) => l.toString()))
          : [],
      noteMoyenne: (json['noteMoyenne'] ?? 0).toDouble(),
      url: json['url'],
      icsUrl: json['icsUrl'],
      totalLikes: json['totalLikes'],
      hasUserLiked: json['hasUserLiked'],
      isOrganizerPremium: json['isOrganizerPremium'] ?? false,
      status: json['status'] ?? 'scheduled',
      ridingStyle: json['ridingStyle'],
      // Outils organisateur
      requiresApproval: json['requiresApproval'] ?? false,
      pendingRequests: json['pendingRequests'] != null
          ? (json['pendingRequests'] as List)
              .map((r) => PendingRequest.fromJson(r))
              .toList()
          : null,
      maxParticipants: json['maxParticipants'],
      enableWaitlist: json['enableWaitlist'] ?? false,
      waitlist: json['waitlist'] != null
          ? (json['waitlist'] as List)
              .map((w) => WaitlistEntry.fromJson(w))
              .toList()
          : null,
      autoReminder: json['autoReminder'] != null
          ? AutoReminder.fromJson(json['autoReminder'])
          : null,
      recurrence: json['recurrence'] != null
          ? RideRecurrence.fromJson(json['recurrence'])
          : null,
    );
  }

  bool get isLikedByCurrentUser => false; // Sera géré par le state
  bool get isParticipant => false; // Sera géré par le state
  
  // Helpers pour les outils organisateur
  bool get hasOrganizerTools => requiresApproval || maxParticipants != null || 
      enableWaitlist || (autoReminder?.enabled ?? false) || (recurrence?.enabled ?? false);
  
  int get pendingRequestsCount => pendingRequests?.length ?? 0;
  int get waitlistCount => waitlist?.length ?? 0;
  bool get isFull => maxParticipants != null && participants.length >= maxParticipants!;
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

class RideInvitation {
  final String userId;
  final String? firstName;
  final String? lastName;
  final String? pseudo;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime? invitedAt;
  final DateTime? respondedAt;

  RideInvitation({
    required this.userId,
    this.firstName,
    this.lastName,
    this.pseudo,
    required this.status,
    this.invitedAt,
    this.respondedAt,
  });

  factory RideInvitation.fromJson(Map<String, dynamic> json) {
    // Gérer le cas où userId est un objet (populé)
    String userIdStr;
    String? firstName;
    String? lastName;
    String? pseudo;

    if (json['userId'] is Map) {
      final user = json['userId'];
      userIdStr = user['_id'] ?? user['id'] ?? '';
      firstName = user['firstName'];
      lastName = user['lastName'];
      pseudo = user['pseudo'];
    } else {
      userIdStr = json['userId']?.toString() ?? '';
    }

    return RideInvitation(
      userId: userIdStr,
      firstName: firstName ?? json['firstName'],
      lastName: lastName ?? json['lastName'],
      pseudo: pseudo ?? json['pseudo'],
      status: json['status'] ?? 'pending',
      invitedAt: json['invitedAt'] != null ? DateTime.parse(json['invitedAt']) : null,
      respondedAt: json['respondedAt'] != null ? DateTime.parse(json['respondedAt']) : null,
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

// ========== CLASSES POUR LES OUTILS ORGANISATEUR ==========

/// Demande de participation en attente d'approbation
class PendingRequest {
  final String userId;
  final String? firstName;
  final String? lastName;
  final String? pseudo;
  final String? avatarUrl;
  final String? vehicleId;
  final String? vehicleNickname;
  final DateTime requestedAt;
  final String? message;

  PendingRequest({
    required this.userId,
    this.firstName,
    this.lastName,
    this.pseudo,
    this.avatarUrl,
    this.vehicleId,
    this.vehicleNickname,
    required this.requestedAt,
    this.message,
  });

  factory PendingRequest.fromJson(Map<String, dynamic> json) {
    String parsedUserId;
    String? parsedFirstName;
    String? parsedLastName;
    String? parsedPseudo;
    String? parsedAvatarUrl;

    if (json['userId'] is Map) {
      final user = json['userId'];
      parsedUserId = user['_id'] ?? user['id'] ?? '';
      parsedFirstName = user['firstName'];
      parsedLastName = user['lastName'];
      parsedPseudo = user['pseudo'];
      parsedAvatarUrl = user['avatarUrl'];
    } else {
      parsedUserId = json['userId']?.toString() ?? '';
    }

    String? parsedVehicleId;
    String? parsedVehicleNickname;
    if (json['vehicleId'] is Map) {
      final vehicle = json['vehicleId'];
      parsedVehicleId = vehicle['_id'] ?? vehicle['id'];
      parsedVehicleNickname = vehicle['nickname'] ?? '${vehicle['make']} ${vehicle['model']}';
    } else {
      parsedVehicleId = json['vehicleId']?.toString();
    }

    return PendingRequest(
      userId: parsedUserId,
      firstName: parsedFirstName,
      lastName: parsedLastName,
      pseudo: parsedPseudo,
      avatarUrl: parsedAvatarUrl,
      vehicleId: parsedVehicleId,
      vehicleNickname: parsedVehicleNickname,
      requestedAt: json['requestedAt'] != null 
          ? DateTime.parse(json['requestedAt']) 
          : DateTime.now(),
      message: json['message'],
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

/// Entrée dans la liste d'attente
class WaitlistEntry {
  final String userId;
  final String? firstName;
  final String? lastName;
  final String? pseudo;
  final String? avatarUrl;
  final String? vehicleId;
  final String? vehicleNickname;
  final DateTime addedAt;
  final int position;

  WaitlistEntry({
    required this.userId,
    this.firstName,
    this.lastName,
    this.pseudo,
    this.avatarUrl,
    this.vehicleId,
    this.vehicleNickname,
    required this.addedAt,
    required this.position,
  });

  factory WaitlistEntry.fromJson(Map<String, dynamic> json) {
    String userId;
    String? firstName;
    String? lastName;
    String? pseudo;
    String? avatarUrl;

    if (json['userId'] is Map) {
      final user = json['userId'];
      userId = user['_id'] ?? user['id'] ?? '';
      firstName = user['firstName'];
      lastName = user['lastName'];
      pseudo = user['pseudo'];
      avatarUrl = user['avatarUrl'];
    } else {
      userId = json['userId']?.toString() ?? '';
    }

    String? vehicleId;
    String? vehicleNickname;
    if (json['vehicleId'] is Map) {
      final vehicle = json['vehicleId'];
      vehicleId = vehicle['_id'] ?? vehicle['id'];
      vehicleNickname = vehicle['nickname'] ?? '${vehicle['make']} ${vehicle['model']}';
    } else {
      vehicleId = json['vehicleId']?.toString();
    }

    return WaitlistEntry(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      pseudo: pseudo,
      avatarUrl: avatarUrl,
      vehicleId: vehicleId,
      vehicleNickname: vehicleNickname,
      addedAt: json['addedAt'] != null 
          ? DateTime.parse(json['addedAt']) 
          : DateTime.now(),
      position: json['position'] ?? 0,
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

/// Configuration du rappel automatique
class AutoReminder {
  final bool enabled;
  final int hoursBefore;
  final String? message;
  final DateTime? sentAt;

  AutoReminder({
    required this.enabled,
    required this.hoursBefore,
    this.message,
    this.sentAt,
  });

  factory AutoReminder.fromJson(Map<String, dynamic> json) {
    return AutoReminder(
      enabled: json['enabled'] ?? false,
      hoursBefore: json['hoursBefore'] ?? 24,
      message: json['message'],
      sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'hoursBefore': hoursBefore,
      'message': message,
    };
  }
}

/// Configuration de la récurrence
class RideRecurrence {
  final bool enabled;
  final String frequency; // 'weekly', 'biweekly', 'monthly'
  final int? dayOfWeek; // 0 = dimanche, 1 = lundi, ..., 6 = samedi
  final DateTime? endDate;
  final String? parentRideId;
  final DateTime? nextOccurrence;

  RideRecurrence({
    required this.enabled,
    required this.frequency,
    this.dayOfWeek,
    this.endDate,
    this.parentRideId,
    this.nextOccurrence,
  });

  factory RideRecurrence.fromJson(Map<String, dynamic> json) {
    return RideRecurrence(
      enabled: json['enabled'] ?? false,
      frequency: json['frequency'] ?? 'weekly',
      dayOfWeek: json['dayOfWeek'],
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      parentRideId: json['parentRideId']?.toString(),
      nextOccurrence: json['nextOccurrence'] != null 
          ? DateTime.parse(json['nextOccurrence']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'frequency': frequency,
      'dayOfWeek': dayOfWeek,
      'endDate': endDate?.toIso8601String(),
    };
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'weekly':
        return 'Hebdomadaire';
      case 'biweekly':
        return 'Toutes les 2 semaines';
      case 'monthly':
        return 'Mensuelle';
      default:
        return frequency;
    }
  }

  String get dayOfWeekLabel {
    if (dayOfWeek == null) return '';
    const days = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    return days[dayOfWeek!];
  }
}

