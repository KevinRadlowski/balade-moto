const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');
const emergencyContactController = require('../controllers/emergencyContact.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const rateLimitMiddleware = require('../middlewares/rateLimit.middleware');
const uploadAvatar = require('../middlewares/upload.middleware');
const uploadBackground = require('../middlewares/background-upload.middleware');
const {
  validateEmergencyContact,
  validateTriggerAlert
} = require('../validators/emergencyContact.validator');

// Toutes les routes nécessitent une authentification
router.put('/update-profile', authMiddleware, userController.updateProfile);
router.put('/change-password', authMiddleware, userController.changePassword);
router.delete('/delete-account', authMiddleware, userController.deleteAccount);
router.post('/upload-avatar', authMiddleware, uploadAvatar, userController.uploadAvatar);
router.post('/upload-background', authMiddleware, uploadBackground, userController.uploadBackground);
router.delete('/delete-background/:type', authMiddleware, userController.deleteBackground);
router.get('/search', authMiddleware, userController.searchUsers);

// Routes contact d'urgence
router.get('/emergency-contact', authMiddleware, emergencyContactController.getEmergencyContact);
router.post('/emergency-contact', authMiddleware, validateEmergencyContact, emergencyContactController.updateEmergencyContact);
router.patch('/emergency-contact', authMiddleware, validateEmergencyContact, emergencyContactController.updateEmergencyContact);
router.delete('/emergency-contact', authMiddleware, emergencyContactController.deleteEmergencyContact);
router.post('/emergency-contact/trigger-alert', 
  authMiddleware, 
  rateLimitMiddleware(3, 60000), // 3 req/min pour les alertes
  validateTriggerAlert, 
  emergencyContactController.triggerEmergencyAlert
);

module.exports = router;

