const express = require('express');
const router = express.Router();
const reputationController = require('../controllers/reputation.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const { validateUserId } = require('../validators/reputation.validator');

// Toutes les routes nécessitent une authentification
router.get('/:userId', authMiddleware, subscriptionMiddleware, validateUserId, reputationController.getReputation);
router.get('/:userId/achievements', authMiddleware, subscriptionMiddleware, validateUserId, reputationController.getAchievements);

module.exports = router;












