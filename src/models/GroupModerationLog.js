const mongoose = require('mongoose');

const groupModerationLogSchema = new mongoose.Schema({
  groupId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Group',
    required: true,
    index: true
  },
  action: {
    type: String,
    enum: ['mute', 'unmute', 'pin', 'unpin', 'report', 'ban', 'unban', 'remove_member'],
    required: true,
    index: true
  },
  targetUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
    index: true
  },
  messageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null,
    index: true
  },
  performedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  meta: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  }
}, {
  timestamps: true
});

// Index pour les requêtes d'audit
groupModerationLogSchema.index({ groupId: 1, createdAt: -1 });
groupModerationLogSchema.index({ performedBy: 1, createdAt: -1 });
groupModerationLogSchema.index({ targetUserId: 1, createdAt: -1 });

module.exports = mongoose.model('GroupModerationLog', groupModerationLogSchema);

