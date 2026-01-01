const express = require('express');
const router = express.Router();
const reviewController = require('../controllers/review.controller');
const authMiddleware = require('../middlewares/auth.middleware');

// Toutes les routes nécessitent une authentification JWT
router.post('/rides/:rideId', authMiddleware, reviewController.createOrUpdateReview);
router.get('/rides/:rideId', authMiddleware, reviewController.getRideReviews);
router.get('/rides/:rideId/check', authMiddleware, reviewController.hasUserReviewed);

module.exports = router;

