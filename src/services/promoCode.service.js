const PromoCode = require('../models/PromoCode');
const User = require('../models/User');
const { generateCode, hashCode, extractPrefix, compareCode } = require('../utils/promoCode.util');
const subscriptionService = require('./subscription.service');

/**
 * Service pour la gestion des codes promotionnels
 */

/**
 * Génère un ou plusieurs codes promotionnels
 * @param {object} options - Options de génération
 * @param {string} options.type - Type de code ('DISCOUNT_PERCENT', 'GRANT_PREMIUM_MONTHS', 'GRANT_PREMIUM_PERMANENT')
 * @param {number} options.count - Nombre de codes à générer
 * @param {number} [options.discountPercent] - Pourcentage de réduction (si type = DISCOUNT_PERCENT)
 * @param {number} [options.premiumMonths] - Nombre de mois Premium (si type = GRANT_PREMIUM_MONTHS)
 * @param {Date} [options.validFrom] - Date de début de validité
 * @param {Date} [options.validUntil] - Date de fin de validité
 * @param {number} [options.usageLimit] - Limite d'utilisation par code (défaut: 1)
 * @param {string|ObjectId} options.createdBy - ID de l'admin créateur
 * @param {object} [options.metadata] - Métadonnées libres
 * @returns {Promise<Array>} Tableau de { codePlain, codePrefix, id }
 */
async function generatePromoCodes(options) {
  const {
    type,
    count,
    discountPercent,
    premiumMonths,
    validFrom,
    validUntil,
    usageLimit = 1,
    createdBy,
    metadata = {}
  } = options;

  // Validation des paramètres
  if (!type || !['DISCOUNT_PERCENT', 'GRANT_PREMIUM_MONTHS', 'GRANT_PREMIUM_PERMANENT'].includes(type)) {
    throw new Error('type doit être DISCOUNT_PERCENT, GRANT_PREMIUM_MONTHS ou GRANT_PREMIUM_PERMANENT');
  }

  if (!count || count < 1 || count > 500) {
    throw new Error('count doit être un nombre entre 1 et 500');
  }

  if (type === 'DISCOUNT_PERCENT' && (!discountPercent || discountPercent < 1 || discountPercent > 100)) {
    throw new Error('discountPercent est requis et doit être entre 1 et 100 pour DISCOUNT_PERCENT');
  }

  if (type === 'GRANT_PREMIUM_MONTHS' && (!premiumMonths || premiumMonths < 1)) {
    throw new Error('premiumMonths est requis et doit être >= 1 pour GRANT_PREMIUM_MONTHS');
  }

  if (!createdBy) {
    throw new Error('createdBy est requis');
  }

  const results = [];
  const errors = [];

  // Générer les codes un par un pour éviter les collisions
  for (let i = 0; i < count; i++) {
    try {
      let codePlain;
      let codeHash;
      let codePrefix;
      let attempts = 0;
      const maxAttempts = 10;

      // Générer un code unique
      do {
        codePlain = generateCode();
        codeHash = hashCode(codePlain);
        codePrefix = extractPrefix(codePlain);
        
        // Vérifier l'unicité
        const existing = await PromoCode.findOne({ codeHash });
        if (!existing) {
          break;
        }
        attempts++;
      } while (attempts < maxAttempts);

      if (attempts >= maxAttempts) {
        errors.push(`Impossible de générer un code unique après ${maxAttempts} tentatives`);
        continue;
      }

      // Créer le code promotionnel
      const promoCode = new PromoCode({
        codeHash,
        codePrefix,
        type,
        discountPercent: type === 'DISCOUNT_PERCENT' ? discountPercent : null,
        premiumMonths: type === 'GRANT_PREMIUM_MONTHS' ? premiumMonths : null,
        usageLimit,
        usedCount: 0,
        validFrom: validFrom ? new Date(validFrom) : null,
        validUntil: validUntil ? new Date(validUntil) : null,
        isActive: true,
        createdBy,
        metadata
      });

      await promoCode.save();

      results.push({
        codePlain,
        codePrefix,
        id: promoCode._id.toString()
      });
    } catch (error) {
      errors.push(`Erreur lors de la génération du code ${i + 1}: ${error.message}`);
    }
  }

  if (results.length === 0) {
    throw new Error(`Aucun code n'a pu être généré. Erreurs: ${errors.join('; ')}`);
  }

  return results;
}

/**
 * Utilise un code promotionnel (redemption)
 * @param {object} params - Paramètres de redemption
 * @param {string|ObjectId} params.userId - ID de l'utilisateur
 * @param {string} params.codePlain - Code en clair saisi par l'utilisateur
 * @returns {Promise<object>} Détails de l'application du code
 */
async function redeemPromoCode({ userId, codePlain }) {
  if (!userId) {
    throw new Error('userId est requis');
  }

  if (!codePlain || typeof codePlain !== 'string') {
    throw new Error('codePlain est requis et doit être une chaîne');
  }

  // Normaliser le code (trim, uppercase)
  const normalizedCode = codePlain.trim().toUpperCase();

  // Vérifier le format (RT-XXXX-XXXX-XXXX)
  if (!/^RT-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(normalizedCode)) {
    throw new Error('Format de code invalide. Format attendu: RT-XXXX-XXXX-XXXX');
  }

  const codeHash = hashCode(normalizedCode);
  const codePrefix = extractPrefix(normalizedCode);

  const now = new Date();

  // Trouver le code promotionnel par préfixe (optimisation) puis vérifier le hash
  const promoCode = await PromoCode.findOne({ codePrefix });
  
  if (!promoCode) {
    throw new Error('Code promotionnel non trouvé');
  }

  // Vérifier que le hash correspond (sécurité)
  if (!compareCode(normalizedCode, promoCode.codeHash)) {
    throw new Error('Code promotionnel invalide');
  }

  // Vérifier la validité du code
  if (!promoCode.isActive) {
    throw new Error('Ce code promotionnel est désactivé');
  }

  if (promoCode.validFrom && new Date(promoCode.validFrom) > now) {
    throw new Error('Ce code promotionnel n\'est pas encore valide');
  }

  if (promoCode.validUntil && new Date(promoCode.validUntil) < now) {
    throw new Error('Ce code promotionnel a expiré');
  }

  // Vérifier si l'utilisateur a déjà utilisé ce code
  if (promoCode.hasBeenUsedBy(userId)) {
    throw new Error('Vous avez déjà utilisé ce code promotionnel');
  }

  // Opération atomique : incrémenter usedCount et ajouter à usedBy seulement si les conditions sont remplies
  // Cela garantit l'atomicité sans transaction (fonctionne sur MongoDB standalone)
  const updatedPromoCode = await PromoCode.findOneAndUpdate(
    {
      _id: promoCode._id,
      isActive: true,
      usedCount: { $lt: promoCode.usageLimit }, // Condition atomique : limite non atteinte
      'usedBy.userId': { $ne: userId }, // Condition atomique : utilisateur pas déjà dans usedBy
      $and: [
        {
          $or: [
            { validFrom: null },
            { validFrom: { $lte: now } }
          ]
        },
        {
          $or: [
            { validUntil: null },
            { validUntil: { $gte: now } }
          ]
        }
      ]
    },
    {
      $inc: { usedCount: 1 },
      $push: {
        usedBy: {
          userId: userId,
          usedAt: now,
          details: {}
        }
      }
    },
    {
      new: true,
      runValidators: true
    }
  );

  // Si findOneAndUpdate retourne null, cela signifie que les conditions n'étaient pas remplies
  if (!updatedPromoCode) {
    // Vérifier quelle condition a échoué pour donner un message d'erreur approprié
    if (promoCode.usedCount >= promoCode.usageLimit) {
      throw new Error('Ce code promotionnel a atteint sa limite d\'utilisation');
    }
    // Si l'utilisateur était déjà dans usedBy, cela aurait été détecté plus tôt, mais on vérifie quand même
    if (promoCode.hasBeenUsedBy(userId)) {
      throw new Error('Vous avez déjà utilisé ce code promotionnel');
    }
    // Sinon, c'est probablement une condition de date
    throw new Error('Ce code promotionnel n\'est plus valide');
  }

  // Charger l'utilisateur
  const user = await User.findById(userId);
  if (!user) {
    throw new Error('Utilisateur non trouvé');
  }

    // Initialiser promoBenefits si nécessaire
    if (!user.promoBenefits) {
      user.promoBenefits = {
        activeDiscountPercent: null,
        discountValidUntil: null,
        lastPromoCodePrefix: null,
        history: []
      };
    }

    // Appliquer l'effet selon le type
    let appliedEffect = null;
    let effectDetails = {};

    const subscriptionService = require('./subscription.service');

    switch (updatedPromoCode.type) {
      case 'DISCOUNT_PERCENT':
        // Appliquer la réduction
        user.promoBenefits.activeDiscountPercent = updatedPromoCode.discountPercent;
        
        // Date d'expiration de la réduction
        if (updatedPromoCode.validUntil) {
          user.promoBenefits.discountValidUntil = new Date(updatedPromoCode.validUntil);
        } else {
          // Par défaut: 30 jours à partir de maintenant
          const defaultExpiry = new Date(now);
          defaultExpiry.setDate(defaultExpiry.getDate() + 30);
          user.promoBenefits.discountValidUntil = defaultExpiry;
        }
        
        user.promoBenefits.lastPromoCodePrefix = codePrefix;
        appliedEffect = `Réduction de ${updatedPromoCode.discountPercent}% appliquée`;
        effectDetails = {
          discountPercent: updatedPromoCode.discountPercent,
          validUntil: user.promoBenefits.discountValidUntil
        };
        break;

      case 'GRANT_PREMIUM_MONTHS':
        // Utiliser le service subscription pour ajouter les mois
        const updatedUserMonths = await subscriptionService.grantPremiumMonths(userId, updatedPromoCode.premiumMonths, 'promo_code');
        
        // Mettre à jour les promoBenefits
        user.promoBenefits.lastPromoCodePrefix = codePrefix;
        appliedEffect = `${updatedPromoCode.premiumMonths} mois de Premium accordés`;
        effectDetails = {
          premiumMonths: updatedPromoCode.premiumMonths,
          premiumExpiresAt: updatedUserMonths.subscription.premiumExpiresAt
        };
        break;

      case 'GRANT_PREMIUM_PERMANENT':
        // Utiliser le service subscription pour le premium permanent
        await subscriptionService.grantPremiumPermanent(userId, 'promo_code');
        
        // Mettre à jour les promoBenefits
        user.promoBenefits.lastPromoCodePrefix = codePrefix;
        appliedEffect = 'Premium permanent accordé';
        effectDetails = {
          permanent: true
        };
        break;

      default:
        throw new Error(`Type de code promotionnel non supporté: ${updatedPromoCode.type}`);
    }

    // Mettre à jour les détails dans le code promotionnel (déjà fait par findOneAndUpdate, mais on peut les mettre à jour)
    const usedByEntry = updatedPromoCode.usedBy[updatedPromoCode.usedBy.length - 1];
    if (usedByEntry && usedByEntry.userId.toString() === userId.toString()) {
      usedByEntry.details = effectDetails;
      await updatedPromoCode.save();
    }

    // Ajouter à l'historique de l'utilisateur
    user.promoBenefits.history.push({
      type: updatedPromoCode.type,
      prefix: codePrefix,
      appliedAt: now,
      details: effectDetails
    });

    // Sauvegarder l'utilisateur
    await user.save();

    return {
      success: true,
      codePrefix,
      type: updatedPromoCode.type,
      appliedEffect,
      details: effectDetails
    };
}

/**
 * Désactive un code promotionnel
 * @param {string|ObjectId} promoCodeId - ID du code promotionnel
 * @returns {Promise<object>} Code promotionnel désactivé
 */
async function deactivatePromoCode(promoCodeId) {
  if (!promoCodeId) {
    throw new Error('promoCodeId est requis');
  }

  const promoCode = await PromoCode.findById(promoCodeId);
  if (!promoCode) {
    throw new Error('Code promotionnel non trouvé');
  }

  promoCode.isActive = false;
  await promoCode.save();

  return promoCode;
}

module.exports = {
  generatePromoCodes,
  redeemPromoCode,
  deactivatePromoCode
};

