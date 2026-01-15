const User = require('../models/User');
const { BadRequestError, NotFoundError } = require('../utils/errors');
const { normalizePhoneE164, isValidE164 } = require('../utils/phone.utils');
const { getTwilioClient, isTwilioConfigured, getVerifyServiceSid } = require('../config/twilio');
const referralService = require('../services/referral.service');

/**
 * Envoyer un code OTP via Twilio Verify
 * POST /auth/phone/send-otp
 * Body: { phone: string }
 */
exports.sendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      throw new BadRequestError('Le numéro de téléphone est requis');
    }

    // Normaliser le téléphone en E.164
    const phoneE164 = normalizePhoneE164(phone);
    if (!phoneE164 || !isValidE164(phoneE164)) {
      throw new BadRequestError('Format de numéro de téléphone invalide. Utilisez le format international (ex: +33612345678)');
    }

    // Vérifier que Twilio est configuré
    if (!isTwilioConfigured()) {
      // En développement, simuler l'envoi
      if (process.env.NODE_ENV === 'development' || process.env.SKIP_SMS_VERIFICATION === 'true') {
        console.log(`📱 [DEV] OTP simulé pour ${phoneE164}`);
        
        // Trouver ou créer l'utilisateur pour mettre à jour phoneE164
        let user = null;
        if (req.user) {
          user = await User.findById(req.user._id);
        } else {
          user = await User.findOne({ phoneE164 });
        }

        if (!user) {
          return res.status(404).json({
            success: false,
            message: 'Aucun compte trouvé avec ce numéro de téléphone'
          });
        }

        // Mettre à jour le téléphone si nécessaire
        if (user.phoneE164 !== phoneE164) {
          // Vérifier que le nouveau numéro n'est pas déjà utilisé
          const existingUser = await User.findOne({ phoneE164 });
          if (existingUser && existingUser._id.toString() !== user._id.toString()) {
            throw new BadRequestError('Ce numéro de téléphone est déjà utilisé');
          }
          user.phoneE164 = phoneE164;
          await user.save();
        }

        return res.status(200).json({
          success: true,
          message: 'Code OTP envoyé avec succès (mode développement)'
        });
      }

      const { InternalServerError } = require('../utils/errors');
      throw new InternalServerError('Service SMS non configuré', { service: 'twilio', config: 'TWILIO_*' });
    }

    // Vérifier si l'utilisateur existe
    let user = null;
    if (req.user) {
      user = await User.findById(req.user._id);
      if (user && user.phoneE164 && user.phoneE164 !== phoneE164) {
        // Vérifier que le nouveau numéro n'est pas déjà utilisé
        const existingUser = await User.findOne({ phoneE164 });
        if (existingUser) {
          throw new BadRequestError('Ce numéro de téléphone est déjà utilisé');
        }
        // Mettre à jour le téléphone et réinitialiser la vérification
        user.phoneE164 = phoneE164;
        user.phoneVerified = false;
        user.status = 'pending_phone_verification';
        user.referralRewardGranted = false; // Réinitialiser les récompenses si téléphone change
        await user.save();
      }
      // Note: phoneE164 est maintenant obligatoire (required: true), donc le cas !user.phoneE164 n'existe plus
    } else {
      user = await User.findOne({ phoneE164 });
      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'Aucun compte trouvé avec ce numéro de téléphone'
        });
      }
    }

    // Envoyer l'OTP via Twilio Verify
    const twilioClient = getTwilioClient();
    const verifyServiceSid = getVerifyServiceSid();

    if (!twilioClient || !verifyServiceSid) {
      const { InternalServerError } = require('../utils/errors');
      throw new InternalServerError('Service SMS non configuré', { service: 'twilio', config: 'TWILIO_*' });
    }

    try {
      await twilioClient.verify.v2
        .services(verifyServiceSid)
        .verifications
        .create({
          to: phoneE164,
          channel: 'sms'
        });

      res.status(200).json({
        success: true,
        message: 'Code OTP envoyé avec succès'
      });
    } catch (twilioError) {
      console.error('Erreur Twilio Verify:', twilioError.message);
      
      // Ne pas exposer les détails de l'erreur Twilio
      if (twilioError.code === 60200) {
        throw new BadRequestError('Numéro de téléphone invalide');
      } else if (twilioError.code === 60203) {
        throw new BadRequestError('Trop de tentatives. Veuillez réessayer plus tard');
      }
      
      const { InternalServerError } = require('../utils/errors');
      throw new InternalServerError('Erreur lors de l\'envoi du code OTP', { service: 'twilio', action: 'send_otp' });
    }
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
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Vérifier un code OTP via Twilio Verify
 * POST /auth/phone/verify-otp
 * Body: { phone: string, code: string }
 */
exports.verifyOtp = async (req, res) => {
  try {
    const { phone, code } = req.body;

    if (!phone || !code) {
      throw new BadRequestError('Le numéro de téléphone et le code sont requis');
    }

    // Valider le format du code (4 à 8 chiffres)
    if (!/^\d{4,8}$/.test(code)) {
      throw new BadRequestError('Le code doit contenir entre 4 et 8 chiffres');
    }

    // Normaliser le téléphone en E.164
    const phoneE164 = normalizePhoneE164(phone);
    if (!phoneE164 || !isValidE164(phoneE164)) {
      throw new BadRequestError('Format de numéro de téléphone invalide');
    }

    // Trouver l'utilisateur
    let user = null;
    if (req.user) {
      user = await User.findById(req.user._id);
      if (user && user.phoneE164 !== phoneE164) {
        return res.status(400).json({
          success: false,
          message: 'Le numéro de téléphone ne correspond pas à votre compte'
        });
      }
    } else {
      user = await User.findOne({ phoneE164 });
    }

    if (!user) {
      throw new NotFoundError('Aucun compte trouvé avec ce numéro de téléphone');
    }

    // Vérifier que Twilio est configuré
    if (!isTwilioConfigured()) {
      // En développement, accepter un code de test
      if (process.env.NODE_ENV === 'development' || process.env.SKIP_SMS_VERIFICATION === 'true') {
        const testCode = process.env.TEST_OTP_CODE || '123456';
        if (code === testCode) {
          // Marquer comme vérifié et activer le compte
          user.phoneVerified = true;
          user.status = 'active';
          await user.save();

          // Accorder les récompenses de parrainage si applicable
          await _grantReferralRewardsIfNeeded(user);

          return res.status(200).json({
            success: true,
            message: 'Téléphone vérifié avec succès. Votre compte est maintenant actif.',
            accountActivated: true
          });
        } else {
          return res.status(401).json({
            success: false,
            message: 'Code OTP invalide'
          });
        }
      }

      const { InternalServerError } = require('../utils/errors');
      throw new InternalServerError('Service SMS non configuré', { service: 'twilio', config: 'TWILIO_*' });
    }

    // Vérifier le code via Twilio Verify
    const twilioClient = getTwilioClient();
    const verifyServiceSid = getVerifyServiceSid();

    if (!twilioClient || !verifyServiceSid) {
      const { InternalServerError } = require('../utils/errors');
      throw new InternalServerError('Service SMS non configuré', { service: 'twilio', config: 'TWILIO_*' });
    }

    try {
      const verificationCheck = await twilioClient.verify.v2
        .services(verifyServiceSid)
        .verificationChecks
        .create({
          to: phoneE164,
          code: code
        });

      if (verificationCheck.status !== 'approved') {
        return res.status(401).json({
          success: false,
          message: 'Code OTP invalide ou expiré'
        });
      }

      // Si déjà vérifié et actif, retourner succès (idempotent)
      if (user.phoneVerified && user.status === 'active') {
        return res.status(200).json({
          success: true,
          message: 'Téléphone déjà vérifié',
          accountActivated: true
        });
      }

      // Marquer comme vérifié et activer le compte
      user.phoneVerified = true;
      user.status = 'active';
      await user.save();

      // Accorder les récompenses de parrainage si applicable
      await _grantReferralRewardsIfNeeded(user);

      res.status(200).json({
        success: true,
        message: 'Téléphone vérifié avec succès. Votre compte est maintenant actif.',
        accountActivated: true
      });
    } catch (twilioError) {
      console.error('Erreur Twilio Verify Check:', twilioError.message);
      
      if (twilioError.code === 20404) {
        throw new NotFoundError('Code de vérification introuvable ou expiré');
      } else if (twilioError.code === 60202) {
        throw new BadRequestError('Trop de tentatives. Veuillez demander un nouveau code');
      }
      
      throw new Error('Erreur lors de la vérification du code');
    }
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
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Accorder les récompenses de parrainage si nécessaire
 * @param {User} user - Utilisateur à vérifier
 */
async function _grantReferralRewardsIfNeeded(user) {
  // Vérifier si l'utilisateur a un parrain et n'a pas encore reçu la récompense
  if (!user.referredBy || user.referralRewardGranted) {
    return;
  }

  try {
    const referrer = await User.findById(user.referredBy);
    if (!referrer) {
      console.warn(`Parrain introuvable pour l'utilisateur ${user._id}`);
      return;
    }

    // Empêcher l'auto-parrainage
    if (referrer.phoneE164 === user.phoneE164 || referrer.email === user.email) {
      console.warn(`Tentative d'auto-parrainage détectée pour ${user._id}`);
      return;
    }

    // Accorder les récompenses
    await referralService.grantReferralRewards(
      referrer._id,
      user._id,
      referrer.referralCode
    );

    // Marquer comme accordé
    user.referralRewardGranted = true;
    await user.save();

    console.log(`✅ Récompenses de parrainage accordées pour ${user._id} (parrain: ${referrer._id})`);
  } catch (error) {
    console.error('Erreur lors de l\'attribution des récompenses de parrainage:', error);
    // Ne pas bloquer la vérification du téléphone si l'attribution échoue
  }
}
