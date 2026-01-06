const User = require('../models/User');

/**
 * Service centralisé pour la gestion des abonnements premium
 */

/**
 * Vérifie si l'abonnement premium d'un utilisateur est actif
 * @param {object} user - L'utilisateur (doit avoir subscription.premiumExpiresAt)
 * @returns {boolean} true si premiumExpiresAt est une date future (>= now)
 */
function isPremiumActive(user) {
  if (!user || !user.subscription) {
    return false;
  }

  const expiresAt = user.subscription.premiumExpiresAt;
  if (!expiresAt) {
    return false;
  }

  const now = new Date();
  const expirationDate = new Date(expiresAt);
  
  // Premium actif si la date d'expiration est >= maintenant
  return expirationDate >= now;
}

/**
 * Normalise l'état de l'abonnement premium d'un utilisateur
 * - Si expiresAt est passé -> met subscription.isPremium=false et premiumSource=null (et sauvegarde)
 * - Si expiresAt est futur -> met subscription.isPremium=true (et sauvegarde si nécessaire)
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
    // Pas de date d'expiration = pas premium
    if (user.subscription.isPremium !== false) {
      user.subscription.isPremium = false;
      user.subscription.premiumSource = null;
      needsSave = true;
    }
  } else {
    const expirationDate = new Date(expiresAt);
    
    if (expirationDate < now) {
      // Premium expiré
      if (user.subscription.isPremium !== false || user.subscription.premiumSource !== null) {
        user.subscription.isPremium = false;
        user.subscription.premiumSource = null;
        needsSave = true;
      }
    } else {
      // Premium actif (date future)
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
  if (!source || !['purchase', 'referral_reward', 'admin_grant'].includes(source)) {
    throw new Error('source doit être l\'un de: purchase, referral_reward, admin_grant');
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
  
  if (currentExpiresAt) {
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

module.exports = {
  isPremiumActive,
  normalizeSubscription,
  grantPremiumDays,
};
