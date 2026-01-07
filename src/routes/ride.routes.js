const express = require('express');
const router = express.Router();
const rideController = require('../controllers/ride.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const rateLimitMiddleware = require('../middlewares/rateLimit.middleware');
const {
  validateCreateRide,
  validateUpdateRide,
  validateGetRides,
  validateGetRidesNearby,
  validateRideId
} = require('../validators/ride.validator');
const liveRideController = require('../controllers/liveRide.controller');
const {
  validateRideId: validateLiveRideId,
  validateReportIncident,
  validateHeartbeat: validateLiveHeartbeat
} = require('../validators/liveRide.validator');

// Toutes les routes nécessitent une authentification JWT
router.post('/', authMiddleware, subscriptionMiddleware, validateCreateRide, rideController.createRide);
router.get('/', authMiddleware, subscriptionMiddleware, validateGetRides, rideController.getRides);
// Route pour les balades proches avec limitation de taux (10 requêtes par minute)
router.get('/proches', authMiddleware, subscriptionMiddleware, rateLimitMiddleware(10, 60000), validateGetRidesNearby, rideController.getRidesNearby);
router.get('/past', authMiddleware, subscriptionMiddleware, validateGetRides, rideController.getPastRides);
router.get('/my-past', authMiddleware, subscriptionMiddleware, validateGetRides, rideController.getMyPastRides);
router.get('/calendar', authMiddleware, subscriptionMiddleware, rideController.getCalendar);
// Routes utilitaires Google Maps (doivent être AVANT /:id pour éviter les conflits)
// PROTECTION: Auth + Rate Limit + Validation
const {
  validateCalculateRoute,
  validateGeocodeAddress,
  validateReverseGeocode
} = require('../validators/google-maps.validator');

router.get('/directions/route', 
  authMiddleware, 
  subscriptionMiddleware,
  rateLimitMiddleware(20, 60000), // 20 req/min
  validateCalculateRoute, 
  rideController.calculateRoute
);
router.get('/geocode', 
  authMiddleware, 
  subscriptionMiddleware,
  rateLimitMiddleware(20, 60000), // 20 req/min
  validateGeocodeAddress, 
  rideController.geocodeAddress
);
router.get('/reverse-geocode', 
  authMiddleware, 
  subscriptionMiddleware,
  rateLimitMiddleware(20, 60000), // 20 req/min
  validateReverseGeocode, 
  rideController.reverseGeocode
);
// Routes avec paramètre :id (doivent être en dernier)
router.get('/:id', authMiddleware, subscriptionMiddleware, validateRideId, rideController.getRideById);
router.get('/:id/ics', authMiddleware, subscriptionMiddleware, validateRideId, rideController.exportRideICS);
router.put('/:id', authMiddleware, subscriptionMiddleware, validateRideId, validateUpdateRide, rideController.updateRide);
router.delete('/:id', authMiddleware, subscriptionMiddleware, validateRideId, rideController.deleteRide);
router.post('/:id/join', authMiddleware, subscriptionMiddleware, validateRideId, rideController.joinRide);
router.delete('/:id/join', authMiddleware, subscriptionMiddleware, validateRideId, rideController.leaveRide);
router.post('/:id/invite', authMiddleware, subscriptionMiddleware, validateRideId, rideController.inviteUsersToRide);
router.post('/:id/invitations/accept', authMiddleware, subscriptionMiddleware, validateRideId, rideController.acceptRideInvitation);
router.post('/:id/invitations/decline', authMiddleware, subscriptionMiddleware, validateRideId, rideController.declineRideInvitation);
router.post('/:id/like', authMiddleware, subscriptionMiddleware, validateRideId, rideController.likeRide);
router.post('/:id/note', authMiddleware, subscriptionMiddleware, validateRideId, rideController.rateRide);
router.post('/:id/complete', authMiddleware, subscriptionMiddleware, validateRideId, rideController.completeRide);
router.post('/:id/arrival', authMiddleware, subscriptionMiddleware, validateRideId, rideController.markArrival);
router.post('/:id/participants/:userId/validate-punctuality', authMiddleware, subscriptionMiddleware, validateRideId, rideController.validatePunctuality);
router.post('/:id/claim-organizer', authMiddleware, subscriptionMiddleware, validateRideId, rideController.claimOrganizer);

// Routes live ride (doivent être avant /:id pour éviter les conflits)
router.post('/:id/start', authMiddleware, subscriptionMiddleware, validateLiveRideId, liveRideController.startLiveRide);
router.post('/:id/pause', authMiddleware, subscriptionMiddleware, validateLiveRideId, liveRideController.pauseLiveRide);
router.post('/:id/resume', authMiddleware, subscriptionMiddleware, validateLiveRideId, liveRideController.resumeLiveRide);
router.post('/:id/end', authMiddleware, subscriptionMiddleware, validateLiveRideId, liveRideController.endLiveRide);
router.post('/:id/incident', 
  authMiddleware, 
  subscriptionMiddleware,
  rateLimitMiddleware(5, 60000), // 5 req/min pour les incidents
  validateLiveRideId, 
  validateReportIncident, 
  liveRideController.reportIncident
);
router.get('/:id/live-status', authMiddleware, subscriptionMiddleware, validateLiveRideId, liveRideController.getLiveRideStatus);
router.post('/:id/heartbeat', authMiddleware, subscriptionMiddleware, validateLiveRideId, validateLiveHeartbeat, liveRideController.sendHeartbeat);

module.exports = router;

