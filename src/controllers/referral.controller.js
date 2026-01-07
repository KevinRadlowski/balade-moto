const User = require('../models/User');
const Referral = require('../models/Referral');
const { NotFoundError, BadRequestError } = require('../utils/errors');

// Obtenir les informations de parrainage de l'utilisateur connecté
exports.getMyReferralInfo = async (req, res) => {
  try {
    const userId = req.user._id;
    const user = await User.findById(userId).select('referralCode subscription');

    if (!user) {
      throw new NotFoundError('Utilisateur non trouvé');
    }

    // Générer un code de parrainage si l'utilisateur n'en a pas
    if (!user.referralCode) {
      const crypto = require('crypto');
      let code;
      let isUnique = false;
      let attempts = 0;
      
      while (!isUnique && attempts < 10) {
        // Générer un code de 8 caractères (lettres majuscules et chiffres)
        code = crypto.randomBytes(4).toString('hex').toUpperCase();
        const existing = await User.findOne({ referralCode: code });
        if (!existing) {
          isUnique = true;
        }
        attempts++;
      }
      
      if (isUnique) {
        user.referralCode = code;
      } else {
        // Fallback : utiliser l'ID avec un préfixe
        user.referralCode = `REF${user._id.toString().slice(-8).toUpperCase()}`;
      }
      
      await user.save();
    }

    // Compter le nombre de personnes parrainées
    const referralsCount = await Referral.countDocuments({ referrerId: userId });

    // Compter le nombre de personnes parrainées qui ont reçu leur récompense
    const activeReferralsCount = await Referral.countDocuments({
      referrerId: userId,
      referredRewardGranted: true
    });

    // Obtenir la liste des personnes parrainées (limité à 10)
    const referrals = await Referral.find({ referrerId: userId })
      .populate('referredUserId', 'pseudo email createdAt')
      .sort({ createdAt: -1 })
      .limit(10)
      .select('referredUserId referredRewardGranted createdAt');

    // Construire l'URL de parrainage
    const frontendUrl = process.env.FRONTEND_URL?.split(',')[0]?.trim() || 'http://localhost:3000';
    const referralUrl = `${frontendUrl}/register?ref=${user.referralCode}`;

    res.status(200).json({
      success: true,
      data: {
        referralCode: user.referralCode,
        referralUrl,
        referralsCount,
        activeReferralsCount,
        referrals: referrals.map(ref => ({
          id: ref._id,
          referredUser: ref.referredUserId,
          rewardGranted: ref.referredRewardGranted,
          createdAt: ref.createdAt
        })),
        subscription: user.subscription
      }
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof BadRequestError) {
      return res.status(error.statusCode).json({
        success: false,
        message: error.message
      });
    }
    console.error('Erreur lors de la récupération des infos de parrainage:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des informations de parrainage',
      error: error.message
    });
  }
};

// Valider un code de parrainage (pour l'inscription)
exports.validateReferralCode = async (req, res) => {
  try {
    const { code } = req.body;

    if (!code) {
      throw new BadRequestError('Le code de parrainage est requis');
    }

    const normalizedCode = code.trim().toUpperCase();
    const referrer = await User.findOne({ referralCode: normalizedCode });

    if (!referrer) {
      return res.status(200).json({
        success: false,
        valid: false,
        message: 'Code de parrainage invalide'
      });
    }

    // Vérifier que l'utilisateur ne se parraine pas lui-même
    if (req.user && req.user._id.toString() === referrer._id.toString()) {
      return res.status(200).json({
        success: false,
        valid: false,
        message: 'Vous ne pouvez pas utiliser votre propre code de parrainage'
      });
    }

    res.status(200).json({
      success: true,
      valid: true,
      message: 'Code de parrainage valide',
      data: {
        referrerPseudo: referrer.pseudo
      }
    });
  } catch (error) {
    if (error instanceof BadRequestError) {
      return res.status(error.statusCode).json({
        success: false,
        message: error.message
      });
    }
    console.error('Erreur lors de la validation du code:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la validation du code de parrainage',
      error: error.message
    });
  }
};
