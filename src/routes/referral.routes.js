const express = require('express');
const router = express.Router();
const referralController = require('../controllers/referral.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');

// Obtenir les informations de parrainage de l'utilisateur connecté
router.get('/my-info', authMiddleware, subscriptionMiddleware, referralController.getMyReferralInfo);

// Valider un code de parrainage (endpoint public pour l'inscription)
router.post('/validate', referralController.validateReferralCode);

module.exports = router;
