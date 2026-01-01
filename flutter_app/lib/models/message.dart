class Message {
  final String id;
  final String auteur;
  final String? auteurPseudo; // Pseudo de l'auteur
  final String contenu;
  final DateTime date;
  final String? idBalade;
  final String? idGroupe;

  Message({
    required this.id,
    required this.auteur,
    this.auteurPseudo,
    required this.contenu,
    required this.date,
    this.idBalade,
    this.idGroupe,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Gérer l'auteur (peut être un ID string ou un objet User)
    String auteurId = '';
    String? auteurPseudo;
    if (json['auteur'] != null) {
      if (json['auteur'] is String) {
        auteurId = json['auteur'];
      } else if (json['auteur'] is Map) {
        auteurId = json['auteur']['id'] ?? json['auteur']['_id'] ?? '';
        auteurPseudo = json['auteur']['pseudo'] ?? json['auteur']['email'];
      }
    }

    // Gérer la date (peut être une string ISO ou un objet Date)
    DateTime messageDate = DateTime.now();
    if (json['date'] != null) {
      if (json['date'] is String) {
        messageDate = DateTime.parse(json['date']);
      } else if (json['date'] is DateTime) {
        messageDate = json['date'];
      }
    }

    return Message(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      auteur: auteurId,
      auteurPseudo: auteurPseudo,
      contenu: json['contenu'] ?? '',
      date: messageDate,
      idBalade: json['idBalade']?.toString() ?? 
                (json['idBalade'] is Map ? (json['idBalade']['id'] ?? json['idBalade']['_id'])?.toString() : null),
      idGroupe: json['idGroupe']?.toString() ?? 
                (json['idGroupe'] is Map ? (json['idGroupe']['id'] ?? json['idGroupe']['_id'])?.toString() : null),
    );
  }
}

