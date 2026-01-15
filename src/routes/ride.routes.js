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
  validateReverseGeocode,
  validatePlacesAutocomplete,
  validatePlaceDetails
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
router.get('/places/autocomplete', 
  authMiddleware, 
  subscriptionMiddleware,
  rateLimitMiddleware(20, 60000), // 20 req/min
  validatePlacesAutocomplete, 
  rideController.placesAutocomplete
);
router.get('/places/details', 
  authMiddleware, 
  subscriptionMiddleware,
  rateLimitMiddleware(20, 60000), // 20 req/min
  validatePlaceDetails, 
  rideController.placeDetails
);
// Route pour accéder à une balade via son lien secret (AVANT /:id pour éviter les conflits)
router.get('/secret/:secretLink', authMiddleware, subscriptionMiddleware, rideController.getRideBySecretLink);

// Routes avec paramètre :id (doivent être en dernier)
router.get('/:id', authMiddleware, subscriptionMiddleware, validateRideId, rideController.getRideById);

// ========== WAYPOINTS ROUTES ==========
// Ajouter/modifier un waypoint
router.put('/:id/waypoints', authMiddleware, subscriptionMiddleware, validateRideId, rideController.addOrUpdateWaypoint);
// Supprimer un waypoint
router.delete('/:id/waypoints/:waypointId', authMiddleware, subscriptionMiddleware, validateRideId, rideController.deleteWaypoint);
// Obtenir le résumé des waypoints
router.get('/:id/waypoint-summary', authMiddleware, subscriptionMiddleware, validateRideId, rideController.getWaypointSummary);

// ========== DANGER REPORTS ROUTES ==========
// Signaler un danger (crowdsourcing)
router.post('/:id/waypoints/danger-report', authMiddleware, subscriptionMiddleware, validateRideId, rideController.reportDanger);
// Lister les signalements
router.get('/:id/danger-reports', authMiddleware, subscriptionMiddleware, validateRideId, rideController.getDangerReports);
// Approuver un signalement (organisateur)
router.post('/danger-reports/:reportId/approve', authMiddleware, subscriptionMiddleware, rideController.approveDangerReport);
// Rejeter un signalement (organisateur)
router.post('/danger-reports/:reportId/reject', authMiddleware, subscriptionMiddleware, rideController.rejectDangerReport);
// Promouvoir un signalement en waypoint (organisateur)
router.post('/danger-reports/:reportId/promote', authMiddleware, subscriptionMiddleware, rideController.promoteDangerReportToWaypoint);

// ========== MÉTÉO ==========
// Récupérer la météo pour une balade
router.get('/:id/weather', authMiddleware, subscriptionMiddleware, validateRideId, rideController.getRideWeather);

// ========== GROUP ASSOCIATION ==========
// Associer une balade à un groupe
router.post('/:id/associate-group', authMiddleware, subscriptionMiddleware, validateRideId, rideController.associateRideToGroup);

// ========== ANNULATION / REPORT / REPROGRAMMATION ==========
// Annuler une balade
router.post('/:id/cancel', authMiddleware, subscriptionMiddleware, validateRideId, rideController.cancelRide);
// Reporter une balade
router.post('/:id/postpone', authMiddleware, subscriptionMiddleware, validateRideId, rideController.postponeRide);
// Reprogrammer une balade (créer une nouvelle balade)
router.post('/:id/reschedule', authMiddleware, subscriptionMiddleware, validateRideId, rideController.rescheduleRide);

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

// ========== OUTILS ORGANISATEUR ==========
// Paramètres organisateur
router.put('/:id/organizer-settings', authMiddleware, subscriptionMiddleware, validateRideId, rideController.updateOrganizerSettings);

// Demandes de participation (validation manuelle)
router.post('/:id/request-join', authMiddleware, subscriptionMiddleware, validateRideId, rideController.requestToJoin);
router.get('/:id/pending-requests', authMiddleware, subscriptionMiddleware, validateRideId, rideController.getPendingRequests);
router.post('/:id/pending-requests/:userId/approve', authMiddleware, subscriptionMiddleware, validateRideId, rideController.approveRequest);
router.post('/:id/pending-requests/:userId/reject', authMiddleware, subscriptionMiddleware, validateRideId, rideController.rejectRequest);

// Liste d'attente
router.get('/:id/waitlist', authMiddleware, subscriptionMiddleware, validateRideId, rideController.getWaitlist);
router.post('/:id/waitlist/:userId/promote', authMiddleware, subscriptionMiddleware, validateRideId, rideController.promoteFromWaitlist);
router.delete('/:id/waitlist/:userId', authMiddleware, subscriptionMiddleware, validateRideId, rideController.removeFromWaitlist);

// Balades récurrentes
router.post('/:id/create-next-occurrence', authMiddleware, subscriptionMiddleware, validateRideId, rideController.createRecurringRide);

// Rappels
router.post('/:id/send-reminder', authMiddleware, subscriptionMiddleware, validateRideId, rideController.sendReminderToParticipants);

// ========== FONCTIONS AVANCÉES ==========
// Export GPX
router.get('/:id/export/gpx', authMiddleware, subscriptionMiddleware, validateRideId, rideController.exportRideGPX);
// Export PDF
router.get('/:id/export/pdf', authMiddleware, subscriptionMiddleware, validateRideId, rideController.exportRidePDF);
// Mise à jour visibilité (mode secret)
router.put('/:id/visibility', authMiddleware, subscriptionMiddleware, validateRideId, rideController.updateRideVisibility);

// ========== DANGER REPORTS ACTIONS (organisateur) ==========
// Approuver un signalement (organisateur)
router.post('/danger-reports/:reportId/approve', authMiddleware, subscriptionMiddleware, rideController.approveDangerReport);
// Rejeter un signalement (organisateur)
router.post('/danger-reports/:reportId/reject', authMiddleware, subscriptionMiddleware, rideController.rejectDangerReport);
// Promouvoir un signalement en waypoint (organisateur)
router.post('/danger-reports/:reportId/promote', authMiddleware, subscriptionMiddleware, rideController.promoteDangerReportToWaypoint);

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

