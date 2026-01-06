const express = require('express');
const router = express.Router();
const reviewController = require('../controllers/review.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');

// Toutes les routes nécessitent une authentification JWT
router.post('/rides/:rideId', authMiddleware, subscriptionMiddleware, reviewController.createOrUpdateReview);
router.get('/rides/:rideId', authMiddleware, subscriptionMiddleware, reviewController.getRideReviews);
router.get('/rides/:rideId/check', authMiddleware, subscriptionMiddleware, reviewController.hasUserReviewed);

module.exports = router;

