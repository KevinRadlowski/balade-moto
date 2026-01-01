const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const uploadAvatar = require('../middlewares/upload.middleware');
const uploadBackground = require('../middlewares/background-upload.middleware');

// Toutes les routes nécessitent une authentification
router.put('/update-profile', authMiddleware, userController.updateProfile);
router.put('/change-password', authMiddleware, userController.changePassword);
router.delete('/delete-account', authMiddleware, userController.deleteAccount);
router.post('/upload-avatar', authMiddleware, uploadAvatar, userController.uploadAvatar);
router.post('/upload-background', authMiddleware, uploadBackground, userController.uploadBackground);
router.delete('/delete-background/:type', authMiddleware, userController.deleteBackground);
router.get('/search', authMiddleware, userController.searchUsers);

module.exports = router;

