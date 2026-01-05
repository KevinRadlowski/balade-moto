const mongoose = require('mongoose');

const reputationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'L\'utilisateur est requis'],
    unique: true,
    index: true
  },
  score: {
    type: Number,
    default: 0,
    min: [0, 'Le score ne peut pas être négatif'],
    max: [100, 'Le score ne peut pas dépasser 100']
  },
  rideCount: {
    type: Number,
    default: 0,
    min: [0, 'Le nombre de balades ne peut pas être négatif']
  },
  punctualityScore: {
    type: Number,
    default: 50,
    min: [0, 'Le score de ponctualité ne peut pas être négatif'],
    max: [100, 'Le score de ponctualité ne peut pas dépasser 100']
  },
  cancellationRate: {
    type: Number,
    default: 0,
    min: [0, 'Le taux d\'annulation ne peut pas être négatif'],
    max: [100, 'Le taux d\'annulation ne peut pas dépasser 100']
  },
  feedbackCount: {
    type: Number,
    default: 0,
    min: [0, 'Le nombre de feedbacks ne peut pas être négatif']
  },
  level: {
    type: String,
    enum: ['bronze', 'silver', 'gold', 'platinum'],
    default: 'bronze',
    index: true
  }
}, {
  timestamps: true
});

// Index pour améliorer les performances
reputationSchema.index({ score: -1 });
reputationSchema.index({ level: 1, score: -1 });

// Méthode pour mettre à jour le niveau basé sur le score
reputationSchema.methods.updateLevel = function() {
  if (this.score >= 90) {
    this.level = 'platinum';
  } else if (this.score >= 75) {
    this.level = 'gold';
  } else if (this.score >= 60) {
    this.level = 'silver';
  } else {
    this.level = 'bronze';
  }
};

// Middleware pre-save pour mettre à jour le niveau
reputationSchema.pre('save', function(next) {
  if (this.isModified('score')) {
    this.updateLevel();
  }
  next();
});

module.exports = mongoose.model('Reputation', reputationSchema);


