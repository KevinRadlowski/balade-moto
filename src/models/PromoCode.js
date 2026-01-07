const mongoose = require('mongoose');
const { hashCode, extractPrefix } = require('../utils/promoCode.util');

const promoCodeSchema = new mongoose.Schema({
  // Hash du code (jamais le code en clair)
  codeHash: {
    type: String,
    required: [true, 'Le hash du code est requis'],
    unique: true,
    index: true,
    trim: true
  },
  // Préfixe pour faciliter la recherche (ex: "A3B2" pour RT-A3B2-XXXX-XXXX)
  codePrefix: {
    type: String,
    required: true,
    trim: true,
    uppercase: true,
    maxlength: [10, 'Le préfixe ne peut pas dépasser 10 caractères'],
    index: true
  },
  // Type de code promotionnel
  type: {
    type: String,
    required: [true, 'Le type de code est requis'],
    enum: {
      values: ['DISCOUNT_PERCENT', 'GRANT_PREMIUM_MONTHS', 'GRANT_PREMIUM_PERMANENT'],
      message: 'Le type doit être DISCOUNT_PERCENT, GRANT_PREMIUM_MONTHS ou GRANT_PREMIUM_PERMANENT'
    },
    index: true
  },
  // Pourcentage de réduction (si type = DISCOUNT_PERCENT)
  discountPercent: {
    type: Number,
    min: [1, 'Le pourcentage de réduction doit être entre 1 et 100'],
    max: [100, 'Le pourcentage de réduction doit être entre 1 et 100'],
    validate: {
      validator: function(value) {
        if (this.type === 'DISCOUNT_PERCENT') {
          return value != null && value >= 1 && value <= 100;
        }
        return value == null;
      },
      message: 'discountPercent est requis et doit être entre 1 et 100 pour DISCOUNT_PERCENT'
    }
  },
  // Nombre de mois Premium (si type = GRANT_PREMIUM_MONTHS)
  premiumMonths: {
    type: Number,
    min: [1, 'Le nombre de mois Premium doit être au moins 1'],
    validate: {
      validator: function(value) {
        if (this.type === 'GRANT_PREMIUM_MONTHS') {
          return value != null && value >= 1;
        }
        return value == null;
      },
      message: 'premiumMonths est requis et doit être >= 1 pour GRANT_PREMIUM_MONTHS'
    }
  },
  // Limite d'utilisation (nombre de fois que le code peut être utilisé)
  usageLimit: {
    type: Number,
    default: 1,
    min: [1, 'La limite d\'utilisation doit être au moins 1']
  },
  // Nombre de fois que le code a été utilisé
  usedCount: {
    type: Number,
    default: 0,
    min: [0, 'Le compteur d\'utilisation ne peut pas être négatif']
  },
  // Historique des utilisations (pour audit)
  usedBy: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    usedAt: {
      type: Date,
      default: Date.now
    },
    // Détails optionnels (ex: montant économisé, mois accordés, etc.)
    details: {
      type: mongoose.Schema.Types.Mixed,
      default: null
    }
  }],
  // Dates de validité
  validFrom: {
    type: Date,
    default: null
  },
  validUntil: {
    type: Date,
    default: null
  },
  // Statut actif/inactif
  isActive: {
    type: Boolean,
    default: true,
    index: true
  },
  // Créateur (admin)
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'Le créateur est requis']
  },
  // Métadonnées libres (ex: campagne, description, etc.)
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  }
}, {
  timestamps: true // Ajoute createdAt et updatedAt automatiquement
});

// Index composé pour les requêtes admin (codes actifs et valides)
promoCodeSchema.index({ isActive: 1, validUntil: 1 });

// Index pour recherche par préfixe
promoCodeSchema.index({ codePrefix: 1, isActive: 1 });

// Méthode statique pour créer un code promotionnel
promoCodeSchema.statics.createFromPlainCode = async function(plainCode, data, createdBy) {
  const codeHash = hashCode(plainCode);
  const codePrefix = extractPrefix(plainCode);
  
  // Vérifier que le code n'existe pas déjà
  const existing = await this.findOne({ codeHash });
  if (existing) {
    throw new Error('Ce code promotionnel existe déjà');
  }
  
  const promoCode = new this({
    codeHash,
    codePrefix,
    type: data.type,
    discountPercent: data.discountPercent,
    premiumMonths: data.premiumMonths,
    usageLimit: data.usageLimit || 1,
    validFrom: data.validFrom,
    validUntil: data.validUntil,
    isActive: data.isActive !== undefined ? data.isActive : true,
    createdBy,
    metadata: data.metadata || {}
  });
  
  return await promoCode.save();
};

// Méthode pour vérifier si le code est valide
promoCodeSchema.methods.isValid = function() {
  if (!this.isActive) {
    return false;
  }
  
  if (this.usedCount >= this.usageLimit) {
    return false;
  }
  
  const now = new Date();
  
  if (this.validFrom && now < this.validFrom) {
    return false;
  }
  
  if (this.validUntil && now > this.validUntil) {
    return false;
  }
  
  return true;
};

// Méthode pour vérifier si un utilisateur a déjà utilisé ce code
promoCodeSchema.methods.hasBeenUsedBy = function(userId) {
  if (!userId) {
    return false;
  }
  
  const userIdStr = userId.toString();
  return this.usedBy.some(usage => usage.userId.toString() === userIdStr);
};

// Méthode pour enregistrer l'utilisation du code
promoCodeSchema.methods.recordUsage = async function(userId, details = null) {
  if (!this.isValid()) {
    throw new Error('Ce code promotionnel n\'est plus valide');
  }
  
  if (this.hasBeenUsedBy(userId)) {
    throw new Error('Vous avez déjà utilisé ce code promotionnel');
  }
  
  this.usedBy.push({
    userId,
    usedAt: new Date(),
    details
  });
  
  this.usedCount += 1;
  
  return await this.save();
};

module.exports = mongoose.model('PromoCode', promoCodeSchema);

