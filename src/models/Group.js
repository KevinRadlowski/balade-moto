const mongoose = require('mongoose');

const groupSchema = new mongoose.Schema({
  nom: {
    type: String,
    required: [true, 'Le nom du groupe est requis'],
    trim: true,
    maxlength: [100, 'Le nom ne peut pas dépasser 100 caractères']
  },
  description: {
    type: String,
    trim: true,
    maxlength: [500, 'La description ne peut pas dépasser 500 caractères']
  },
  visibilite: {
    type: String,
    enum: ['publique', 'privee'],
    default: 'publique'
  },
  createur: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'Le créateur est requis']
  },
  membres: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    role: {
      type: String,
      enum: ['admin', 'moderateur', 'membre'],
      default: 'membre'
    },
    dateAjout: {
      type: Date,
      default: Date.now
    }
  }],
  bannedUsers: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    bannedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    reason: {
      type: String,
      trim: true
    },
    bannedAt: {
      type: Date,
      default: Date.now
    }
  }],
  // Localisation géographique (optionnel)
  location: {
    city: {
      type: String,
      trim: true,
      index: true
    },
    departmentCode: {
      type: String,
      trim: true,
      index: true
    },
    departmentName: {
      type: String,
      trim: true,
      index: true
    },
    regionName: {
      type: String,
      trim: true,
      index: true
    },
    countryCode: {
      type: String,
      trim: true,
      index: true
    },
    geo: {
      type: {
        type: String,
        enum: ['Point']
        // Pas de default: on ne crée geo que si coordinates est fourni
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        default: undefined
      }
    }
  }
}, {
  timestamps: true
});

// Index pour améliorer les performances
groupSchema.index({ createur: 1 });
groupSchema.index({ visibilite: 1 });
groupSchema.index({ 'membres.userId': 1 });
groupSchema.index({ 'bannedUsers.userId': 1 });
// Index géospatial pour les recherches "près de moi" (seulement si location.geo existe)
groupSchema.index({ 'location.geo': '2dsphere' }, { sparse: true });
// Index pour tri et pagination
groupSchema.index({ createdAt: -1 });
groupSchema.index({ visibilite: 1, createdAt: -1 }); // Compound pour listing filtré

// Méthode pour vérifier si un utilisateur est membre
groupSchema.methods.isMember = function(userId) {
  return this.membres.some(m => {
    // m.userId peut être un ObjectId ou un objet peuplé
    const membreUserId = m.userId._id ? m.userId._id.toString() : m.userId.toString();
    return membreUserId === userId.toString();
  });
};

// Méthode pour vérifier si un utilisateur est le créateur
groupSchema.methods.isCreator = function(userId) {
  return this.createur.toString() === userId.toString();
};

// Méthode pour vérifier si un utilisateur est admin
groupSchema.methods.isAdmin = function(userId) {
  // Le créateur est toujours admin
  if (this.isCreator(userId)) {
    return true;
  }
  // Vérifier si l'utilisateur est dans la liste des membres avec le rôle admin
  return this.membres.some(
    m => m.userId.toString() === userId.toString() && m.role === 'admin'
  );
};

// Méthode pour vérifier si un utilisateur est modérateur
groupSchema.methods.isModerator = function(userId) {
  // Le créateur et les admins sont considérés comme ayant les permissions de modérateur
  if (this.isCreator(userId) || this.isAdmin(userId)) {
    return true;
  }
  // Vérifier si l'utilisateur est dans la liste des membres avec le rôle modérateur
  return this.membres.some(
    m => m.userId.toString() === userId.toString() && m.role === 'moderateur'
  );
};

// Méthode pour obtenir le rôle d'un utilisateur
groupSchema.methods.getUserRole = function(userId) {
  // Le créateur a un rôle spécial
  if (this.isCreator(userId)) {
    return 'createur';
  }
  const membre = this.membres.find(m => m.userId.toString() === userId.toString());
  return membre ? membre.role : null;
};

// Méthode pour vérifier les permissions
// Retourne un objet avec les permissions de l'utilisateur
groupSchema.methods.getUserPermissions = function(userId) {
  const isCreator = this.isCreator(userId);
  const isAdmin = this.isAdmin(userId);
  const isModerator = this.isModerator(userId);
  
  return {
    canEditGroupInfo: isCreator || isAdmin, // Créateur et admin peuvent modifier titre/description
    canPromoteMembers: isCreator, // Seul le créateur peut promouvoir en admin/modérateur
    canAddMembers: isCreator || isAdmin, // Créateur et admin peuvent ajouter des membres
    canRemoveMembers: isCreator || isAdmin || isModerator, // Tous peuvent retirer des membres
    canBanUsers: isCreator || isAdmin || isModerator, // Tous peuvent bannir
    canUnbanUsers: isCreator || isAdmin || isModerator, // Tous peuvent débannir
    canDeleteGroup: isCreator, // Seul le créateur peut supprimer le groupe
    canManageMembers: isCreator || isAdmin || isModerator // Tous peuvent gérer les membres (retirer, bannir)
  };
};

// Méthode pour vérifier si un utilisateur est banni
groupSchema.methods.isBanned = function(userId) {
  return this.bannedUsers.some(b => b.userId.toString() === userId.toString());
};

// Le créateur est automatiquement admin
groupSchema.pre('save', function(next) {
  if (this.isNew) {
    const createurIsMember = this.membres.some(
      m => m.userId.toString() === this.createur.toString()
    );
    if (!createurIsMember) {
      this.membres.push({
        userId: this.createur,
        role: 'admin',
        dateAjout: new Date()
      });
    }
  }
  
  // Nettoyer location.geo si coordinates est manquant (évite erreur index géospatial)
  if (this.location) {
    if (this.location.geo) {
      // Si geo existe mais coordinates est invalide, supprimer geo
      if (!this.location.geo.coordinates || 
          !Array.isArray(this.location.geo.coordinates) || 
          this.location.geo.coordinates.length < 2) {
        delete this.location.geo;
      }
    }
    
    // Si location n'a plus de champs valides (ou seulement geo qui a été supprimé), supprimer location entièrement
    const locationKeys = Object.keys(this.location).filter(key => this.location[key] !== undefined);
    if (locationKeys.length === 0) {
      this.location = undefined;
    }
  }
  
  next();
});

module.exports = mongoose.model('Group', groupSchema);

