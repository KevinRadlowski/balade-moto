const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');
const emergencyContactController = require('../controllers/emergencyContact.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const rateLimitMiddleware = require('../middlewares/rateLimit.middleware');
const uploadAvatar = require('../middlewares/upload.middleware');
const uploadBackground = require('../middlewares/background-upload.middleware');
const {
  validateEmergencyContact,
  validateTriggerAlert
} = require('../validators/emergencyContact.validator');

// Toutes les routes nécessitent une authentification
router.put('/update-profile', authMiddleware, subscriptionMiddleware, userController.updateProfile);
router.post('/change-password', authMiddleware, subscriptionMiddleware, userController.changePassword);
router.delete('/delete-account', authMiddleware, subscriptionMiddleware, userController.deleteAccount);
router.post('/upload-avatar', authMiddleware, subscriptionMiddleware, uploadAvatar, userController.uploadAvatar);
router.post('/upload-background', authMiddleware, subscriptionMiddleware, uploadBackground, userController.uploadBackground);
router.delete('/delete-background/:type', authMiddleware, subscriptionMiddleware, userController.deleteBackground);
router.get('/search', authMiddleware, subscriptionMiddleware, userController.searchUsers);
router.get('/me/plan', authMiddleware, subscriptionMiddleware, userController.getMyPlan);

// Routes contact d'urgence
router.get('/emergency-contact', authMiddleware, subscriptionMiddleware, emergencyContactController.getEmergencyContact);
router.post('/emergency-contact', authMiddleware, subscriptionMiddleware, validateEmergencyContact, emergencyContactController.updateEmergencyContact);
router.patch('/emergency-contact', authMiddleware, subscriptionMiddleware, validateEmergencyContact, emergencyContactController.updateEmergencyContact);
router.delete('/emergency-contact', authMiddleware, subscriptionMiddleware, emergencyContactController.deleteEmergencyContact);
router.post('/emergency-contact/trigger-alert', 
  authMiddleware, 
  subscriptionMiddleware,
  rateLimitMiddleware(3, 60000), // 3 req/min pour les alertes
  validateTriggerAlert, 
  emergencyContactController.triggerEmergencyAlert
);

module.exports = router;

