/**
 * Cache simple en mémoire (LRU-like) pour les requêtes Google Maps
 * Pour la production, utiliser Redis ou un cache distribué
 */

class SimpleCache {
  constructor(maxSize = 100, ttl = 5 * 60 * 1000) { // 5 minutes par défaut
    this.cache = new Map();
    this.maxSize = maxSize;
    this.ttl = ttl;
  }

  /**
   * Génère une clé de cache à partir des paramètres
   */
  _generateKey(params) {
    return JSON.stringify(params);
  }

  /**
   * Vérifie si une entrée est expirée
   */
  _isExpired(entry) {
    return Date.now() - entry.timestamp > this.ttl;
  }

  /**
   * Nettoie les entrées expirées
   */
  _cleanExpired() {
    for (const [key, entry] of this.cache.entries()) {
      if (this._isExpired(entry)) {
        this.cache.delete(key);
      }
    }
  }

  /**
   * Nettoie les entrées les plus anciennes si le cache est plein
   */
  _evictOldest() {
    if (this.cache.size >= this.maxSize) {
      // Supprimer les 10% les plus anciennes
      const entries = Array.from(this.cache.entries())
        .sort((a, b) => a[1].timestamp - b[1].timestamp);
      
      const toDelete = Math.ceil(this.maxSize * 0.1);
      for (let i = 0; i < toDelete; i++) {
        this.cache.delete(entries[i][0]);
      }
    }
  }

  /**
   * Récupère une valeur du cache
   */
  get(params) {
    this._cleanExpired();
    const key = this._generateKey(params);
    const entry = this.cache.get(key);
    
    if (!entry) {
      return null;
    }
    
    if (this._isExpired(entry)) {
      this.cache.delete(key);
      return null;
    }
    
    return entry.value;
  }

  /**
   * Stocke une valeur dans le cache
   */
  set(params, value) {
    this._cleanExpired();
    this._evictOldest();
    
    const key = this._generateKey(params);
    this.cache.set(key, {
      value,
      timestamp: Date.now()
    });
  }

  /**
   * Vide le cache
   */
  clear() {
    this.cache.clear();
  }

  /**
   * Retourne la taille actuelle du cache
   */
  size() {
    this._cleanExpired();
    return this.cache.size;
  }
}

// Instances de cache pour chaque type de requête
const routeCache = new SimpleCache(50, 5 * 60 * 1000); // 5 min pour les routes
const geocodeCache = new SimpleCache(100, 10 * 60 * 1000); // 10 min pour le géocodage
const reverseGeocodeCache = new SimpleCache(100, 10 * 60 * 1000); // 10 min pour le géocodage inverse

module.exports = {
  routeCache,
  geocodeCache,
  reverseGeocodeCache
};





