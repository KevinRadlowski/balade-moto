// Middleware simple de limitation de taux pour les requêtes géospatiales
// Pour une production, utilisez express-rate-limit ou redis

const rateLimitMap = new Map();
const isDevelopment = process.env.NODE_ENV === 'development';

const rateLimitMiddleware = (maxRequests = 10, windowMs = 60000) => {
  return (req, res, next) => {
    // En développement, multiplier la limite par 5 pour faciliter les tests
    const effectiveMaxRequests = isDevelopment ? maxRequests * 5 : maxRequests;
    
    const userId = req.user?._id?.toString();
    if (!userId) {
      return next();
    }

    const now = Date.now();
    const userKey = `geospatial_${userId}`;
    const userRequests = rateLimitMap.get(userKey) || { count: 0, resetTime: now + windowMs };

    // Réinitialiser si la fenêtre est expirée
    if (now > userRequests.resetTime) {
      userRequests.count = 0;
      userRequests.resetTime = now + windowMs;
    }

    // Vérifier la limite
    if (userRequests.count >= effectiveMaxRequests) {
      const remainingTime = Math.ceil((userRequests.resetTime - now) / 1000);
      return res.status(429).json({
        success: false,
        message: `Trop de requêtes. Veuillez réessayer dans ${remainingTime} seconde(s)`,
        retryAfter: remainingTime
      });
    }

    // Incrémenter le compteur
    userRequests.count++;
    rateLimitMap.set(userKey, userRequests);

    // Nettoyer les anciennes entrées périodiquement
    if (Math.random() < 0.01) { // 1% de chance à chaque requête
      for (const [key, value] of rateLimitMap.entries()) {
        if (now > value.resetTime) {
          rateLimitMap.delete(key);
        }
      }
    }

    next();
  };
};

// Fonction utilitaire pour réinitialiser le rate limiting (utile en développement)
const resetRateLimit = (userId = null) => {
  if (userId) {
    const userKey = `geospatial_${userId}`;
    rateLimitMap.delete(userKey);
  } else {
    rateLimitMap.clear();
  }
};

module.exports = rateLimitMiddleware;
module.exports.resetRateLimit = resetRateLimit;



