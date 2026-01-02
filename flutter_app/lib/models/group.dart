class Group {
  final String id;
  final String nom;
  final String? description;
  final String visibilite;
  final GroupMember createur;
  final List<GroupMember> membres;
  final List<BannedUser>? bannedUsers;
  // Champs pour l'indicateur d'activité
  final int? unreadCount;
  final DateTime? lastMessageAt;

  Group({
    required this.id,
    required this.nom,
    this.description,
    required this.visibilite,
    required this.createur,
    required this.membres,
    this.bannedUsers,
    this.unreadCount,
    this.lastMessageAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    // Le createur est un User object, on doit extraire l'ID, pseudo et avatarUrl
    final createurId = json['createur']?['id'] ?? 
                       json['createur']?['_id'] ?? 
                       json['createur'] ?? '';
    final createurPseudo = json['createur']?['pseudo'];
    final createurAvatarUrl = json['createur']?['avatarUrl'];
    
    // Gérer unreadCount
    int? unreadCount;
    if (json['unreadCount'] != null) {
      unreadCount = json['unreadCount'] is int 
          ? json['unreadCount'] 
          : int.tryParse(json['unreadCount'].toString());
    }
    
    // Gérer lastMessageAt
    DateTime? lastMessageAt;
    if (json['lastMessageAt'] != null) {
      try {
        if (json['lastMessageAt'] is String) {
          lastMessageAt = DateTime.parse(json['lastMessageAt']);
        } else if (json['lastMessageAt'] is int) {
          lastMessageAt = DateTime.fromMillisecondsSinceEpoch(json['lastMessageAt']);
        }
      } catch (e) {
        // Ignorer les erreurs de parsing
        lastMessageAt = null;
      }
    }
    
    return Group(
      id: json['id'] ?? json['_id'] ?? '',
      nom: json['nom'] ?? '',
      description: json['description'],
      visibilite: json['visibilite'] ?? 'publique',
      createur: GroupMember(
        userId: createurId.toString(),
        pseudo: createurPseudo,
        avatarUrl: createurAvatarUrl,
        role: 'admin', // Le créateur est toujours admin
        dateAjout: DateTime.now(),
      ),
      membres: json['membres'] != null
          ? (json['membres'] as List)
              .map((m) => GroupMember.fromJson(m))
              .toList()
          : [],
      bannedUsers: json['bannedUsers'] != null
          ? (json['bannedUsers'] as List)
              .map((b) => BannedUser.fromJson(b))
              .toList()
          : [],
      unreadCount: unreadCount,
      lastMessageAt: lastMessageAt,
    );
  }
}

class BannedUser {
  final String userId;
  final String? pseudo;
  final String? avatarUrl;
  final String? reason;
  final DateTime bannedAt;

  BannedUser({
    required this.userId,
    this.pseudo,
    this.avatarUrl,
    this.reason,
    required this.bannedAt,
  });

  factory BannedUser.fromJson(Map<String, dynamic> json) {
    String? userPseudo;
    String? userAvatarUrl;
    String userIdStr = '';
    
    // Gérer userId qui peut être un objet User, un ObjectId, ou une string
    try {
      if (json['userId'] != null) {
        if (json['userId'] is Map) {
          // C'est un objet User avec id/_id
          final userIdObj = json['userId'] as Map<String, dynamic>;
          
          // Extraire l'ID de manière sécurisée
          dynamic idValue;
          if (userIdObj.containsKey('id')) {
            idValue = userIdObj['id'];
          } else if (userIdObj.containsKey('_id')) {
            idValue = userIdObj['_id'];
            // Si _id est un Map (ObjectId MongoDB), extraire $oid
            if (idValue is Map && idValue.containsKey('\$oid')) {
              idValue = idValue['\$oid'];
            }
          } else if (userIdObj.containsKey('\$oid')) {
            idValue = userIdObj['\$oid'];
          }
          
          // Convertir l'ID en string de manière sécurisée
          if (idValue != null) {
            if (idValue is String) {
              userIdStr = idValue;
            } else if (idValue is int) {
              userIdStr = idValue.toString();
            } else {
              userIdStr = idValue.toString();
            }
          }
          
          userPseudo = userIdObj['pseudo']?.toString();
          userAvatarUrl = userIdObj['avatarUrl']?.toString();
        } else if (json['userId'] is String) {
          // C'est directement une string
          userIdStr = json['userId'] as String;
        } else {
          // C'est peut-être un ObjectId ou autre, convertir en string
          userIdStr = json['userId'].toString();
        }
      }
    } catch (e) {
      print('Erreur lors du parsing de userId: $e');
      userIdStr = '';
    }
    
    // Gérer bannedAt qui peut être une string ISO, un int (timestamp), ou un objet Date
    DateTime bannedAtDate = DateTime.now();
    if (json['bannedAt'] != null) {
      try {
        if (json['bannedAt'] is String) {
          bannedAtDate = DateTime.parse(json['bannedAt'] as String);
        } else if (json['bannedAt'] is int) {
          // C'est un timestamp en millisecondes
          bannedAtDate = DateTime.fromMillisecondsSinceEpoch(json['bannedAt'] as int);
        } else if (json['bannedAt'] is Map) {
          // Format MongoDB avec $date
          final bannedAtMap = json['bannedAt'] as Map<String, dynamic>;
          if (bannedAtMap.containsKey('\$date')) {
            final dateValue = bannedAtMap['\$date'];
            if (dateValue is int) {
              bannedAtDate = DateTime.fromMillisecondsSinceEpoch(dateValue);
            } else if (dateValue is String) {
              bannedAtDate = DateTime.parse(dateValue);
            } else if (dateValue is num) {
              // Gérer les num (int ou double)
              bannedAtDate = DateTime.fromMillisecondsSinceEpoch(dateValue.toInt());
            }
          }
        }
      } catch (e) {
        // En cas d'erreur, utiliser la date actuelle
        print('Erreur lors du parsing de bannedAt: $e');
        bannedAtDate = DateTime.now();
      }
    }
    
    return BannedUser(
      userId: userIdStr,
      pseudo: userPseudo,
      avatarUrl: userAvatarUrl,
      reason: json['reason']?.toString(),
      bannedAt: bannedAtDate,
    );
  }
}

class GroupMember {
  final String userId;
  final String? pseudo; // Pseudo de l'utilisateur
  final String? avatarUrl; // URL de l'avatar de l'utilisateur
  final String role;
  final DateTime dateAjout;

  GroupMember({
    required this.userId,
    this.pseudo,
    this.avatarUrl,
    required this.role,
    required this.dateAjout,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    // Extraire le pseudo et l'avatarUrl depuis l'objet userId si c'est un objet User
    String? userPseudo;
    String? userAvatarUrl;
    if (json['userId'] is Map) {
      userPseudo = json['userId']['pseudo'];
      userAvatarUrl = json['userId']['avatarUrl'];
    }
    
    return GroupMember(
      userId: json['userId']?['id'] ?? json['userId']?['_id'] ?? json['userId']?.toString() ?? '',
      pseudo: userPseudo,
      avatarUrl: userAvatarUrl,
      role: json['role'] ?? 'membre',
      dateAjout: json['dateAjout'] != null
          ? DateTime.parse(json['dateAjout'])
          : DateTime.now(),
    );
  }
}

