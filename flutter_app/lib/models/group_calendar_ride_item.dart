/// Modèle pour un élément de balade dans le calendrier de groupe
class GroupCalendarRideItem {
  final String rideId;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final String departureName;
  final String arrivalName;
  final GroupCalendarOrganizer organizer;
  final String visibility;

  GroupCalendarRideItem({
    required this.rideId,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.departureName,
    required this.arrivalName,
    required this.organizer,
    required this.visibility,
  });

  factory GroupCalendarRideItem.fromJson(Map<String, dynamic> json) {
    return GroupCalendarRideItem(
      rideId: json['rideId'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
      startAt: DateTime.parse(json['startAt']),
      endAt: DateTime.parse(json['endAt']),
      status: json['status'] ?? 'scheduled',
      departureName: json['departureName'] ?? 'Départ',
      arrivalName: json['arrivalName'] ?? 'Arrivée',
      organizer: GroupCalendarOrganizer.fromJson(json['organizer'] ?? {}),
      visibility: json['visibility'] ?? 'publique',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rideId': rideId,
      'title': title,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'status': status,
      'departureName': departureName,
      'arrivalName': arrivalName,
      'organizer': organizer.toJson(),
      'visibility': visibility,
    };
  }
}

class GroupCalendarOrganizer {
  final String id;
  final String pseudo;

  GroupCalendarOrganizer({
    required this.id,
    required this.pseudo,
  });

  factory GroupCalendarOrganizer.fromJson(Map<String, dynamic> json) {
    return GroupCalendarOrganizer(
      id: json['id'] ?? json['_id'] ?? '',
      pseudo: json['pseudo'] ?? 'Organisateur',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pseudo': pseudo,
    };
  }
}

