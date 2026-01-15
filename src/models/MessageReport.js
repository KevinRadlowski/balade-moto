const mongoose = require('mongoose');

const messageReportSchema = new mongoose.Schema({
  groupId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Group',
    required: true,
    index: true
  },
  messageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    required: true,
    index: true
  },
  reporterId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  reasonCode: {
    type: String,
    enum: ['SPAM', 'HARASSMENT', 'HATE', 'NUDITY', 'OTHER'],
    required: true
  },
  reasonText: {
    type: String,
    trim: true,
    maxlength: [500, 'Le texte de raison ne peut pas dépasser 500 caractères']
  },
  status: {
    type: String,
    enum: ['open', 'reviewing', 'resolved', 'dismissed'],
    default: 'open',
    index: true
  },
  reviewedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  reviewedAt: {
    type: Date,
    default: null
  },
  resolution: {
    type: String,
    trim: true
  }
}, {
  timestamps: true
});

// Index composé pour éviter les doublons (un utilisateur ne peut reporter qu'une fois)
messageReportSchema.index({ messageId: 1, reporterId: 1 }, { unique: true });
// Index pour les requêtes de modération
messageReportSchema.index({ groupId: 1, status: 1, createdAt: -1 });

module.exports = mongoose.model('MessageReport', messageReportSchema);

