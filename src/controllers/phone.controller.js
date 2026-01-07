const User = require('../models/User');
const smsService = require('../services/sms.service');
const { BadRequestError, NotFoundError } = require('../utils/errors');

/**
 * Générer un code OTP à 6 chiffres
 */
function generateOtpCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Envoyer un code OTP par SMS
 */
exports.sendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      throw new BadRequestError('Le numéro de téléphone est requis');
    }

    // Normaliser le téléphone
    const normalizedPhone = phone.replace(/\s+/g, '').replace(/-/g, '').trim();

    // Vérifier le format (doit contenir au moins 8 chiffres)
    if (!/^\+?[1-9]\d{7,14}$/.test(normalizedPhone)) {
      throw new BadRequestError('Format de numéro de téléphone invalide');
    }

    // Vérifier le cooldown (60 secondes entre chaque envoi)
    // Si l'utilisateur est authentifié, utiliser son compte
    let user = null;
    if (req.user) {
      user = await User.findById(req.user._id);
    } else {
      user = await User.findOne({ phone: normalizedPhone });
    }
    
    if (user && user.phoneOtpLastSent) {
      const timeSinceLastSent = Date.now() - user.phoneOtpLastSent.getTime();
      const cooldownTime = 60 * 1000; // 60 secondes
      if (timeSinceLastSent < cooldownTime) {
        const remainingSeconds = Math.ceil((cooldownTime - timeSinceLastSent) / 1000);
        return res.status(429).json({
          success: false,
          message: `Veuillez attendre ${remainingSeconds} seconde(s) avant de demander un nouveau code`
        });
      }
    }

    // Générer le code OTP
    const otpCode = generateOtpCode();
    const otpExpires = Date.now() + 10 * 60 * 1000; // 10 minutes

    // Si l'utilisateur existe, mettre à jour le code
    // Si l'utilisateur est authentifié (req.user), utiliser son ID
    // Sinon, chercher par téléphone
    let targetUser = user;
    if (!targetUser && req.user) {
      targetUser = await User.findById(req.user._id);
      // Vérifier que le téléphone correspond
      if (targetUser && targetUser.phone !== normalizedPhone) {
        return res.status(400).json({
          success: false,
          message: 'Le numéro de téléphone ne correspond pas à votre compte'
        });
      }
    }

    if (!targetUser) {
      return res.status(404).json({
        success: false,
        message: 'Aucun compte trouvé avec ce numéro de téléphone'
      });
    }

    targetUser.phoneOtpCode = otpCode;
    targetUser.phoneOtpExpires = new Date(otpExpires);
    targetUser.phoneOtpLastSent = new Date();
    await targetUser.save();

    // Envoyer le SMS
    try {
      await smsService.sendOtpSms(normalizedPhone, otpCode);
    } catch (smsError) {
      console.error('Erreur lors de l\'envoi du SMS:', smsError);
      // En développement, on continue même si l'envoi échoue
      if (process.env.NODE_ENV !== 'development' && process.env.SKIP_SMS_VERIFICATION !== 'true') {
        throw smsError;
      }
    }

    res.status(200).json({
      success: true,
      message: 'Code OTP envoyé avec succès'
    });
  } catch (error) {
    if (error instanceof BadRequestError || error instanceof NotFoundError) {
      return res.status(error.statusCode).json({
        success: false,
        message: error.message
      });
    }
    console.error('Erreur lors de l\'envoi de l\'OTP:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'envoi du code OTP',
      error: error.message
    });
  }
};

/**
 * Vérifier un code OTP
 */
exports.verifyOtp = async (req, res) => {
  try {
    const { phone, code } = req.body;

    if (!phone || !code) {
      throw new BadRequestError('Le numéro de téléphone et le code sont requis');
    }

    // Normaliser le téléphone
    const normalizedPhone = phone.replace(/\s+/g, '').replace(/-/g, '').trim();

    // Trouver l'utilisateur
    // Si l'utilisateur est authentifié, utiliser son compte
    let user = null;
    if (req.user) {
      user = await User.findById(req.user._id);
      // Vérifier que le téléphone correspond
      if (user && user.phone !== normalizedPhone) {
        return res.status(400).json({
          success: false,
          message: 'Le numéro de téléphone ne correspond pas à votre compte'
        });
      }
    } else {
      user = await User.findOne({ phone: normalizedPhone });
    }

    if (!user) {
      throw new NotFoundError('Aucun compte trouvé avec ce numéro de téléphone');
    }

    // Vérifier le code
    if (!user.phoneOtpCode || user.phoneOtpCode !== code) {
      return res.status(400).json({
        success: false,
        message: 'Code OTP invalide'
      });
    }

    // Vérifier l'expiration
    if (!user.phoneOtpExpires || user.phoneOtpExpires < new Date()) {
      return res.status(400).json({
        success: false,
        message: 'Code OTP expiré. Veuillez demander un nouveau code'
      });
    }

    // Marquer le téléphone comme vérifié
    user.phoneVerified = true;
    user.phoneOtpCode = null;
    user.phoneOtpExpires = null;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Téléphone vérifié avec succès'
    });
  } catch (error) {
    if (error instanceof BadRequestError || error instanceof NotFoundError) {
      return res.status(error.statusCode).json({
        success: false,
        message: error.message
      });
    }
    console.error('Erreur lors de la vérification de l\'OTP:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la vérification du code OTP',
      error: error.message
    });
  }
};
