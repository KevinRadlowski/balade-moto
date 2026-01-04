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
  visibilite: {
    type: String,
    enum: ['privee', 'publique'],
    default: 'publique'
  },
  participants: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
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
rideSchema.index({ status: 1, date: 1 }); // Pour les requêtes par statut
rideSchema.index({ ridingStyle: 1 }); // Pour les filtres par style
// Index géospatial 2dsphere pour les requêtes de proximité
rideSchema.index({ localisation: '2dsphere' });

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

