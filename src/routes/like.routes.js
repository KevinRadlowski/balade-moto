const express = require('express');
const router = express.Router();
const likeController = require('../controllers/like.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');

// Toutes les routes nécessitent une authentification JWT
router.post('/', authMiddleware, subscriptionMiddleware, likeController.toggleLike);
router.get('/ride/:rideId', authMiddleware, subscriptionMiddleware, likeController.getLikesByRide);
router.get('/user/:userId', authMiddleware, subscriptionMiddleware, likeController.getLikesByUser);

module.exports = router;



