const express = require('express');
const router = express.Router();
const vehicleStatsController = require('../controllers/vehicleStats.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const {
  validateVehicleId,
  validateUpdateStats
} = require('../validators/vehicleStats.validator');

// Toutes les routes nécessitent une authentification
router.get('/:vehicleId', authMiddleware, validateVehicleId, vehicleStatsController.getVehicleStats);
router.post('/:vehicleId/update', authMiddleware, validateVehicleId, validateUpdateStats, vehicleStatsController.updateVehicleStats);

module.exports = router;

