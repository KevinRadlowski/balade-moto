const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  type: {
    type: String,
    required: true,
    enum: [
      'ride_cancelled',
      'ride_postponed',
      'ride_rescheduled',
      'ride_reminder',
      'ride_invitation',
      'ride_request_approved',
      'ride_request_rejected',
      'weather_alert',
      'mention', // Nouveau : mention dans un message
      'message_reported', // Nouveau : message signalé
      'general'
    ],
    index: true
  },
  title: {
    type: String,
    required: true,
    maxlength: [200, 'Le titre ne peut pas dépasser 200 caractères']
  },
  message: {
    type: String,
    required: true,
    maxlength: [1000, 'Le message ne peut pas dépasser 1000 caractères']
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  read: {
    type: Boolean,
    default: false,
    index: true
  },
  readAt: {
    type: Date,
    default: null
  }
}, {
  timestamps: true
});

// Index composé pour les requêtes fréquentes
notificationSchema.index({ user: 1, read: 1, createdAt: -1 });
notificationSchema.index({ user: 1, type: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);

