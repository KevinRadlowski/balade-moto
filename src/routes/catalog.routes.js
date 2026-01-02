const express = require('express');
const router = express.Router();
const catalogController = require('../controllers/catalog.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const rateLimitMiddleware = require('../middlewares/rateLimit.middleware');
const {
  validateGetMakes,
  validateGetMakesLegacy,
  validateGetModels
} = require('../validators/catalog.validator');

// Toutes les routes nécessitent une authentification JWT
router.use(authMiddleware);

// Rate limiting léger : 30 requêtes par minute par utilisateur
const catalogRateLimit = rateLimitMiddleware(30, 60000);

// Routes pour le catalogue CarAPI.app
// Voitures
router.get('/voiture/makes', catalogRateLimit, validateGetMakes, catalogController.getCarMakes);
router.get('/voiture/models', catalogRateLimit, validateGetModels, catalogController.getCarModels);
// Motos
router.get('/moto/makes', catalogRateLimit, validateGetMakes, catalogController.getMotoMakes);
router.get('/moto/models', catalogRateLimit, validateGetModels, catalogController.getMotoModels);

// Routes CarQuery dépréciées (conservées pour compatibilité temporaire)
router.get('/carquery/makes', catalogRateLimit, validateGetMakesLegacy, catalogController.getMakes);
router.get('/carquery/models', catalogRateLimit, validateGetModels, catalogController.getModels);

module.exports = router;

