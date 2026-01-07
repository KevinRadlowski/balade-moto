const express = require('express');
const router = express.Router();
const vehicleStatsController = require('../controllers/vehicleStats.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const {
  validateVehicleId,
  validateUpdateStats
} = require('../validators/vehicleStats.validator');

// Toutes les routes nécessitent une authentification
router.get('/:vehicleId', authMiddleware, subscriptionMiddleware, validateVehicleId, vehicleStatsController.getVehicleStats);
router.post('/:vehicleId/update', authMiddleware, subscriptionMiddleware, validateVehicleId, validateUpdateStats, vehicleStatsController.updateVehicleStats);

module.exports = router;






