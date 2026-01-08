const mongoose = require('mongoose');

const routeCacheSchema = new mongoose.Schema({
  // Clé de cache basée sur les paramètres de la route
  cacheKey: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  // Paramètres de la route (pour debug et vérification)
  origin: {
    type: String,
    required: true
  },
  destination: {
    type: String,
    required: true
  },
  waypoints: {
    type: String,
    default: ''
  },
  avoid: {
    type: String,
    default: ''
  },
  // Données de la réponse Google Directions API
  directionsData: {
    type: mongoose.Schema.Types.Mixed,
    required: true
  },
  // Date de création et expiration (optionnel, pour nettoyer les anciens caches)
  createdAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index pour accélérer les recherches
routeCacheSchema.index({ cacheKey: 1 });
routeCacheSchema.index({ createdAt: 1 });

// Index TTL pour nettoyer automatiquement les caches de plus de 1 an
routeCacheSchema.index({ createdAt: 1 }, { expireAfterSeconds: 365 * 24 * 60 * 60 });

module.exports = mongoose.model('RouteCache', routeCacheSchema);

