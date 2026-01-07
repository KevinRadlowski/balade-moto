const User = require('../models/User');

/**
 * Service centralisé pour la gestion des abonnements premium
 */

/**
 * Vérifie si l'abonnement premium d'un utilisateur est actif
 * @param {object} user - L'utilisateur (doit avoir subscription.isPremium et subscription.premiumExpiresAt)
 * @returns {boolean} true si:
 *   - user.subscription.isPremium === true ET (
 *       premiumExpiresAt est null (premium permanent)
 *       OU premiumExpiresAt >= now (premium à durée limitée)
 *     )
 */
function isPremiumActive(user) {
  if (!user || !user.subscription) {
    return false;
  }

  // Premium doit être activé
  if (user.subscription.isPremium !== true) {
    return false;
  }

  const expiresAt = user.subscription.premiumExpiresAt;
  
  // Premium permanent (premiumExpiresAt = null)
  if (!expiresAt) {
    return true;
  }

  // Premium à durée limitée : vérifier que la date d'expiration est >= maintenant
  const now = new Date();
  const expirationDate = new Date(expiresAt);
  
  return expirationDate >= now;
}

/**
 * Normalise l'état de l'abonnement premium d'un utilisateur
 * - Si isPremium=true et premiumExpiresAt=null => NE PAS forcer à false (premium permanent)
 * - Si premiumExpiresAt est passé => isPremium=false, premiumSource=null, premiumExpiresAt=null
 * - Si premiumExpiresAt est futur => isPremium=true (et sauvegarde si nécessaire)
 * @param {object} user - L'utilisateur (peut être un document Mongoose ou un objet simple)
 * @returns {Promise<object>} L'utilisateur mis à jour
 */
async function normalizeSubscription(user) {
  if (!user || !user.subscription) {
    return user;
  }

  const expiresAt = user.subscription.premiumExpiresAt;
  const now = new Date();
  let needsSave = false;

  if (!expiresAt) {
    // Pas de date d'expiration
    if (user.subscription.isPremium === true) {
      // Premium permanent : ne pas modifier (isPremium=true, premiumExpiresAt=null)
      // Ne rien faire, c'est correct
    } else {
      // Pas premium : s'assurer que tout est à null/false
      if (user.subscription.isPremium !== false || user.subscription.premiumSource !== null) {
        user.subscription.isPremium = false;
        user.subscription.premiumSource = null;
        needsSave = true;
      }
    }
  } else {
    const expirationDate = new Date(expiresAt);
    
    if (expirationDate < now) {
      // Premium expiré : nettoyer
      if (user.subscription.isPremium !== false || user.subscription.premiumSource !== null || user.subscription.premiumExpiresAt !== null) {
        user.subscription.isPremium = false;
        user.subscription.premiumSource = null;
        user.subscription.premiumExpiresAt = null;
        needsSave = true;
      }
    } else {
      // Premium actif (date future) : s'assurer que isPremium=true
      if (user.subscription.isPremium !== true) {
        user.subscription.isPremium = true;
        needsSave = true;
      }
    }
  }

  // Sauvegarder si nécessaire (uniquement si c'est un document Mongoose)
  if (needsSave && user.save && typeof user.save === 'function') {
    await user.save();
  }

  return user;
}

/**
 * Accorde des jours de premium à un utilisateur
 * - Si déjà premium actif : ajoute les jours à la date d'expiration actuelle
 * - Si non premium : ajoute les jours à maintenant
 * Met également isPremium=true et premiumSource=source
 * @param {string|ObjectId} userId - L'ID de l'utilisateur
 * @param {number} days - Nombre de jours à ajouter
 * @param {string} source - Source du premium ('purchase', 'referral_reward', 'admin_grant')
 * @returns {Promise<object>} L'utilisateur mis à jour
 */
async function grantPremiumDays(userId, days, source) {
  if (!userId) {
    throw new Error('userId est requis');
  }
  if (!days || days <= 0) {
    throw new Error('days doit être un nombre positif');
  }
  if (!source || !['purchase', 'referral_reward', 'admin_grant', 'promo_code'].includes(source)) {
    throw new Error('source doit être l\'un de: purchase, referral_reward, admin_grant, promo_code');
  }

  const user = await User.findById(userId);
  if (!user) {
    throw new Error('Utilisateur non trouvé');
  }

  const now = new Date();
  let newExpirationDate;

  // Initialiser subscription si nécessaire
  if (!user.subscription) {
    user.subscription = {
      isPremium: false,
      premiumExpiresAt: null,
      premiumSource: null
    };
  }

  const currentExpiresAt = user.subscription.premiumExpiresAt;
  const isPremiumActive = user.subscription.isPremium === true;
  
  if (currentExpiresAt) {
    // Premium à durée limitée
    const expirationDate = new Date(currentExpiresAt);
    if (expirationDate >= now) {
      // Premium déjà actif : ajouter les jours à la date d'expiration actuelle
      newExpirationDate = new Date(expirationDate);
      newExpirationDate.setDate(newExpirationDate.getDate() + days);
    } else {
      // Premium expiré : ajouter les jours à maintenant
      newExpirationDate = new Date(now);
      newExpirationDate.setDate(newExpirationDate.getDate() + days);
    }
  } else if (isPremiumActive) {
    // Premium permanent : convertir en premium à durée limitée en ajoutant les jours à maintenant
    newExpirationDate = new Date(now);
    newExpirationDate.setDate(newExpirationDate.getDate() + days);
  } else {
    // Pas de premium actif : ajouter les jours à maintenant
    newExpirationDate = new Date(now);
    newExpirationDate.setDate(newExpirationDate.getDate() + days);
  }

  // Mettre à jour l'abonnement
  user.subscription.premiumExpiresAt = newExpirationDate;
  user.subscription.isPremium = true;
  user.subscription.premiumSource = source;

  await user.save();

  return user;
}

/**
 * Accorde des mois de premium à un utilisateur (ajout de mois calendaires)
 * - Si déjà premium actif : ajoute les mois à la date d'expiration actuelle
 * - Si non premium : ajoute les mois à maintenant
 * - Si premium permanent (premiumExpiresAt=null) : convertit en premium à durée limitée
 * Met également isPremium=true et premiumSource=source
 * @param {string|ObjectId} userId - L'ID de l'utilisateur
 * @param {number} months - Nombre de mois à ajouter
 * @param {string} source - Source du premium ('purchase', 'referral_reward', 'admin_grant', 'promo_code')
 * @returns {Promise<object>} L'utilisateur mis à jour
 */
async function grantPremiumMonths(userId, months, source) {
  if (!userId) {
    throw new Error('userId est requis');
  }
  if (!months || months <= 0) {
    throw new Error('months doit être un nombre positif');
  }
  if (!source || !['purchase', 'referral_reward', 'admin_grant', 'promo_code'].includes(source)) {
    throw new Error('source doit être l\'un de: purchase, referral_reward, admin_grant, promo_code');
  }

  const user = await User.findById(userId);
  if (!user) {
    throw new Error('Utilisateur non trouvé');
  }

  const now = new Date();
  let newExpirationDate;

  // Initialiser subscription si nécessaire
  if (!user.subscription) {
    user.subscription = {
      isPremium: false,
      premiumExpiresAt: null,
      premiumSource: null
    };
  }

  const currentExpiresAt = user.subscription.premiumExpiresAt;
  const isPremiumActive = user.subscription.isPremium === true;
  
  if (currentExpiresAt) {
    // Premium à durée limitée
    const expirationDate = new Date(currentExpiresAt);
    if (expirationDate >= now) {
      // Premium déjà actif : ajouter les mois à la date d'expiration actuelle
      newExpirationDate = new Date(expirationDate);
      newExpirationDate.setMonth(newExpirationDate.getMonth() + months);
    } else {
      // Premium expiré : ajouter les mois à maintenant
      newExpirationDate = new Date(now);
      newExpirationDate.setMonth(newExpirationDate.getMonth() + months);
    }
  } else if (isPremiumActive) {
    // Premium permanent : convertir en premium à durée limitée en ajoutant les mois à maintenant
    newExpirationDate = new Date(now);
    newExpirationDate.setMonth(newExpirationDate.getMonth() + months);
  } else {
    // Pas de premium actif : ajouter les mois à maintenant
    newExpirationDate = new Date(now);
    newExpirationDate.setMonth(newExpirationDate.getMonth() + months);
  }

  // Mettre à jour l'abonnement
  user.subscription.premiumExpiresAt = newExpirationDate;
  user.subscription.isPremium = true;
  user.subscription.premiumSource = source;

  await user.save();

  return user;
}

/**
 * Accorde un premium permanent à un utilisateur
 * - subscription.isPremium = true
 * - subscription.premiumExpiresAt = null
 * - subscription.premiumSource = source
 * @param {string|ObjectId} userId - L'ID de l'utilisateur
 * @param {string} source - Source du premium ('purchase', 'referral_reward', 'admin_grant', 'promo_code')
 * @returns {Promise<object>} L'utilisateur mis à jour
 */
async function grantPremiumPermanent(userId, source) {
  if (!userId) {
    throw new Error('userId est requis');
  }
  if (!source || !['purchase', 'referral_reward', 'admin_grant', 'promo_code'].includes(source)) {
    throw new Error('source doit être l\'un de: purchase, referral_reward, admin_grant, promo_code');
  }

  const user = await User.findById(userId);
  if (!user) {
    throw new Error('Utilisateur non trouvé');
  }

  // Initialiser subscription si nécessaire
  if (!user.subscription) {
    user.subscription = {
      isPremium: false,
      premiumExpiresAt: null,
      premiumSource: null
    };
  }

  // Mettre à jour pour premium permanent
  user.subscription.isPremium = true;
  user.subscription.premiumExpiresAt = null; // null = permanent
  user.subscription.premiumSource = source;

  await user.save();

  return user;
}

module.exports = {
  isPremiumActive,
  normalizeSubscription,
  grantPremiumDays,
  grantPremiumMonths,
  grantPremiumPermanent,
};
