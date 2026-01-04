const express = require('express');
const router = express.Router();
const adminRidesController = require('../controllers/admin.rides.controller');
const requireAdmin = require('../middlewares/requireAdmin.middleware');

// Toutes les routes admin nécessitent l'authentification admin
router.use(requireAdmin);

// GET /api/admin/rides - Liste des balades
router.get('/', adminRidesController.getRides);

// DELETE /api/admin/rides/:id - Supprimer une balade
router.delete('/:id', adminRidesController.deleteRide);

module.exports = router;

