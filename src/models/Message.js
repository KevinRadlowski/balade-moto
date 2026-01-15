const mongoose = require('mongoose');

const reactionSchema = new mongoose.Schema({
  emoji: {
    type: String,
    required: true,
    maxlength: [10, 'L\'emoji ne peut pas dépasser 10 caractères']
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  userPseudo: {
    type: String,
    default: null
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
}, { _id: false });

const messageSchema = new mongoose.Schema({
  auteur: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'L\'auteur est requis']
  },
  contenu: {
    type: String,
    required: false, // Rendre optionnel, on validera manuellement
    trim: true,
    maxlength: [2000, 'Le message ne peut pas dépasser 2000 caractères']
  },
  type: {
    type: String,
    enum: ['text', 'image', 'video', 'audio', 'file', 'system', 'poll', 'ride'],
    default: 'text'
  },
  metadata: {
    url: String,
    mimeType: String,
    size: Number,
    duration: Number, // Pour audio/video
    fileName: String
  },
  date: {
    type: Date,
    default: Date.now
  },
  idBalade: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    default: null
  },
  idGroupe: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Group',
    default: null
  },
  // Réponse à un message (pour les réponses directes)
  replyToMessageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null
  },
  // Threads : message parent dans un fil de discussion
  parentMessageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null,
    index: true
  },
  // Threads : ID du message racine du fil (pour performance)
  threadRootId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null,
    index: true
  },
  // Threads : nombre de réponses dans le fil (dénormalisé pour performance)
  threadReplyCount: {
    type: Number,
    default: 0,
    min: 0
  },
  replyPreview: {
    senderPseudo: {
      type: String,
      default: null
    },
    content: {
      type: String,
      default: null
    },
    type: {
      type: String,
      default: 'text'
    }
  },
  // Édition
  edited: {
    type: Boolean,
    default: false
  },
  // Suppression
  deletedForAll: {
    type: Boolean,
    default: false
  },
  deletedForUserIds: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  // Réactions
  reactions: [reactionSchema],
  // Mentions (optionnel)
  mentions: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  // Épinglage (pour les groupes)
  pinned: {
    type: Boolean,
    default: false
  },
  pinnedAt: {
    type: Date,
    default: null
  },
  pinnedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  // Sondage (poll)
  pollData: {
    question: {
      type: String,
      default: null
    },
    options: [{
      text: {
        type: String,
        required: true
      },
      votes: [{
        userId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'User',
          required: true
        },
        userPseudo: {
          type: String,
          default: null
        },
        votedAt: {
          type: Date,
          default: Date.now
        }
      }]
    }],
    multipleChoice: {
      type: Boolean,
      default: false
    },
    expiresAt: {
      type: Date,
      default: null
    }
  },
  // Référence à une balade proposée (pour les messages de type 'ride')
  proposedRideId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    default: null
  }
}, {
  timestamps: true
});

// Index pour améliorer les performances
messageSchema.index({ idBalade: 1, date: -1 });
messageSchema.index({ idGroupe: 1, date: -1 });
messageSchema.index({ auteur: 1 });
// Index pour requêtes fréquentes
messageSchema.index({ auteur: 1, date: -1 }); // Messages d'un utilisateur
messageSchema.index({ createdAt: -1 }); // Tri par création
// Index pour les threads
messageSchema.index({ parentMessageId: 1, date: 1 }); // Réponses d'un thread
messageSchema.index({ threadRootId: 1, date: 1 }); // Toutes les réponses d'un fil
messageSchema.index({ idGroupe: 1, parentMessageId: 1 }); // Messages principaux d'un groupe (parentMessageId = null)
// Index pour la recherche avancée
messageSchema.index({ contenu: 'text' }); // Index textuel pour recherche dans le contenu
messageSchema.index({ idGroupe: 1, type: 1, date: -1 }); // Pour filtrer par type (image, video, etc.) dans un groupe
messageSchema.index({ idGroupe: 1, 'pollData.question': 1, date: -1 }); // Pour filtrer les sondages dans un groupe

// Validation : soit idBalade soit idGroupe doit être défini
// Et soit contenu soit metadata (fichier) doit être présent
messageSchema.pre('validate', function(next) {
  if (!this.idBalade && !this.idGroupe) {
    return next(new Error('Un message doit être associé à une balade ou un groupe'));
  }
  if (this.idBalade && this.idGroupe) {
    return next(new Error('Un message ne peut pas être associé à une balade et un groupe simultanément'));
  }
  // Le contenu est requis seulement s'il n'y a pas de fichier (metadata)
  const hasFile = this.metadata && this.metadata.url;
  const hasContent = this.contenu && this.contenu.trim().length > 0;
  if (!hasFile && !hasContent) {
    return next(new Error('Le contenu du message est requis'));
  }
  next();
});

module.exports = mongoose.model('Message', messageSchema);

