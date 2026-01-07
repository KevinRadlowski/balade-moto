const express = require('express');
const router = express.Router();
const maintenanceReminderController = require('../controllers/maintenanceReminder.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const {
  validateCreateReminder,
  validateUpdateReminder,
  validateSnooze,
  validateMarkAsDone
} = require('../validators/maintenanceReminder.validator');

// Toutes les routes nécessitent une authentification
router.get('/', authMiddleware, subscriptionMiddleware, maintenanceReminderController.getReminders);
router.post('/', authMiddleware, subscriptionMiddleware, validateCreateReminder, maintenanceReminderController.createReminder);
router.get('/:id', authMiddleware, subscriptionMiddleware, maintenanceReminderController.getReminderById);
router.patch('/:id', authMiddleware, subscriptionMiddleware, validateUpdateReminder, maintenanceReminderController.updateReminder);
router.delete('/:id', authMiddleware, subscriptionMiddleware, maintenanceReminderController.deleteReminder);
router.post('/:id/snooze', authMiddleware, subscriptionMiddleware, validateSnooze, maintenanceReminderController.snoozeReminder);
router.post('/:id/done', authMiddleware, subscriptionMiddleware, validateMarkAsDone, maintenanceReminderController.markAsDone);

module.exports = router;






