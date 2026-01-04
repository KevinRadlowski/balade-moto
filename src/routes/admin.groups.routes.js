const express = require('express');
const router = express.Router();
const adminGroupsController = require('../controllers/admin.groups.controller');
const requireAdmin = require('../middlewares/requireAdmin.middleware');

// Toutes les routes admin nécessitent l'authentification admin
router.use(requireAdmin);

// GET /api/admin/groups - Liste des groupes
router.get('/', adminGroupsController.getGroups);

// DELETE /api/admin/groups/:id - Supprimer un groupe
router.delete('/:id', adminGroupsController.deleteGroup);

module.exports = router;

