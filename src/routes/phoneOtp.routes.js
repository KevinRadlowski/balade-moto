const express = require('express');
const router = express.Router();
const phoneOtpController = require('../controllers/phoneOtp.controller');
const { sendOtpLimiter, verifyOtpLimiter } = require('../middlewares/otpRateLimit.middleware');
const authMiddleware = require('../middlewares/auth.middleware');

/**
 * @route   POST /auth/phone/send-otp
 * @desc    Envoyer un code OTP par SMS via Twilio Verify
 * @access  Public (ou Protected si utilisateur connecté veut changer son téléphone)
 * @body    { phone: string } - Numéro de téléphone (sera normalisé en E.164)
 */
router.post('/send-otp', sendOtpLimiter, phoneOtpController.sendOtp);

/**
 * @route   POST /auth/phone/verify-otp
 * @desc    Vérifier un code OTP et marquer le téléphone comme vérifié
 * @access  Public (ou Protected si utilisateur connecté)
 * @body    { phone: string, code: string } - Numéro et code OTP
 * 
 * Si la vérification réussit et que l'utilisateur a un code de parrainage valide,
 * les récompenses de parrainage seront accordées automatiquement.
 */
router.post('/verify-otp', verifyOtpLimiter, phoneOtpController.verifyOtp);

module.exports = router;
