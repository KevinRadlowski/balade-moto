const express = require('express');
const router = express.Router();
const checkInController = require('../controllers/checkIn.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const { validateHeartbeat } = require('../validators/checkIn.validator');

// Toutes les routes nécessitent une authentification
router.post('/heartbeat', authMiddleware, validateHeartbeat, checkInController.sendHeartbeat);
router.get('/status', authMiddleware, checkInController.getCheckInStatus);

module.exports = router;


