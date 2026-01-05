const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: [true, 'L\'email est requis'],
    unique: true,
    lowercase: true,
    trim: true,
    match: [/^\S+@\S+\.\S+$/, 'Veuillez entrer un email valide']
  },
  password: {
    type: String,
    required: function() {
      // Le mot de passe est requis seulement si l'utilisateur n'utilise pas OAuth
      return !this.authProvider;
    },
    minlength: [6, 'Le mot de passe doit contenir au moins 6 caractères']
  },
  // Authentification OAuth
  authProvider: {
    type: String,
    enum: ['google', 'apple', 'facebook'],
    default: null
  },
  providerId: {
    type: String,
    default: null,
    trim: true
  },
  // Informations de profil
  firstName: {
    type: String,
    trim: true,
    default: null
  },
  lastName: {
    type: String,
    trim: true,
    default: null
  },
  pseudo: {
    type: String,
    required: [true, 'Le pseudo est requis'],
    trim: true,
    unique: true,
    minlength: [3, 'Le pseudo doit contenir au moins 3 caractères'],
    maxlength: [30, 'Le pseudo ne peut pas dépasser 30 caractères'],
    match: [/^[a-zA-Z0-9_-]+$/, 'Le pseudo ne peut contenir que des lettres, chiffres, tirets et underscores']
  },
  vehiclePreference: {
    type: String,
    enum: ['moto', 'voiture', 'les deux'],
    default: 'moto'
  },
  avatarUrl: {
    type: String,
    default: null,
    trim: true
  },
  // Backgrounds personnalisés
  customBackgrounds: {
    balade: {
      type: String,
      default: null,
      trim: true
    },
    groupe: {
      type: String,
      default: null,
      trim: true
    },
    profil: {
      type: String,
      default: null,
      trim: true
    },
    global: {
      type: String,
      default: null,
      trim: true
    }
  },
  // Rôles et permissions
  role: {
    type: String,
    enum: ['MEMBER', 'ADMIN'],
    default: 'MEMBER',
    index: true
  },
  roles: {
    type: [String],
    enum: ['user', 'admin', 'moderator'],
    default: ['user']
  },
  refreshToken: {
    type: String,
    default: null
  },
  // Vérification email
  emailVerified: {
    type: Boolean,
    default: false
  },
  emailVerificationToken: {
    type: String,
    default: null
  },
  emailVerificationExpires: {
    type: Date,
    default: null
  },
  emailVerificationLastSent: {
    type: Date,
    default: null
  },
  // Verrouillage compte
  loginAttempts: {
    type: Number,
    default: 0
  },
  lockUntil: {
    type: Date,
    default: null
  },
  // Bannissement utilisateur
  banned: {
    type: Boolean,
    default: false,
    index: true
  },
  // Authentification à deux facteurs
  twoFactorEnabled: {
    type: Boolean,
    default: false
  },
  isTwoFactorEnabled: {
    type: Boolean,
    default: false
  },
  twoFactorMethod: {
    type: String,
    enum: ['totp', 'sms', 'email'],
    default: null
  },
  twoFactorSecret: {
    type: String,
    default: null
  },
  // Contact d'urgence
  emergencyContact: {
    name: {
      type: String,
      trim: true,
      maxlength: [100, 'Le nom ne peut pas dépasser 100 caractères']
    },
    phone: {
      type: String,
      trim: true,
      validate: {
        validator: function(value) {
          if (!value) return false;
          // Accepter les emails
          const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
          if (emailRegex.test(value)) return true;
          // Accepter les numéros français (0 suivi de 9 chiffres) et internationaux (+ suivi de 8-15 chiffres)
          const phoneRegex = /^(\+?\d{8,15}|0\d{9})$/;
          return phoneRegex.test(value);
        },
        message: 'Format de téléphone invalide (doit être un email ou un numéro valide)'
      }
    },
    relation: {
      type: String,
      enum: ['family', 'friend', 'colleague', 'other'],
      default: 'family'
    },
    notes: {
      type: String,
      trim: true,
      maxlength: [500, 'Les notes ne peuvent pas dépasser 500 caractères']
    }
  },
  // Statut de check-in (pour détection inactivité)
  checkInStatus: {
    lastHeartbeat: {
      type: Date,
      default: null
    },
    isActive: {
      type: Boolean,
      default: false,
      index: true
    },
    lastLocation: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point'
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        default: null
      }
    }
  }
}, {
  timestamps: true
});

// Index unique sur pseudo (plus besoin de sparse car le pseudo est maintenant obligatoire)

// Index pour améliorer les performances
userSchema.index({ 'checkInStatus.isActive': 1, 'checkInStatus.lastHeartbeat': 1 }); // Pour les jobs cron

// Hash du mot de passe avant sauvegarde
userSchema.pre('save', async function(next) {
  // Normaliser le rôle (compatibilité legacy)
  if (this.role === 'user') {
    this.role = 'MEMBER';
  } else if (this.role === 'admin') {
    this.role = 'ADMIN';
  } else if (!this.role || this.role === '') {
    this.role = 'MEMBER';
  }
  
  // Synchroniser isTwoFactorEnabled avec twoFactorEnabled
  if (this.isModified('twoFactorEnabled')) {
    this.isTwoFactorEnabled = this.twoFactorEnabled;
  }
  if (this.isModified('isTwoFactorEnabled')) {
    this.twoFactorEnabled = this.isTwoFactorEnabled;
  }
  
  // Ne pas hasher le mot de passe si l'utilisateur utilise OAuth ou si le mot de passe n'est pas modifié
  if (!this.isModified('password') || !this.password || this.authProvider) {
    return next();
  }
  
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Méthode pour comparer les mots de passe
userSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

// Vérifier si le compte est verrouillé
userSchema.methods.isLocked = function() {
  return !!(this.lockUntil && this.lockUntil > Date.now());
};

// Incrémenter les tentatives de connexion
userSchema.methods.incLoginAttempts = async function() {
  // Si le compte était verrouillé et que le délai est expiré, réinitialiser
  if (this.lockUntil && this.lockUntil < Date.now()) {
    this.loginAttempts = 1;
    this.lockUntil = undefined;
    return await this.save();
  }
  
  this.loginAttempts += 1;
  
  // Verrouiller après 5 tentatives pendant 15 minutes
  if (this.loginAttempts >= 5 && !this.isLocked()) {
    this.lockUntil = Date.now() + 15 * 60 * 1000; // 15 minutes
  }
  
  return await this.save();
};

// Réinitialiser les tentatives de connexion
userSchema.methods.resetLoginAttempts = async function() {
  this.loginAttempts = 0;
  this.lockUntil = undefined;
  return await this.save();
};

module.exports = mongoose.model('User', userSchema);

