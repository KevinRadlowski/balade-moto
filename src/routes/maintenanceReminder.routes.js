const express = require('express');
const router = express.Router();
const maintenanceReminderController = require('../controllers/maintenanceReminder.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const {
  validateCreateReminder,
  validateUpdateReminder,
  validateSnooze,
  validateMarkAsDone
} = require('../validators/maintenanceReminder.validator');

// Toutes les routes nécessitent une authentification
router.get('/', authMiddleware, maintenanceReminderController.getReminders);
router.post('/', authMiddleware, validateCreateReminder, maintenanceReminderController.createReminder);
router.get('/:id', authMiddleware, maintenanceReminderController.getReminderById);
router.patch('/:id', authMiddleware, validateUpdateReminder, maintenanceReminderController.updateReminder);
router.delete('/:id', authMiddleware, maintenanceReminderController.deleteReminder);
router.post('/:id/snooze', authMiddleware, validateSnooze, maintenanceReminderController.snoozeReminder);
router.post('/:id/done', authMiddleware, validateMarkAsDone, maintenanceReminderController.markAsDone);

module.exports = router;



