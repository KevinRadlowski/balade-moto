const express = require('express');
const router = express.Router();
const ratingController = require('../controllers/rating.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');

// Toutes les routes nécessitent une authentification JWT
router.post('/', authMiddleware, subscriptionMiddleware, ratingController.createRating);
router.get('/ride/:rideId', authMiddleware, subscriptionMiddleware, ratingController.getRatingsByRide);
router.get('/user/:userId', authMiddleware, subscriptionMiddleware, ratingController.getRatingsByUser);
router.get('/:ratingId', authMiddleware, subscriptionMiddleware, ratingController.getRatingById);

module.exports = router;



