const Referral = require('../models/Referral');
const subscriptionService = require('./subscription.service');

/**
 * Attribuer les récompenses de parrainage (1 mois premium = 30 jours pour le parrain et le filleul)
 */
async function grantReferralRewards(referrerId, referredUserId, referralCode) {
  try {
    // Trouver ou créer l'enregistrement de parrainage
    let referral = await Referral.findOne({
      referrerId,
      referredUserId
    });

    if (!referral) {
      referral = new Referral({
        referrerId,
        referredUserId,
        referralCode
      });
      await referral.save();
    }

    // Attribuer 1 mois premium au filleul (30 jours)
    if (!referral.referredRewardGranted) {
      // Utiliser le service centralisé pour accorder les jours premium
      // Le service gère automatiquement la prolongation si premium déjà actif
      await subscriptionService.grantPremiumDays(referredUserId, 30, 'referral_reward');

      referral.referredRewardGranted = true;
      referral.referredRewardGrantedAt = new Date();
      await referral.save();
    }

    // Attribuer 1 mois premium au parrain (30 jours)
    if (!referral.referrerRewardGranted) {
      // Utiliser le service centralisé pour accorder les jours premium
      // Le service gère automatiquement la prolongation si premium déjà actif
      await subscriptionService.grantPremiumDays(referrerId, 30, 'referral_reward');

      referral.referrerRewardGranted = true;
      referral.referrerRewardGrantedAt = new Date();
      await referral.save();
    }

    return referral;
  } catch (error) {
    console.error('Erreur lors de l\'attribution des récompenses de parrainage:', error);
    throw error;
  }
}

module.exports = {
  grantReferralRewards
};
