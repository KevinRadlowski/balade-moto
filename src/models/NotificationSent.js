const mongoose = require('mongoose');

const notificationSentSchema = new mongoose.Schema({
  rideId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    required: true
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  sentAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index unique pour éviter les doublons
notificationSentSchema.index({ rideId: 1, userId: 1 }, { unique: true });

// Index pour le nettoyage automatique (supprimer après 7 jours)
notificationSentSchema.index({ sentAt: 1 }, { expireAfterSeconds: 7 * 24 * 60 * 60 });

module.exports = mongoose.model('NotificationSent', notificationSentSchema);



