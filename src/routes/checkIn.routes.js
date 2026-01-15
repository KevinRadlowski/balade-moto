const express = require('express');
const router = express.Router();
const checkInController = require('../controllers/checkIn.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const { validateHeartbeat } = require('../validators/checkIn.validator');

// Toutes les routes nécessitent une authentification
router.post('/heartbeat', authMiddleware, subscriptionMiddleware, validateHeartbeat, checkInController.sendHeartbeat);
router.get('/status', authMiddleware, subscriptionMiddleware, checkInController.getCheckInStatus);

module.exports = router;












