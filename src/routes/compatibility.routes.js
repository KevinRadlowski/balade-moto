const express = require('express');
const router = express.Router();
const compatibilityController = require('../controllers/compatibility.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const { validateCheckCompatibility } = require('../validators/compatibility.validator');

// Route nécessite une authentification
router.get('/check', authMiddleware, subscriptionMiddleware, validateCheckCompatibility, compatibilityController.checkCompatibility);

module.exports = router;







