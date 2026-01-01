const express = require('express');
const router = express.Router();
const ratingController = require('../controllers/rating.controller');
const authMiddleware = require('../middlewares/auth.middleware');

// Toutes les routes nécessitent une authentification JWT
router.post('/', authMiddleware, ratingController.createRating);
router.get('/ride/:rideId', authMiddleware, ratingController.getRatingsByRide);
router.get('/user/:userId', authMiddleware, ratingController.getRatingsByUser);
router.get('/:ratingId', authMiddleware, ratingController.getRatingById);

module.exports = router;



