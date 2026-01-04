const mongoose = require('mongoose');

const vehicleSchema = new mongoose.Schema({
  ownerUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'Le propriétaire est requis']
    // index: true retiré car déjà couvert par l'index composé ci-dessous
  },
  type: {
    type: String,
    required: [true, 'Le type de véhicule est requis'],
    enum: {
      values: ['moto', 'voiture'],
      message: 'Le type doit être "moto" ou "voiture"'
    }
  },
  nickname: {
    type: String,
    trim: true,
    maxlength: [100, 'Le surnom ne peut pas dépasser 100 caractères']
  },
  make: {
    type: String,
    trim: true,
    maxlength: [50, 'La marque ne peut pas dépasser 50 caractères']
  },
  model: {
    type: String,
    trim: true,
    maxlength: [100, 'Le modèle ne peut pas dépasser 100 caractères']
  },
  trim: {
    type: String,
    trim: true,
    maxlength: [50, 'La finition ne peut pas dépasser 50 caractères']
  },
  year: {
    type: Number,
    min: [1900, 'L\'année doit être supérieure à 1900'],
    max: [new Date().getFullYear() + 1, 'L\'année ne peut pas être dans le futur']
  },
  engine: {
    fuel: {
      type: String,
      enum: ['essence', 'diesel', 'electrique', 'hybride', 'autre'],
      trim: true
    },
    displacementCc: {
      type: Number,
      min: [0, 'La cylindrée ne peut pas être négative']
    },
    powerHp: {
      type: Number,
      min: [0, 'La puissance ne peut pas être négative']
    },
    powerKw: {
      type: Number,
      min: [0, 'La puissance ne peut pas être négative']
    },
    transmission: {
      type: String,
      enum: ['manuelle', 'automatique', 'cvt', 'autre'],
      trim: true
    }
  },
  odometerCurrentKm: {
    type: Number,
    required: [true, 'Le kilométrage actuel est requis'],
    min: [0, 'Le kilométrage ne peut pas être négatif'],
    default: 0
  },
  purchase: {
    date: {
      type: Date
    },
    price: {
      type: Number,
      min: [0, 'Le prix ne peut pas être négatif']
    },
    sellerType: {
      type: String,
      enum: ['particulier', 'professionnel', 'concessionnaire', 'autre'],
      trim: true
    }
  },
  insurance: {
    company: {
      type: String,
      trim: true,
      maxlength: [100, 'Le nom de la compagnie ne peut pas dépasser 100 caractères']
    },
    policyNumber: {
      type: String,
      trim: true,
      maxlength: [50, 'Le numéro de police ne peut pas dépasser 50 caractères']
    },
    renewalDate: {
      type: Date
    }
  },
  notes: {
    type: String,
    trim: true,
    maxlength: [2000, 'Les notes ne peuvent pas dépasser 2000 caractères']
  },
  // Ancien champ (déprécié, conservé pour compatibilité)
  photoUrl: {
    type: String,
    trim: true,
    maxlength: [500, 'L\'URL de la photo ne peut pas dépasser 500 caractères'],
    description: 'URL de la photo du véhicule (déprécié, utiliser photos[])'
  },
  // Nouveau champ : galerie de photos
  photos: [{
    url: {
      type: String,
      required: [true, 'L\'URL de la photo est requise'],
      trim: true,
      maxlength: [500, 'L\'URL de la photo ne peut pas dépasser 500 caractères']
    },
    uploadedAt: {
      type: Date,
      default: Date.now
    },
    order: {
      type: Number,
      default: 0,
      description: 'Ordre d\'affichage (0 = première photo)'
    }
  }],
  selectionSource: {
    type: String,
    enum: {
      values: ['MANUAL', 'CATALOG', 'CATALOG_LOCAL', 'SUGGESTION', 'VPIC'],
      message: 'selectionSource doit être "MANUAL", "CATALOG", "CATALOG_LOCAL", "SUGGESTION" ou "VPIC"'
    },
    default: 'MANUAL',
    index: true
  },
  // Champ unifié pour les catalogues externes (CarAPI.app)
  externalCatalog: {
    provider: {
      type: String,
      enum: {
        values: ['CARAPI', 'LOCAL_FR', 'SUGGESTION'],
        message: 'provider doit être "CARAPI", "LOCAL_FR" ou "SUGGESTION"'
      }
    },
    vehicleType: {
      type: String,
      enum: {
        values: ['voiture', 'moto'],
        message: 'vehicleType doit être "voiture" ou "moto"'
      }
    },
    makeId: {
      type: String,
      trim: true,
      description: 'ID de la marque dans le catalogue externe (string, jamais d\'entier)'
    },
    modelId: {
      type: String,
      trim: true,
      description: 'ID du modèle dans le catalogue externe (string, jamais d\'entier). Optionnel pour SUGGESTION.'
    },
    make: {
      type: String,
      trim: true,
      uppercase: true,
      description: 'Nom de la marque (pour SUGGESTION uniquement)'
    },
    model: {
      type: String,
      trim: true,
      uppercase: true,
      description: 'Nom du modèle (pour SUGGESTION uniquement)'
    },
    year: {
      type: Number,
      description: 'Année du véhicule dans le catalogue'
    },
    raw: {
      type: mongoose.Schema.Types.Mixed,
      description: 'Données brutes du catalogue externe (optionnel)'
    }
  },
  // Champs dépréciés (conservés pour compatibilité, mais plus utilisés)
  vpic: {
    type: mongoose.Schema.Types.Mixed,
    description: 'DÉPRÉCIÉ: ne plus utiliser. Utiliser externalCatalog à la place.'
  },
  catalog: {
    type: mongoose.Schema.Types.Mixed,
    description: 'DÉPRÉCIÉ: ne plus utiliser. Utiliser externalCatalog à la place.'
  },
  active: {
    type: Boolean,
    default: true,
    index: true
  }
}, {
  timestamps: true
});

// Index composé pour les requêtes fréquentes
vehicleSchema.index({ ownerUserId: 1, active: 1 });
vehicleSchema.index({ ownerUserId: 1, type: 1, active: 1 });
// Index partiel pour type (seulement les actifs)
vehicleSchema.index({ type: 1 }, { partialFilterExpression: { active: true } });

// Virtuals pour compatibilité avec l'ancien code (si nécessaire)
vehicleSchema.virtual('owner').get(function() {
  return this.ownerUserId;
});

vehicleSchema.virtual('owner').set(function(value) {
  this.ownerUserId = value;
});

vehicleSchema.virtual('name').get(function() {
  return this.nickname || `${this.make || ''} ${this.model || ''}`.trim() || 'Véhicule sans nom';
});

vehicleSchema.virtual('brand').get(function() {
  return this.make;
});

vehicleSchema.virtual('brand').set(function(value) {
  this.make = value;
});

// S'assurer que les virtuals sont inclus dans le JSON
vehicleSchema.set('toJSON', { virtuals: true });
vehicleSchema.set('toObject', { virtuals: true });

// Migration soft: migrer vpic/catalog vers externalCatalog lors de la sauvegarde
vehicleSchema.pre('save', function(next) {
  // Si externalCatalog n'existe pas mais vpic ou catalog existent, migrer (legacy)
  if (!this.externalCatalog || (!this.externalCatalog.provider && !this.externalCatalog.makeId && !this.externalCatalog.modelId)) {
    // Migration depuis vpic (ancien format)
    if (this.vpic && (this.vpic.makeId || this.vpic.modelId)) {
      if (!this.externalCatalog) {
        this.externalCatalog = {};
      }
      if (!this.externalCatalog.provider) {
        this.externalCatalog.provider = 'CARAPI'; // Migration vers CARAPI
      }
      if (!this.externalCatalog.vehicleType && this.type) {
        this.externalCatalog.vehicleType = this.type;
      }
      if (this.vpic.makeId !== undefined) {
        this.externalCatalog.makeId = String(this.vpic.makeId); // Convertir en string
      }
      if (this.vpic.modelId !== undefined) {
        this.externalCatalog.modelId = String(this.vpic.modelId); // Convertir en string
      }
      if (this.year) {
        this.externalCatalog.year = this.year;
      }
    }
    
    // Migration depuis catalog (ancien format)
    if (this.catalog && (this.catalog.makeId || this.catalog.modelId)) {
      if (!this.externalCatalog) {
        this.externalCatalog = {};
      }
      if (!this.externalCatalog.provider) {
        this.externalCatalog.provider = 'CARAPI'; // Migration vers CARAPI
      }
      if (!this.externalCatalog.vehicleType && this.type) {
        this.externalCatalog.vehicleType = this.type;
      }
      if (this.catalog.makeId !== undefined) {
        this.externalCatalog.makeId = String(this.catalog.makeId); // Convertir en string
      }
      if (this.catalog.modelId !== undefined) {
        this.externalCatalog.modelId = String(this.catalog.modelId); // Convertir en string
      }
      if (this.year) {
        this.externalCatalog.year = this.year;
      }
      if (this.catalog.raw !== undefined) {
        this.externalCatalog.raw = this.catalog.raw;
      }
    }
  }
  
  // Normaliser selectionSource: VPIC -> CATALOG (legacy)
  if (this.selectionSource === 'VPIC') {
    this.selectionSource = 'CATALOG';
  }
  
  next();
});

module.exports = mongoose.model('Vehicle', vehicleSchema);
