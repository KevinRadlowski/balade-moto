/**
 * Configuration Redis pour rate limiting et cache
 * Implémente fail-open : fallback vers memory store si Redis indisponible
 */

let redisClient = null;
let redisEnabled = false;

/**
 * Initialise la connexion Redis
 * @returns {Promise<object|null>} Client Redis ou null si désactivé/erreur
 */
async function initRedis() {
  const redisUrl = process.env.REDIS_URL;
  const redisEnabledEnv = process.env.REDIS_ENABLED !== 'false'; // Par défaut activé si REDIS_URL est défini
  
  // Si REDIS_URL n'est pas défini, Redis est désactivé
  if (!redisUrl) {
    console.log('ℹ️  Redis non configuré (REDIS_URL non défini). Rate limiting en mémoire.');
    return null;
  }
  
  // Si explicitement désactivé
  if (!redisEnabledEnv) {
    console.log('ℹ️  Redis désactivé (REDIS_ENABLED=false). Rate limiting en mémoire.');
    return null;
  }
  
  try {
    // Utiliser ioredis (plus robuste que redis)
    const Redis = require('ioredis');
    
    redisClient = new Redis(redisUrl, {
      retryStrategy: (times) => {
        // Réessayer avec délai exponentiel, max 3 fois
        if (times > 3) {
          console.error('❌ Redis: Échec de connexion après 3 tentatives. Fallback vers memory store.');
          return null; // Arrêter les tentatives
        }
        const delay = Math.min(times * 200, 2000);
        console.warn(`⚠️  Redis: Tentative de reconnexion ${times} dans ${delay}ms...`);
        return delay;
      },
      maxRetriesPerRequest: 3,
      enableReadyCheck: true,
      enableOfflineQueue: true, // Permettre la queue si offline (fallback géré par le store)
      lazyConnect: true, // Connecter à la demande (évite erreur si Redis non disponible)
      connectTimeout: 5000, // Timeout de connexion 5s
      commandTimeout: 3000 // Timeout de commande 3s
    });
    
    // Événements Redis
    redisClient.on('connect', () => {
      console.log('✅ Redis: Connexion établie');
      redisEnabled = true;
    });
    
    redisClient.on('ready', () => {
      console.log('✅ Redis: Prêt à recevoir des commandes');
      redisEnabled = true;
    });
    
    redisClient.on('error', (err) => {
      console.error('❌ Redis: Erreur:', err.message);
      redisEnabled = false;
      // Ne pas arrêter l'application, fallback vers memory store
    });
    
    redisClient.on('close', () => {
      console.warn('⚠️  Redis: Connexion fermée. Fallback vers memory store.');
      redisEnabled = false;
    });
    
    redisClient.on('reconnecting', (delay) => {
      console.log(`🔄 Redis: Reconnexion dans ${delay}ms...`);
    });
    
    // Tester la connexion (avec timeout)
    try {
      await Promise.race([
        redisClient.ping(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), 5000))
      ]);
      console.log('✅ Redis: Connexion testée avec succès');
      redisEnabled = true;
    } catch (pingError) {
      // Si le ping échoue, on continue quand même (lazyConnect)
      console.warn('⚠️  Redis: Ping échoué, mais client créé (lazyConnect). Connexion à la demande.');
      redisEnabled = false;
    }
    
    return redisClient;
  } catch (error) {
    console.error('❌ Redis: Erreur lors de l\'initialisation:', error.message);
    console.log('ℹ️  Fallback vers memory store pour rate limiting.');
    redisEnabled = false;
    redisClient = null;
    return null;
  }
}

/**
 * Récupère le client Redis
 * @returns {object|null} Client Redis ou null
 */
function getRedisClient() {
  return redisClient;
}

/**
 * Vérifie si Redis est disponible
 * @returns {boolean}
 */
function isRedisEnabled() {
  return redisEnabled && redisClient !== null;
}

/**
 * Ferme la connexion Redis
 * @returns {Promise<void>}
 */
async function closeRedis() {
  if (redisClient) {
    try {
      await redisClient.quit();
      console.log('✅ Redis: Connexion fermée proprement');
    } catch (error) {
      console.error('❌ Redis: Erreur lors de la fermeture:', error.message);
    } finally {
      redisClient = null;
      redisEnabled = false;
    }
  }
}

module.exports = {
  initRedis,
  getRedisClient,
  isRedisEnabled,
  closeRedis
};

