const mongoose = require('mongoose');

const groupMuteSchema = new mongoose.Schema({
  groupId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Group',
    required: true,
    index: true
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  mutedUntil: {
    type: Date,
    required: true,
    index: true
  },
  reason: {
    type: String,
    trim: true,
    maxlength: [500, 'La raison ne peut pas dépasser 500 caractères']
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  }
}, {
  timestamps: true
});

// Index composé pour éviter les doublons actifs
groupMuteSchema.index({ groupId: 1, userId: 1, mutedUntil: 1 });
// Index pour vérifier rapidement si un utilisateur est muet
groupMuteSchema.index({ groupId: 1, userId: 1, mutedUntil: 1 });

module.exports = mongoose.model('GroupMute', groupMuteSchema);

