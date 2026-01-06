/**
 * Configuration centralisée des plans d'abonnement (FREE vs PREMIUM)
 * 
 * IMPORTANT : Free limite la CRÉATION, pas la PARTICIPATION.
 * - Un utilisateur FREE peut participer à autant de balades/groupes qu'il veut
 * - Un utilisateur FREE peut voir toutes les balades/groupes publics
 * - Les limites s'appliquent uniquement à la création de nouvelles ressources
 */

/**
 * Types de plans disponibles
 */
const PLANS = {
  FREE: 'FREE',
  PREMIUM: 'PREMIUM',
};

/**
 * Limites pour le plan FREE
 * Ces limites s'appliquent uniquement lors de la création de nouvelles ressources
 */
const FREE_LIMITS = {
  // Nombre maximum de véhicules au total
  maxVehiclesTotal: 2,
  
  // Nombre maximum de véhicules par type
  maxVehiclesByType: {
    moto: 1,
    voiture: 1,
  },
  
  // Nombre maximum de groupes privés créés
  maxPrivateGroupsCreated: 1,
  
  // Nombre maximum de balades privées créées par mois
  maxPrivateRidesCreatedPerMonth: 2,
  
  // Nombre maximum de photos totales (tous véhicules confondus)
  maxPhotosTotal: 12,
};

/**
 * Limites pour le plan PREMIUM
 * Le plan premium offre des fonctionnalités illimitées
 */
const PREMIUM_LIMITS = {
  unlimited: true,
};

/**
 * Détermine le plan d'un utilisateur à partir de son objet subscription
 * @param {object} user - L'utilisateur (doit avoir subscription.isPremium)
 * @returns {string} Le plan (PLANS.FREE ou PLANS.PREMIUM)
 */
function getUserPlan(user) {
  if (!user || !user.subscription) {
    return PLANS.FREE;
  }
  
  // Vérifier si premium est actif (isPremium = true et pas expiré si premiumExpiresAt existe)
  if (user.subscription.isPremium) {
    if (user.subscription.premiumExpiresAt) {
      const now = new Date();
      const expiresAt = new Date(user.subscription.premiumExpiresAt);
      if (expiresAt > now) {
        return PLANS.PREMIUM;
      }
      // Premium expiré
      return PLANS.FREE;
    }
    // Premium sans date d'expiration (permanent ou admin)
    return PLANS.PREMIUM;
  }
  
  return PLANS.FREE;
}

/**
 * Vérifie si un plan est premium
 * @param {string} plan - Le plan à vérifier
 * @returns {boolean}
 */
function isPremium(plan) {
  return plan === PLANS.PREMIUM;
}

/**
 * Vérifie si un plan est free
 * @param {string} plan - Le plan à vérifier
 * @returns {boolean}
 */
function isFree(plan) {
  return plan === PLANS.FREE;
}

/**
 * Récupère les limites d'un plan
 * @param {string} plan - Le plan (FREE ou PREMIUM)
 * @returns {object} Les limites du plan
 */
function getPlanLimits(plan) {
  if (isPremium(plan)) {
    return PREMIUM_LIMITS;
  }
  return FREE_LIMITS;
}

/**
 * Vérifie si une action est autorisée pour un plan donné
 * @param {string} plan - Le plan de l'utilisateur
 * @param {string} limitKey - La clé de la limite à vérifier (ex: 'maxVehiclesTotal')
 * @param {number} currentCount - Le nombre actuel de ressources
 * @returns {boolean} true si l'action est autorisée
 */
function canPerformAction(plan, limitKey, currentCount = 0) {
  const limits = getPlanLimits(plan);
  
  // Premium = illimité
  if (limits.unlimited) {
    return true;
  }
  
  // Free = vérifier la limite
  const limit = limits[limitKey];
  if (limit === undefined) {
    // Si la limite n'existe pas, on autorise par défaut (sécurité)
    return true;
  }
  
  return currentCount < limit;
}

module.exports = {
  PLANS,
  FREE_LIMITS,
  PREMIUM_LIMITS,
  getUserPlan,
  isPremium,
  isFree,
  getPlanLimits,
  canPerformAction,
};
