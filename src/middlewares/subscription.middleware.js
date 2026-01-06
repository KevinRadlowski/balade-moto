const subscriptionService = require('../services/subscription.service');

/**
 * Middleware pour normaliser et enrichir les informations d'abonnement de l'utilisateur
 * 
 * Prérequis : req.user doit exister (utiliser après auth.middleware)
 * 
 * Actions :
 * - Normalise l'état de l'abonnement (met à jour isPremium si nécessaire)
 * - Attache req.userIsPremium (boolean)
 * - Attache req.userPlan ('PREMIUM' ou 'FREE')
 */
async function subscriptionMiddleware(req, res, next) {
  try {
    // Vérifier que req.user existe (doit être utilisé après auth.middleware)
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentification requise'
      });
    }

    // Normaliser l'état de l'abonnement (met à jour isPremium si nécessaire)
    await subscriptionService.normalizeSubscription(req.user);

    // Déterminer si le premium est actif
    const userIsPremium = subscriptionService.isPremiumActive(req.user);

    // Attacher les informations d'abonnement à la requête
    req.userIsPremium = userIsPremium;
    req.userPlan = userIsPremium ? 'PREMIUM' : 'FREE';

    next();
  } catch (error) {
    console.error('Erreur dans subscriptionMiddleware:', error);
    next(error);
  }
}

module.exports = subscriptionMiddleware;
