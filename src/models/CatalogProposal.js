const mongoose = require('mongoose');

const catalogProposalSchema = new mongoose.Schema({
  type: {
    type: String,
    required: true,
    enum: ['voiture', 'moto'],
    index: true
  },
  year: {
    type: Number,
    required: true,
    min: 1900,
    max: new Date().getFullYear() + 1,
    index: true
  },
  make: {
    type: String,
    required: true,
    trim: true,
    uppercase: true,
    maxlength: 40,
    index: true
  },
  model: {
    type: String,
    required: true,
    trim: true,
    uppercase: true,
    maxlength: 80,
    index: true
  },
  status: {
    type: String,
    required: true,
    enum: ['PENDING', 'APPROVED', 'REJECTED'],
    default: 'PENDING',
    index: true
  },
  reason: {
    type: String,
    trim: true,
    maxlength: 500,
    default: null
  },
  createdByUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  reviewedByUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
    index: true
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  },
  reviewedAt: {
    type: Date,
    default: null
  }
}, {
  timestamps: true
});

// Index composé pour éviter les doublons PENDING
catalogProposalSchema.index(
  { type: 1, year: 1, make: 1, model: 1, status: 1 },
  { 
    unique: true,
    partialFilterExpression: { status: 'PENDING' }
  }
);

// Index pour les requêtes admin
catalogProposalSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model('CatalogProposal', catalogProposalSchema);

