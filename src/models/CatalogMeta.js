const mongoose = require('mongoose');

const catalogMetaSchema = new mongoose.Schema({
  // Clé unique pour identifier le meta
  key: {
    type: String,
    required: true,
    unique: true,
    default: 'catalog_version'
  },
  // Version (ISO date string)
  version: {
    type: String,
    required: true,
    default: () => new Date().toISOString()
  },
  // Date de dernière mise à jour
  updatedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index pour les requêtes rapides
catalogMetaSchema.index({ key: 1 });

module.exports = mongoose.model('CatalogMeta', catalogMetaSchema);

