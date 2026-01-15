/**
 * Rate limiting pour les requêtes géospatiales et autres endpoints
 * Utilise express-rate-limit avec Redis (fail-open vers memory store)
 */

const rateLimit = require('express-rate-limit');
const { ipKeyGenerator } = require('express-rate-limit');
const { createRedisStore } = require('./redis-rate-limit.store');

const isDevelopment = process.env.NODE_ENV === 'development';

/**
 * Crée un rate limiter configurable
 * @param {number} maxRequests - Nombre max de requêtes
 * @param {number} windowMs - Fenêtre de temps en ms
 * @param {string} prefix - Préfixe pour la clé Redis
 * @param {function} keyGenerator - Fonction pour générer la clé (optionnel)
 * @returns {Function} Middleware Express
 */
const rateLimitMiddleware = (maxRequests = 10, windowMs = 60000, prefix = 'geospatial:', keyGenerator = null) => {
  // En développement, multiplier la limite par 5 pour faciliter les tests
  const effectiveMaxRequests = isDevelopment ? maxRequests * 5 : maxRequests;
  
  return rateLimit({
    windowMs: windowMs,
    max: effectiveMaxRequests,
    store: createRedisStore({ prefix, windowMs }),
    keyGenerator: keyGenerator || ((req) => {
      // Utiliser l'ID utilisateur si authentifié, sinon l'IP (avec gestion IPv6)
      if (req.user?._id) {
        return req.user._id.toString();
      }
      // Utiliser ipKeyGenerator pour gérer correctement IPv6
      return ipKeyGenerator(req.ip);
    }),
    message: {
      success: false,
      message: `Trop de requêtes. Veuillez réessayer dans ${Math.ceil(windowMs / 1000)} seconde(s)`,
      retryAfter: Math.ceil(windowMs / 1000)
    },
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: false,
    skipFailedRequests: false,
  });
};

// Fonction utilitaire pour réinitialiser le rate limiting (utile en développement)
// Note: Avec Redis, cette fonction nécessiterait d'accéder au store directement
// Pour l'instant, on la garde pour compatibilité mais elle ne fonctionne qu'avec memory store
const resetRateLimit = async (userId = null) => {
  // Cette fonction est principalement utile en développement avec memory store
  // En production avec Redis, utiliser redis-cli ou une interface admin
  console.warn('resetRateLimit: Fonction limitée avec Redis. Utilisez redis-cli pour réinitialiser.');
};

module.exports = rateLimitMiddleware;
module.exports.resetRateLimit = resetRateLimit;



