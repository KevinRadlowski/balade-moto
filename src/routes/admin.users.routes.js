const express = require('express');
const router = express.Router();
const adminUsersController = require('../controllers/admin.users.controller');
const requireAdmin = require('../middlewares/requireAdmin.middleware');

// Toutes les routes admin nécessitent l'authentification admin
router.use(requireAdmin);

// GET /api/admin/users - Liste des utilisateurs
router.get('/', adminUsersController.getUsers);

// POST /api/admin/users - Créer un utilisateur
router.post('/', adminUsersController.createUser);

// PATCH /api/admin/users/:id - Mettre à jour un utilisateur
router.patch('/:id', adminUsersController.updateUser);

// DELETE /api/admin/users/:id - Supprimer un utilisateur
router.delete('/:id', adminUsersController.deleteUser);

module.exports = router;

