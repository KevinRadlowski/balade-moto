const express = require('express');
const router = express.Router();
const vehicleCatalogController = require('../controllers/vehicle-catalog.controller');
const authMiddleware = require('../middlewares/auth.middleware');

// Toutes les routes nécessitent une authentification
router.use(authMiddleware);

/**
 * @swagger
 * /api/vehicle-catalog/makes:
 *   get:
 *     summary: Récupère les marques de véhicules
 *     tags: [Vehicle Catalog]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: type
 *         required: true
 *         schema:
 *           type: string
 *           enum: [voiture, moto]
 *         description: Type de véhicule
 *       - in: query
 *         name: year
 *         schema:
 *           type: integer
 *         description: Année (optionnel, ignoré pour l'instant)
 *     responses:
 *       200:
 *         description: Liste des marques
 *       400:
 *         description: Paramètres invalides
 *       401:
 *         description: Non authentifié
 */
router.get('/makes', vehicleCatalogController.getMakes);

/**
 * @swagger
 * /api/vehicle-catalog/models:
 *   get:
 *     summary: Récupère les modèles pour une marque
 *     tags: [Vehicle Catalog]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: type
 *         required: true
 *         schema:
 *           type: string
 *           enum: [voiture, moto]
 *         description: Type de véhicule
 *       - in: query
 *         name: make
 *         required: true
 *         schema:
 *           type: string
 *         description: ID de la marque
 *       - in: query
 *         name: year
 *         schema:
 *           type: integer
 *         description: Année (optionnel, ignoré pour l'instant)
 *     responses:
 *       200:
 *         description: Liste des modèles
 *       400:
 *         description: Paramètres invalides
 *       401:
 *         description: Non authentifié
 */
router.get('/models', vehicleCatalogController.getModels);

module.exports = router;

