import '../config/api_config.dart';

class MessageExtended {
  final String id;
  final String auteurId;
  final String? auteurPseudo;
  final String? auteurEmail;
  final String? senderAvatarUrl;
  final String contenu;
  final DateTime date;
  final DateTime? updatedAt;
  final String? idBalade;
  final String? idGroupe;
  final MessageType type;
  final MessageMetadata? metadata;
  final bool edited;
  final bool deletedForAll;
  final List<String> deletedForUserIds;
  final String? replyToMessageId;
  final ReplyPreview? replyPreview;
  final List<Reaction> reactions;
  final List<String> mentions;
  final MessageStatus status; // sending, sent, delivered, read
  final bool pinned;
  final DateTime? pinnedAt;
  final String? pinnedById;
  final String? pinnedByPseudo;
  final PollData? pollData;
  final String? proposedRideId;

  MessageExtended({
    required this.id,
    required this.auteurId,
    this.auteurPseudo,
    this.auteurEmail,
    this.senderAvatarUrl,
    required this.contenu,
    required this.date,
    this.updatedAt,
    this.idBalade,
    this.idGroupe,
    this.type = MessageType.text,
    this.metadata,
    this.edited = false,
    this.deletedForAll = false,
    this.deletedForUserIds = const [],
    this.replyToMessageId,
    this.replyPreview,
    this.reactions = const [],
    this.mentions = const [],
    this.status = MessageStatus.sent,
    this.pinned = false,
    this.pinnedAt,
    this.pinnedById,
    this.pinnedByPseudo,
    this.pollData,
    this.proposedRideId,
  });

  factory MessageExtended.fromJson(Map<String, dynamic> json) {
    // Gérer l'auteur (peut être un ID string ou un objet User)
    String auteurId = '';
    String? auteurPseudo;
    String? auteurEmail;
    
    String? senderAvatarUrl;
    
    if (json['auteur'] != null) {
      if (json['auteur'] is String) {
        auteurId = json['auteur'];
      } else if (json['auteur'] is Map) {
        auteurId = json['auteur']['id'] ?? json['auteur']['_id'] ?? '';
        auteurPseudo = json['auteur']['pseudo'];
        auteurEmail = json['auteur']['email'];
        final avatarUrl = json['auteur']['avatarUrl'];
        // Construire l'URL complète si c'est un chemin relatif
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          if (avatarUrl.startsWith('http')) {
            senderAvatarUrl = avatarUrl;
          } else if (avatarUrl.startsWith('/uploads')) {
            // Construire l'URL complète depuis le chemin relatif
            senderAvatarUrl = ApiConfig.getFileUrl(avatarUrl);
          } else {
            senderAvatarUrl = avatarUrl;
          }
        }
      }
    }

    // Gérer la date
    DateTime messageDate = DateTime.now();
    if (json['date'] != null) {
      if (json['date'] is String) {
        messageDate = DateTime.parse(json['date']);
      } else if (json['date'] is DateTime) {
        messageDate = json['date'];
      }
    }

    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      if (json['updatedAt'] is String) {
        updatedAt = DateTime.parse(json['updatedAt']);
      } else if (json['updatedAt'] is DateTime) {
        updatedAt = json['updatedAt'];
      }
    }

    // Gérer le type
    MessageType messageType = MessageType.text;
    if (json['type'] != null) {
      messageType = MessageType.fromString(json['type']);
    }

    // Gérer metadata
    MessageMetadata? metadata;
    if (json['metadata'] != null) {
      metadata = MessageMetadata.fromJson(json['metadata']);
    }

    // Gérer replyPreview
    ReplyPreview? replyPreview;
    if (json['replyPreview'] != null) {
      replyPreview = ReplyPreview.fromJson(json['replyPreview']);
    }

    // Gérer reactions
    List<Reaction> reactions = [];
    if (json['reactions'] != null && json['reactions'] is List) {
      reactions = (json['reactions'] as List)
          .map((r) => Reaction.fromJson(r))
          .toList();
    }

    // Gérer deletedForUserIds
    List<String> deletedForUserIds = [];
    if (json['deletedForUserIds'] != null && json['deletedForUserIds'] is List) {
      deletedForUserIds = (json['deletedForUserIds'] as List)
          .map((id) => id.toString())
          .toList();
    }

    // Gérer mentions
    List<String> mentions = [];
    if (json['mentions'] != null && json['mentions'] is List) {
      mentions = (json['mentions'] as List).map((id) => id.toString()).toList();
    }

    // Gérer pollData - seulement si c'est un vrai sondage (avec question et options)
    PollData? pollData;
    if (json['pollData'] != null) {
      final pollDataJson = json['pollData'];
      // Vérifier que c'est un vrai sondage : doit avoir une question non vide et des options
      if (pollDataJson is Map<String, dynamic> && 
          pollDataJson['question'] != null && 
          pollDataJson['question'].toString().trim().isNotEmpty &&
          pollDataJson['options'] != null && 
          pollDataJson['options'] is List &&
          (pollDataJson['options'] as List).isNotEmpty) {
        pollData = PollData.fromJson(pollDataJson);
      }
    }

    // Gérer proposedRideId
    String? proposedRideId;
    if (json['proposedRideId'] != null) {
      proposedRideId = json['proposedRideId'] is String
          ? json['proposedRideId']
          : json['proposedRideId']['_id']?.toString() ?? json['proposedRideId']['id']?.toString();
    }

    return MessageExtended(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      auteurId: auteurId,
      auteurPseudo: auteurPseudo,
      auteurEmail: auteurEmail,
      senderAvatarUrl: senderAvatarUrl,
      contenu: json['contenu'] ?? '',
      date: messageDate,
      updatedAt: updatedAt,
      idBalade: json['idBalade']?.toString() ??
          (json['idBalade'] is Map
              ? (json['idBalade']['id'] ?? json['idBalade']['_id'])?.toString()
              : null),
      idGroupe: json['idGroupe']?.toString() ??
          (json['idGroupe'] is Map
              ? (json['idGroupe']['id'] ?? json['idGroupe']['_id'])?.toString()
              : null),
      type: messageType,
      metadata: metadata,
      edited: json['edited'] ?? false,
      deletedForAll: json['deletedForAll'] ?? false,
      deletedForUserIds: deletedForUserIds,
      replyToMessageId: json['replyToMessageId']?.toString(),
      replyPreview: replyPreview,
      reactions: reactions,
      mentions: mentions,
      status: MessageStatus.sent, // Par défaut, sera mis à jour par le client
      pinned: json['pinned'] ?? false,
      pinnedAt: json['pinnedAt'] != null 
          ? (json['pinnedAt'] is String 
              ? DateTime.parse(json['pinnedAt']) 
              : json['pinnedAt'] as DateTime?)
          : null,
      pinnedById: json['pinnedBy'] != null
          ? (json['pinnedBy'] is String
              ? json['pinnedBy']
              : json['pinnedBy']['_id']?.toString() ?? json['pinnedBy']['id']?.toString())
          : null,
      pinnedByPseudo: json['pinnedBy'] != null && json['pinnedBy'] is Map
          ? json['pinnedBy']['pseudo']
          : null,
      pollData: pollData,
      proposedRideId: proposedRideId,
    );
  }

  String get displayName {
    return auteurPseudo ?? auteurEmail ?? 'Utilisateur';
  }

  bool get isDeleted {
    return deletedForAll;
  }

  bool isDeletedForUser(String userId) {
    return deletedForUserIds.contains(userId);
  }

  bool hasReaction(String emoji, String userId) {
    return reactions.any((r) => r.emoji == emoji && r.userId == userId);
  }

  List<Reaction> getReactionsByEmoji(String emoji) {
    return reactions.where((r) => r.emoji == emoji).toList();
  }

  Map<String, int> get reactionsSummary {
    final Map<String, int> summary = {};
    for (final reaction in reactions) {
      summary[reaction.emoji] = (summary[reaction.emoji] ?? 0) + 1;
    }
    return summary;
  }
}

enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  system,
  poll,
  ride;

  static MessageType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      case 'poll':
        return MessageType.poll;
      case 'ride':
        return MessageType.ride;
      default:
        return MessageType.text;
    }
  }
}

class MessageMetadata {
  final String? url;
  final String? mimeType;
  final int? size;
  final int? duration;
  final String? fileName;

  MessageMetadata({
    this.url,
    this.mimeType,
    this.size,
    this.duration,
    this.fileName,
  });

  factory MessageMetadata.fromJson(Map<String, dynamic> json) {
    return MessageMetadata(
      url: json['url'],
      mimeType: json['mimeType'],
      size: json['size'],
      duration: json['duration'],
      fileName: json['fileName'],
    );
  }
}

class ReplyPreview {
  final String senderPseudo;
  final String content;
  final String type;

  ReplyPreview({
    required this.senderPseudo,
    required this.content,
    required this.type,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) {
    return ReplyPreview(
      senderPseudo: json['senderPseudo'] ?? 'Utilisateur',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
    );
  }
}

class Reaction {
  final String emoji;
  final String userId;
  final String? userPseudo;
  final DateTime createdAt;

  Reaction({
    required this.emoji,
    required this.userId,
    this.userPseudo,
    required this.createdAt,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) {
    DateTime createdAt = DateTime.now();
    if (json['createdAt'] != null) {
      if (json['createdAt'] is String) {
        createdAt = DateTime.parse(json['createdAt']);
      } else if (json['createdAt'] is DateTime) {
        createdAt = json['createdAt'];
      }
    }

    return Reaction(
      emoji: json['emoji'] ?? '',
      userId: json['userId']?.toString() ?? json['userId']?['id']?.toString() ?? '',
      userPseudo: json['userPseudo'],
      createdAt: createdAt,
    );
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read;
}

class PollData {
  final String question;
  final List<PollOption> options;
  final bool multipleChoice;
  final DateTime? expiresAt;

  PollData({
    required this.question,
    required this.options,
    this.multipleChoice = false,
    this.expiresAt,
  });

  factory PollData.fromJson(Map<String, dynamic> json) {
    List<PollOption> options = [];
    if (json['options'] != null && json['options'] is List) {
      options = (json['options'] as List)
          .map((opt) => PollOption.fromJson(opt))
          .toList();
    }

    DateTime? expiresAt;
    if (json['expiresAt'] != null) {
      if (json['expiresAt'] is String) {
        expiresAt = DateTime.parse(json['expiresAt']);
      } else if (json['expiresAt'] is DateTime) {
        expiresAt = json['expiresAt'];
      }
    }

    return PollData(
      question: json['question'] ?? 'Sondage',
      options: options,
      multipleChoice: json['multipleChoice'] ?? false,
      expiresAt: expiresAt,
    );
  }

  int get totalVotes {
    return options.fold(0, (sum, option) => sum + option.votes.length);
  }
}

class PollOption {
  final String text;
  final List<PollVote> votes;

  PollOption({
    required this.text,
    required this.votes,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    List<PollVote> votes = [];
    if (json['votes'] != null && json['votes'] is List) {
      votes = (json['votes'] as List)
          .map((vote) => PollVote.fromJson(vote))
          .toList();
    }

    return PollOption(
      text: json['text'] ?? '',
      votes: votes,
    );
  }
}

class PollVote {
  final String userId;
  final String? userPseudo;
  final DateTime votedAt;

  PollVote({
    required this.userId,
    this.userPseudo,
    required this.votedAt,
  });

  factory PollVote.fromJson(Map<String, dynamic> json) {
    DateTime votedAt = DateTime.now();
    if (json['votedAt'] != null) {
      if (json['votedAt'] is String) {
        votedAt = DateTime.parse(json['votedAt']);
      } else if (json['votedAt'] is DateTime) {
        votedAt = json['votedAt'];
      }
    }

    String userId = '';
    if (json['userId'] != null) {
      if (json['userId'] is String) {
        userId = json['userId'];
      } else if (json['userId'] is Map) {
        userId = json['userId']['_id']?.toString() ?? json['userId']['id']?.toString() ?? '';
      }
    }

    return PollVote(
      userId: userId,
      userPseudo: json['userPseudo'],
      votedAt: votedAt,
    );
  }
}

