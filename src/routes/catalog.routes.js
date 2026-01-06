const express = require('express');
const router = express.Router();
const catalogController = require('../controllers/catalog.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');

// POST /api/catalog/proposals - Créer une proposition
router.post('/proposals', authMiddleware, subscriptionMiddleware, catalogController.createProposal);

// GET /api/catalog/approved - Récupérer les entrées approuvées
router.get('/approved', authMiddleware, subscriptionMiddleware, catalogController.getApproved);

// GET /api/catalog/approved/makes - Récupérer toutes les marques approuvées (toutes années)
router.get('/approved/makes', authMiddleware, subscriptionMiddleware, catalogController.getApprovedMakes);

// GET /api/catalog/version - Récupérer la version du catalogue
router.get('/version', authMiddleware, subscriptionMiddleware, catalogController.getVersion);

module.exports = router;
