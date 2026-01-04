const authMiddleware = require('./auth.middleware');
const { ForbiddenError } = require('../utils/errors');

/**
 * Middleware qui vérifie que l'utilisateur est authentifié ET admin
 * Utilise authMiddleware puis vérifie le rôle
 */
const requireAdmin = (req, res, next) => {
  // D'abord vérifier l'authentification
  authMiddleware(req, res, (err) => {
    if (err) {
      return next(err);
    }
    
    // Ensuite vérifier le rôle admin
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentification requise'
      });
    }
    
    if (req.user.role !== 'ADMIN') {
      return res.status(403).json({
        success: false,
        message: 'Accès refusé. Seuls les administrateurs peuvent accéder à cette ressource.'
      });
    }
    
    next();
  });
};

module.exports = requireAdmin;

