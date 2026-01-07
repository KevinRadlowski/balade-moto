const mongoose = require('mongoose');

const referralSchema = new mongoose.Schema({
  referrerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  referredUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
    index: true
  },
  referralCode: {
    type: String,
    required: true,
    index: true
  },
  // Récompenses attribuées
  referrerRewardGranted: {
    type: Boolean,
    default: false
  },
  referredRewardGranted: {
    type: Boolean,
    default: false
  },
  referrerRewardGrantedAt: {
    type: Date,
    default: null
  },
  referredRewardGrantedAt: {
    type: Date,
    default: null
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index composé pour les requêtes fréquentes
referralSchema.index({ referrerId: 1, createdAt: -1 });

module.exports = mongoose.model('Referral', referralSchema);
