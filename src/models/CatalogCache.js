const mongoose = require('mongoose');

const catalogCacheSchema = new mongoose.Schema({
  key: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  data: {
    type: mongoose.Schema.Types.Mixed,
    required: true
  },
  expiresAt: {
    type: Date,
    required: true,
    index: { expireAfterSeconds: 0 } // TTL index pour expiration automatique
  }
}, {
  timestamps: true
});

// Méthode statique pour générer une clé de cache
catalogCacheSchema.statics.generateKey = function(provider, ...params) {
  // provider peut être 'carapi', 'carquery', etc.
  return `${provider}:${params.join(':')}`;
};

// Méthode statique pour récupérer ou créer un cache
catalogCacheSchema.statics.getOrSet = async function(key, fetchFn, ttlHours = 24) {
  const cached = await this.findOne({ key });
  
  // Si le cache existe et n'est pas expiré
  if (cached && cached.expiresAt > new Date()) {
    const dataLength = Array.isArray(cached.data) ? cached.data.length : 'not array';
    console.log('[CatalogCache] Cache hit:', { key, dataLength });
    
    // Si le cache contient un tableau vide, forcer un refresh
    if (Array.isArray(cached.data) && cached.data.length === 0) {
      console.log('[CatalogCache] Cache contient 0 éléments, forcer refresh:', { key });
      // Supprimer le cache vide et continuer pour faire un nouvel appel
      await this.deleteOne({ key });
    } else {
      // Cache valide, retourner les données
      return cached.data;
    }
  }
  
  console.log('[CatalogCache] Cache miss, fetching:', { key });
  
  // Récupérer les données
  const data = await fetchFn();
  
  const dataLength = Array.isArray(data) ? data.length : 'N/A';
  console.log('[CatalogCache] Data fetched:', {
    key,
    dataType: Array.isArray(data) ? 'array' : typeof data,
    dataLength
  });
  
  // Ne pas mettre en cache un tableau vide (probablement une erreur)
  if (Array.isArray(data) && data.length === 0) {
    console.warn('[CatalogCache] Résultat vide, ne pas mettre en cache:', { key });
    return data; // Retourner quand même les données vides
  }
  
  // Mettre en cache uniquement si les données ne sont pas vides
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + ttlHours);
  
  await this.findOneAndUpdate(
    { key },
    { data, expiresAt },
    { upsert: true, new: true }
  );
  
  return data;
};

module.exports = mongoose.model('CatalogCache', catalogCacheSchema);

