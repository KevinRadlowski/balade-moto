const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const socialAuthController = require('../controllers/social-auth.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const { registerLimiter, loginLimiter } = require('../middlewares/otpRateLimit.middleware');
const {
  validateRegister,
  validateLogin,
  validateRefreshToken,
  validateVerifyEmail,
  validateResendVerification
} = require('../validators/auth.validator');

// Routes publiques
router.post('/register', registerLimiter, validateRegister, authController.register);
router.post('/login', loginLimiter, validateLogin, authController.login);

// Routes OAuth
router.post('/social/google', socialAuthController.googleAuth);
router.post('/social/apple', socialAuthController.appleAuth);
router.post('/social/facebook', socialAuthController.facebookAuth);
router.post('/resend-verification', validateResendVerification, authController.resendVerificationEmail);
router.get('/verify-email', authController.verifyEmail);
router.post('/verify-email', validateVerifyEmail, authController.verifyEmail);
router.post('/forgot-password', authController.forgotPassword);
router.get('/reset-password', authController.resetPassword);
router.post('/reset-password', authController.resetPassword);
router.get('/unlock-account', authController.unlockAccount);
router.post('/refresh-token', validateRefreshToken, authController.refreshToken);

// Routes protégées (nécessitent JWT)
router.get('/me', authMiddleware, subscriptionMiddleware, authController.getMe);
router.post('/logout', authMiddleware, subscriptionMiddleware, authController.logout);
router.post('/2fa/enable', authMiddleware, subscriptionMiddleware, authController.enable2FA);
router.post('/2fa/verify', authMiddleware, subscriptionMiddleware, authController.verify2FA);
router.post('/2fa/disable', authMiddleware, subscriptionMiddleware, authController.disable2FA);

module.exports = router;
