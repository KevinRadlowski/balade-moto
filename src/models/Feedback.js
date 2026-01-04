const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'L\'utilisateur est requis'],
    index: true
  },
  entityType: {
    type: String,
    required: [true, 'Le type d\'entité est requis'],
    enum: ['ride', 'user'],
    index: true
  },
  entityId: {
    type: mongoose.Schema.Types.ObjectId,
    required: [true, 'L\'ID de l\'entité est requis'],
    index: true
  },
  type: {
    type: String,
    required: [true, 'Le type de feedback est requis'],
    enum: ['rating', 'review', 'suggestion', 'bug_report'],
    index: true
  },
  rating: {
    type: Number,
    min: [1, 'La note doit être entre 1 et 5'],
    max: [5, 'La note doit être entre 1 et 5'],
    validate: {
      validator: function(value) {
        // La note est requise si le type est 'rating' ou 'review'
        if (this.type === 'rating' || this.type === 'review') {
          return value !== undefined && value !== null;
        }
        return true;
      },
      message: 'La note est requise pour les types rating et review'
    }
  },
  comment: {
    type: String,
    trim: true,
    maxlength: [2000, 'Le commentaire ne peut pas dépasser 2000 caractères']
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending',
    index: true
  }
}, {
  timestamps: true
});

// Index composé pour améliorer les performances
feedbackSchema.index({ entityType: 1, entityId: 1, createdAt: -1 });
feedbackSchema.index({ userId: 1, createdAt: -1 });
feedbackSchema.index({ status: 1, createdAt: -1 });

// Index pour éviter les doublons (un utilisateur ne peut donner qu'un feedback par entité)
feedbackSchema.index({ userId: 1, entityType: 1, entityId: 1 }, { unique: true });

module.exports = mongoose.model('Feedback', feedbackSchema);

