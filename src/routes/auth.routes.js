const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const {
  validateRegister,
  validateLogin,
  validateRefreshToken,
  validateVerifyEmail,
  validateResendVerification
} = require('../validators/auth.validator');

// Routes publiques
router.post('/register', validateRegister, authController.register);
router.post('/login', validateLogin, authController.login);
router.post('/resend-verification', validateResendVerification, authController.resendVerificationEmail);
router.get('/verify-email', authController.verifyEmail);
router.post('/verify-email', validateVerifyEmail, authController.verifyEmail);
router.get('/unlock-account', authController.unlockAccount);
router.post('/refresh-token', validateRefreshToken, authController.refreshToken);

// Routes protégées (nécessitent JWT)
router.get('/me', authMiddleware, authController.getMe);
router.post('/logout', authMiddleware, authController.logout);
router.post('/2fa/enable', authMiddleware, authController.enable2FA);
router.post('/2fa/verify', authMiddleware, authController.verify2FA);
router.post('/2fa/disable', authMiddleware, authController.disable2FA);

module.exports = router;
