const mongoose = require('mongoose');

const groupReadSchema = new mongoose.Schema({
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
  lastReadAt: {
    type: Date,
    required: true,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index composé unique pour éviter les doublons
groupReadSchema.index({ groupId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model('GroupRead', groupReadSchema);

