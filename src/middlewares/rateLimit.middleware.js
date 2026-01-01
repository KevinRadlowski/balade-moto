// Middleware simple de limitation de taux pour les requêtes géospatiales
// Pour une production, utilisez express-rate-limit ou redis

const rateLimitMap = new Map();

const rateLimitMiddleware = (maxRequests = 10, windowMs = 60000) => {
  return (req, res, next) => {
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
    if (userRequests.count >= maxRequests) {
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

module.exports = rateLimitMiddleware;



