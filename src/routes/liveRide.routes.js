const express = require('express');
const router = express.Router();
const liveRideController = require('../controllers/liveRide.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const rateLimitMiddleware = require('../middlewares/rateLimit.middleware');
const {
  validateRideId,
  validateReportIncident,
  validateHeartbeat
} = require('../validators/liveRide.validator');

// Toutes les routes nécessitent une authentification
// Rate limiting sur les endpoints critiques
router.post('/:id/start', authMiddleware, subscriptionMiddleware, validateRideId, liveRideController.startLiveRide);
router.post('/:id/pause', authMiddleware, subscriptionMiddleware, validateRideId, liveRideController.pauseLiveRide);
router.post('/:id/resume', authMiddleware, subscriptionMiddleware, validateRideId, liveRideController.resumeLiveRide);
router.post('/:id/end', authMiddleware, subscriptionMiddleware, validateRideId, liveRideController.endLiveRide);
router.post('/:id/incident', 
  authMiddleware, 
  subscriptionMiddleware,
  rateLimitMiddleware(5, 60000), // 5 req/min pour les incidents
  validateRideId, 
  validateReportIncident, 
  liveRideController.reportIncident
);
router.get('/:id/status', authMiddleware, subscriptionMiddleware, validateRideId, liveRideController.getLiveRideStatus);
router.post('/:id/heartbeat', authMiddleware, subscriptionMiddleware, validateRideId, validateHeartbeat, liveRideController.sendHeartbeat);

module.exports = router;





