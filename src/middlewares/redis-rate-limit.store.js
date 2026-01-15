/**
 * Redis store pour express-rate-limit
 * Implémente fail-open : fallback vers memory store si Redis indisponible
 */

const { isRedisEnabled, getRedisClient } = require('../config/redis');

/**
 * Store en mémoire (fallback)
 */
class MemoryStore {
  constructor() {
    this.hits = new Map();
  }

  async increment(key) {
    const count = (this.hits.get(key) || 0) + 1;
    this.hits.set(key, count);
    return {
      totalHits: count,
      resetTime: undefined
    };
  }

  async decrement(key) {
    const count = this.hits.get(key) || 0;
    if (count > 0) {
      this.hits.set(key, count - 1);
    }
  }

  async resetKey(key) {
    this.hits.delete(key);
  }

  async shutdown() {
    this.hits.clear();
  }
}

/**
 * Redis store pour express-rate-limit
 */
class RedisStore {
  constructor(options = {}) {
    this.prefix = options.prefix || 'rl:';
    this.redis = getRedisClient();
    this.memoryStore = new MemoryStore(); // Fallback
  }

  async increment(key) {
    // Si Redis n'est pas disponible, utiliser memory store
    if (!isRedisEnabled() || !this.redis) {
      return await this.memoryStore.increment(key);
    }

    try {
      const fullKey = `${this.prefix}${key}`;
      const count = await this.redis.incr(fullKey);
      
      // Si c'est la première requête pour cette clé, définir l'expiration
      if (count === 1) {
        const windowMs = options.windowMs || 60000;
        await this.redis.pexpire(fullKey, windowMs);
      }
      
      // Récupérer le TTL pour resetTime
      const ttl = await this.redis.pttl(fullKey);
      const resetTime = ttl > 0 ? new Date(Date.now() + ttl) : undefined;
      
      return {
        totalHits: count,
        resetTime: resetTime
      };
    } catch (error) {
      // En cas d'erreur Redis, fallback vers memory store
      console.warn('⚠️  Redis store error, fallback to memory:', error.message);
      return await this.memoryStore.increment(key);
    }
  }

  async decrement(key) {
    if (!isRedisEnabled() || !this.redis) {
      return await this.memoryStore.decrement(key);
    }

    try {
      const fullKey = `${this.prefix}${key}`;
      await this.redis.decr(fullKey);
    } catch (error) {
      console.warn('⚠️  Redis store error, fallback to memory:', error.message);
      await this.memoryStore.decrement(key);
    }
  }

  async resetKey(key) {
    if (!isRedisEnabled() || !this.redis) {
      return await this.memoryStore.resetKey(key);
    }

    try {
      const fullKey = `${this.prefix}${key}`;
      await this.redis.del(fullKey);
    } catch (error) {
      console.warn('⚠️  Redis store error, fallback to memory:', error.message);
      await this.memoryStore.resetKey(key);
    }
  }

  async shutdown() {
    if (this.memoryStore) {
      await this.memoryStore.shutdown();
    }
    // Ne pas fermer le client Redis ici (géré par config/redis.js)
  }
}

/**
 * Factory pour créer un store Redis avec fail-open
 * @param {object} options - Options pour express-rate-limit
 * @returns {RedisStore|MemoryStore}
 */
function createRedisStore(options = {}) {
  if (isRedisEnabled()) {
    return new RedisStore(options);
  } else {
    console.log('ℹ️  Rate limiting: Utilisation du memory store (Redis non disponible)');
    return new MemoryStore();
  }
}

module.exports = {
  RedisStore,
  MemoryStore,
  createRedisStore
};

