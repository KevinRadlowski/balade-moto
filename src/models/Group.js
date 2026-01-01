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
      enum: ['admin', 'membre'],
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
  }]
}, {
  timestamps: true
});

// Index pour améliorer les performances
groupSchema.index({ createur: 1 });
groupSchema.index({ visibilite: 1 });
groupSchema.index({ 'membres.userId': 1 });
groupSchema.index({ 'bannedUsers.userId': 1 });

// Méthode pour vérifier si un utilisateur est membre
groupSchema.methods.isMember = function(userId) {
  return this.membres.some(m => {
    // m.userId peut être un ObjectId ou un objet peuplé
    const membreUserId = m.userId._id ? m.userId._id.toString() : m.userId.toString();
    return membreUserId === userId.toString();
  });
};

// Méthode pour vérifier si un utilisateur est admin
groupSchema.methods.isAdmin = function(userId) {
  // Le créateur est toujours admin
  if (this.createur.toString() === userId.toString()) {
    return true;
  }
  // Vérifier si l'utilisateur est dans la liste des membres avec le rôle admin
  return this.membres.some(
    m => m.userId.toString() === userId.toString() && m.role === 'admin'
  );
};

// Méthode pour obtenir le rôle d'un utilisateur
groupSchema.methods.getUserRole = function(userId) {
  const membre = this.membres.find(m => m.userId.toString() === userId.toString());
  return membre ? membre.role : null;
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
  next();
});

module.exports = mongoose.model('Group', groupSchema);

