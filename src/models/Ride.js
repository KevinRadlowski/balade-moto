const mongoose = require('mongoose');

const rideSchema = new mongoose.Schema({
  titre: {
    type: String,
    required: [true, 'Le titre est requis'],
    trim: true,
    maxlength: [200, 'Le titre ne peut pas dépasser 200 caractères']
  },
  description: {
    type: String,
    trim: true,
    maxlength: [2000, 'La description ne peut pas dépasser 2000 caractères']
  },
  typeVehicule: {
    type: String,
    enum: ['moto', 'voiture'],
    required: [true, 'Le type de véhicule est requis']
  },
  date: {
    type: Date,
    required: [true, 'La date est requise']
  },
  heure: {
    type: String,
    required: [true, 'L\'heure est requise'],
    match: [/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'Format d\'heure invalide (HH:MM)']
  },
  lieuDepart: {
    type: mongoose.Schema.Types.Mixed,
    required: [true, 'Le lieu de départ est requis']
    // Peut être une string ou un objet GeoJSON
  },
  lieuArrivee: {
    type: mongoose.Schema.Types.Mixed,
    required: [true, 'Le lieu d\'arrivée est requis']
    // Peut être une string ou un objet GeoJSON
  },
  // Nouveau système de waypoints (comme Liberty Rider)
  waypoints: [{
    _id: {
      type: mongoose.Schema.Types.ObjectId,
      auto: true
    },
    type: {
      type: String,
      enum: ['depart', 'checkpoint', 'arrivee'],
      required: true
    },
    address: {
      type: String,
      required: true
    },
    coordinates: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point'
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        required: true,
        validate: {
          validator: function(coords) {
            return coords.length === 2 && 
                   coords[0] >= -180 && coords[0] <= 180 && 
                   coords[1] >= -90 && coords[1] <= 90;
          },
          message: 'Les coordonnées doivent être [longitude, latitude]'
        }
      }
    },
    order: {
      type: Number,
      required: true,
      min: 0
    },
    // NOUVEAUX CHAMPS - Types de waypoints avancés
    waypointType: {
      type: String,
      enum: ['normal', 'fuel', 'coffee', 'danger', 'viewpoint'],
      default: 'normal'
    },
    isMandatoryStop: {
      type: Boolean,
      default: false
    },
    note: {
      type: String,
      maxlength: [500, 'La note ne peut pas dépasser 500 caractères'],
      default: null
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null
    },
    createdAt: {
      type: Date,
      default: Date.now
    }
  }],
  localisation: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point'
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: false,
      validate: {
        validator: function(coords) {
          return !coords || (coords.length === 2 && 
                 coords[0] >= -180 && coords[0] <= 180 && 
                 coords[1] >= -90 && coords[1] <= 90);
        },
        message: 'Les coordonnées doivent être [longitude, latitude] avec longitude entre -180 et 180, latitude entre -90 et 90'
      }
    }
  },
  rayon: {
    type: Number,
    required: false, // Le rayon n'est plus requis, il est utilisé uniquement pour la recherche
    min: [0, 'Le rayon doit être positif'],
    default: 0
  },
  organisateur: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'L\'organisateur est requis']
  },
  // Association avec un groupe (optionnel, rétrocompatible)
  groupId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Group',
    default: null,
    index: true
  },
  visibilite: {
    type: String,
    enum: ['privee', 'publique', 'secrete'],
    default: 'publique'
  },
  
  // Lien secret pour les balades secrètes (généré automatiquement)
  secretLink: {
    type: String,
  },
  participants: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    vehicleId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Vehicle',
      default: null // Véhicule avec lequel le participant effectue la balade (optionnel)
    },
    // Informations de ponctualité
    arrivalTime: {
      type: Date,
      default: null // Heure à laquelle le participant a indiqué son arrivée
    },
    isOnTime: {
      type: Boolean,
      default: null // null = non validé (considéré comme à l'heure par défaut), true = à l'heure, false = en retard
    },
    validatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null // Qui a validé/invalidé (généralement l'organisateur)
    },
    validatedAt: {
      type: Date,
      default: null // Quand la validation a eu lieu
    }
  }],
  invitations: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'declined'],
      default: 'pending'
    },
    invitedAt: {
      type: Date,
      default: Date.now
    },
    respondedAt: {
      type: Date,
      default: null
    }
  }],
  likes: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  notes: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    note: {
      type: Number,
      required: true,
      min: [0, 'La note doit être entre 0 et 5'],
      max: [5, 'La note doit être entre 0 et 5']
    },
    createdAt: {
      type: Date,
      default: Date.now
    }
  }],
  noteMoyenne: {
    type: Number,
    default: 0,
    min: 0,
    max: 5
  },
  // Statut de la balade
  status: {
    type: String,
    enum: ['scheduled', 'in_progress', 'completed', 'cancelled', 'postponed'],
    default: 'scheduled',
    index: true
  },
  // Style de conduite
  ridingStyle: {
    type: String,
    enum: ['calme', 'modere', 'sportif', 'mixte'],
    default: null
  },
  // ========== ANNULATION / REPORT ==========
  // Annulation
  cancellation: {
    cancelledAt: {
      type: Date,
      default: null
    },
    cancelledBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null
    },
    cancelReasonCode: {
      type: String,
      enum: ['WEATHER', 'MECHANICAL', 'ROAD_CLOSED', 'LOW_PARTICIPATION', 'OTHER'],
      default: null
    },
    cancelReasonText: {
      type: String,
      maxlength: [500, 'Le texte de raison ne peut pas dépasser 500 caractères'],
      default: null
    }
  },
  // Report (reporté sans nouvelle date)
  postponement: {
    postponedAt: {
      type: Date,
      default: null
    },
    postponedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null
    },
    postponeReasonCode: {
      type: String,
      enum: ['WEATHER', 'MECHANICAL', 'ROAD_CLOSED', 'LOW_PARTICIPATION', 'OTHER'],
      default: null
    },
    postponeReasonText: {
      type: String,
      maxlength: [500, 'Le texte de raison ne peut pas dépasser 500 caractères'],
      default: null
    },
    newDateTime: {
      type: Date,
      default: null // Date/heure proposée pour le report (optionnel)
    }
  },
  // Reprogrammation (duplication)
  originalRideId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    default: null // Si cette balade est une reprogrammation, référence à la balade originale
  },
  reprogrammedToRideId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    default: null // Si cette balade a été reprogrammée, référence à la nouvelle balade
  },

  // ========== OUTILS ORGANISATEUR ==========
  
  // 1) Validation manuelle des participants
  requiresApproval: {
    type: Boolean,
    default: false // Si true, les demandes doivent être approuvées par l'organisateur
  },
  
  // Demandes de participation en attente d'approbation
  pendingRequests: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    vehicleId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Vehicle',
      default: null
    },
    requestedAt: {
      type: Date,
      default: Date.now
    },
    message: {
      type: String,
      maxlength: [500, 'Le message ne peut pas dépasser 500 caractères'],
      default: null
    }
  }],
  
  // 2) Limite de participants + liste d'attente
  maxParticipants: {
    type: Number,
    default: null, // null = illimité
    min: [1, 'La limite doit être au moins 1']
  },
  
  enableWaitlist: {
    type: Boolean,
    default: false // Si true, les participants au-delà de la limite sont mis en liste d'attente
  },
  
  waitlist: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    vehicleId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Vehicle',
      default: null
    },
    addedAt: {
      type: Date,
      default: Date.now
    },
    position: {
      type: Number,
      required: true
    }
  }],
  
  // 3) Message automatique avant la balade
  autoReminder: {
    enabled: {
      type: Boolean,
      default: false
    },
    hoursBefore: {
      type: Number,
      default: 24, // Par défaut 24h avant
      min: [1, 'Le rappel doit être au moins 1 heure avant'],
      max: [168, 'Le rappel ne peut pas être plus de 7 jours avant']
    },
    message: {
      type: String,
      maxlength: [1000, 'Le message ne peut pas dépasser 1000 caractères'],
      default: null // Si null, un message par défaut sera utilisé
    },
    sentAt: {
      type: Date,
      default: null // Date à laquelle le rappel a été envoyé
    }
  },
  
  // 4) Balades récurrentes
  recurrence: {
    enabled: {
      type: Boolean,
      default: false
    },
    frequency: {
      type: String,
      enum: ['weekly', 'biweekly', 'monthly'],
      default: 'weekly'
    },
    dayOfWeek: {
      type: Number, // 0 = dimanche, 1 = lundi, ..., 6 = samedi
      min: 0,
      max: 6,
      default: null
    },
    endDate: {
      type: Date,
      default: null // Date de fin de la récurrence (null = infini)
    },
    parentRideId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Ride',
      default: null // Pour les balades créées automatiquement, référence à la balade parente
    },
    nextOccurrence: {
      type: Date,
      default: null // Prochaine occurrence à créer
    }
  },
  // Événements de la balade (pour mode live)
  rideEvents: [{
    type: {
      type: String,
      enum: ['started', 'paused', 'resumed', 'incident', 'completed', 'cancelled', 'participant_joined', 'participant_left'],
      required: true
    },
    timestamp: {
      type: Date,
      default: Date.now
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    details: {
      location: {
        type: {
          type: String,
          enum: ['Point'],
          default: 'Point'
        },
        coordinates: {
          type: [Number], // [longitude, latitude]
          default: null
        }
      },
      description: {
        type: String,
        trim: true,
        maxlength: [500, 'La description ne peut pas dépasser 500 caractères']
      }
    }
  }]
}, {
  timestamps: true
});

// Index pour améliorer les performances de recherche
rideSchema.index({ organisateur: 1 });
rideSchema.index({ date: 1 });
rideSchema.index({ typeVehicule: 1 });
rideSchema.index({ visibilite: 1 });
rideSchema.index({ participants: 1 });
rideSchema.index({ 'participants.vehicleId': 1 }); // Pour rechercher les balades par véhicule
rideSchema.index({ status: 1, date: 1 }); // Pour les requêtes par statut
rideSchema.index({ ridingStyle: 1 }); // Pour les filtres par style
// Index pour calendar groupe
rideSchema.index({ groupId: 1, date: 1 }); // Calendar queries
rideSchema.index({ groupId: 1, status: 1, date: 1 }); // Filtered calendar
// Index compound pour requêtes fréquentes (listing avec filtres)
rideSchema.index({ typeVehicule: 1, date: 1, visibilite: 1 });
rideSchema.index({ organisateur: 1, date: -1 }); // Mes balades triées par date
rideSchema.index({ 'participants.userId': 1, date: -1 }); // Balades où je participe
rideSchema.index({ createdAt: -1 }); // Tri par date de création
rideSchema.index({ 'invitations.userId': 1 }); // Pour rechercher les invitations par utilisateur
rideSchema.index({ 'invitations.status': 1 }); // Pour filtrer par statut d'invitation
// Index géospatial 2dsphere pour les requêtes de proximité
rideSchema.index({ localisation: '2dsphere' });
// Index pour les outils organisateur
rideSchema.index({ 'pendingRequests.userId': 1 });
rideSchema.index({ 'waitlist.userId': 1 });
rideSchema.index({ 'recurrence.parentRideId': 1 });
rideSchema.index({ 'recurrence.nextOccurrence': 1 });
rideSchema.index({ 'autoReminder.enabled': 1, 'autoReminder.sentAt': 1, date: 1 });
rideSchema.index({ secretLink: 1 }, { unique: true, sparse: true });

// Méthode pour calculer la note moyenne
rideSchema.methods.calculateAverageRating = function() {
  if (this.notes.length === 0) {
    this.noteMoyenne = 0;
    return;
  }
  
  const sum = this.notes.reduce((acc, note) => acc + note.note, 0);
  this.noteMoyenne = Math.round((sum / this.notes.length) * 10) / 10; // Arrondi à 1 décimale
};

// Middleware pre-save pour calculer la note moyenne
rideSchema.pre('save', function(next) {
  if (this.isModified('notes')) {
    this.calculateAverageRating();
  }
  next();
});

module.exports = mongoose.model('Ride', rideSchema);

