const express = require('express');
const router = express.Router();
const liveRideController = require('../controllers/liveRide.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const rateLimitMiddleware = require('../middlewares/rateLimit.middleware');
const {
  validateRideId,
  validateReportIncident,
  validateHeartbeat
} = require('../validators/liveRide.validator');

// Toutes les routes nécessitent une authentification
// Rate limiting sur les endpoints critiques
router.post('/:id/start', authMiddleware, validateRideId, liveRideController.startLiveRide);
router.post('/:id/pause', authMiddleware, validateRideId, liveRideController.pauseLiveRide);
router.post('/:id/resume', authMiddleware, validateRideId, liveRideController.resumeLiveRide);
router.post('/:id/end', authMiddleware, validateRideId, liveRideController.endLiveRide);
router.post('/:id/incident', 
  authMiddleware, 
  rateLimitMiddleware(5, 60000), // 5 req/min pour les incidents
  validateRideId, 
  validateReportIncident, 
  liveRideController.reportIncident
);
router.get('/:id/status', authMiddleware, validateRideId, liveRideController.getLiveRideStatus);
router.post('/:id/heartbeat', authMiddleware, validateRideId, validateHeartbeat, liveRideController.sendHeartbeat);

module.exports = router;






