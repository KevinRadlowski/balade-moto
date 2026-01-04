const mongoose = require('mongoose');

const catalogApprovedEntrySchema = new mongoose.Schema({
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
  createdByAdminId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  }
}, {
  timestamps: true
});

// Index unique pour éviter les doublons
catalogApprovedEntrySchema.index(
  { type: 1, year: 1, make: 1, model: 1 },
  { unique: true }
);

// Index pour les requêtes de récupération
catalogApprovedEntrySchema.index({ type: 1, year: 1 });

module.exports = mongoose.model('CatalogApprovedEntry', catalogApprovedEntrySchema);

