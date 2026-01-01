const express = require('express');
const router = express.Router();
const rideController = require('../controllers/ride.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const rateLimitMiddleware = require('../middlewares/rateLimit.middleware');
const {
  validateCreateRide,
  validateUpdateRide,
  validateGetRides,
  validateGetRidesNearby,
  validateRideId
} = require('../validators/ride.validator');

// Toutes les routes nécessitent une authentification JWT
router.post('/', authMiddleware, validateCreateRide, rideController.createRide);
router.get('/', authMiddleware, validateGetRides, rideController.getRides);
// Route pour les balades proches avec limitation de taux (10 requêtes par minute)
router.get('/proches', authMiddleware, rateLimitMiddleware(10, 60000), validateGetRidesNearby, rideController.getRidesNearby);
router.get('/past', authMiddleware, validateGetRides, rideController.getPastRides);
router.get('/my-past', authMiddleware, validateGetRides, rideController.getMyPastRides);
router.get('/calendar', authMiddleware, rideController.getCalendar);
// Routes utilitaires (doivent être AVANT /:id pour éviter les conflits)
router.get('/directions/route', rideController.calculateRoute);
router.get('/geocode', rideController.geocodeAddress);
router.get('/reverse-geocode', rideController.reverseGeocode);
// Routes avec paramètre :id (doivent être en dernier)
router.get('/:id', authMiddleware, validateRideId, rideController.getRideById);
router.get('/:id/ics', authMiddleware, validateRideId, rideController.exportRideICS);
router.put('/:id', authMiddleware, validateRideId, validateUpdateRide, rideController.updateRide);
router.delete('/:id', authMiddleware, validateRideId, rideController.deleteRide);
router.post('/:id/join', authMiddleware, validateRideId, rideController.joinRide);
router.delete('/:id/join', authMiddleware, validateRideId, rideController.leaveRide);
router.post('/:id/like', authMiddleware, validateRideId, rideController.likeRide);
router.post('/:id/note', authMiddleware, validateRideId, rideController.rateRide);

module.exports = router;

