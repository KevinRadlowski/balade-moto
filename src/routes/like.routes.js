const express = require('express');
const router = express.Router();
const likeController = require('../controllers/like.controller');
const authMiddleware = require('../middlewares/auth.middleware');

// Toutes les routes nécessitent une authentification JWT
router.post('/', authMiddleware, likeController.toggleLike);
router.get('/ride/:rideId', authMiddleware, likeController.getLikesByRide);
router.get('/user/:userId', authMiddleware, likeController.getLikesByUser);

module.exports = router;



