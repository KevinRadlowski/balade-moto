const express = require('express');
const router = express.Router();
const adminPromoCodesController = require('../controllers/admin.promoCodes.controller');
const requireAdmin = require('../middlewares/requireAdmin.middleware');
const {
  validateGeneratePromoCodes,
  validatePromoCodeId
} = require('../validators/promoCode.validator');

// Toutes les routes admin nécessitent l'authentification admin
router.use(requireAdmin);

// POST /api/admin/promo-codes/generate - Générer des codes promotionnels
router.post('/generate', validateGeneratePromoCodes, adminPromoCodesController.generatePromoCodes);

// GET /api/admin/promo-codes - Liste des codes promotionnels
router.get('/', adminPromoCodesController.listPromoCodes);

// PATCH /api/admin/promo-codes/:id/deactivate - Désactiver un code
router.patch('/:id/deactivate', validatePromoCodeId, adminPromoCodesController.deactivatePromoCode);

module.exports = router;







