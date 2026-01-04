const express = require('express');
const router = express.Router();
const adminCatalogController = require('../controllers/admin.catalog.controller');
const requireAdmin = require('../middlewares/requireAdmin.middleware');

// Toutes les routes admin nécessitent l'authentification admin
router.use(requireAdmin);

// GET /api/admin/catalog/proposals - Liste des propositions
router.get('/proposals', adminCatalogController.getProposals);

// POST /api/admin/catalog/proposals/:id/approve - Approuver une proposition
router.post('/proposals/:id/approve', adminCatalogController.approveProposal);

// POST /api/admin/catalog/proposals/:id/reject - Rejeter une proposition
router.post('/proposals/:id/reject', adminCatalogController.rejectProposal);

module.exports = router;

