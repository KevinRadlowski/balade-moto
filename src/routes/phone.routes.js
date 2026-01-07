const express = require('express');
const router = express.Router();
const phoneController = require('../controllers/phone.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');

// Envoyer un code OTP (nécessite authentification pour modifier son propre téléphone)
router.post('/send-otp', authMiddleware, subscriptionMiddleware, phoneController.sendOtp);

// Vérifier un code OTP (nécessite authentification)
router.post('/verify-otp', authMiddleware, subscriptionMiddleware, phoneController.verifyOtp);

module.exports = router;
