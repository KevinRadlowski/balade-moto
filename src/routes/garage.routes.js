const express = require('express');
const router = express.Router();
const garageController = require('../controllers/garage.controller');
// Routes vPIC supprimées - utilisation de /api/catalog/carquery à la place
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const uploadVehiclePhoto = require('../middlewares/vehicle-upload.middleware');
const uploadVehiclePhotos = uploadVehiclePhoto.multiple;
const uploadVehicleDocument = require('../middlewares/vehicle-document-upload.middleware');
const uploadMaintenanceLogDocument = require('../middlewares/maintenance-log-document-upload.middleware');
const {
  validateCreateVehicle,
  validateUpdateVehicle,
  validateGetVehicles,
  validateVehicleId,
  validateCreateOdometer,
  validateGetOdometers,
  validateCreateMaintenanceItem,
  validateUpdateMaintenanceItem,
  validateCreateMaintenanceLog,
  validateUpdateMaintenanceLog,
  validateGetMaintenanceLogs,
  validateMaintenanceLogId,
  validateMaintenanceItemId,
  validateCreateDocument,
  validateUpdateDocument,
  validateGetDocuments,
  validateDocumentId
} = require('../validators/garage.validator');

// Toutes les routes nécessitent une authentification JWT
router.use(authMiddleware);
router.use(subscriptionMiddleware);

// Contrôleurs additionnels (définis avant leur utilisation)
const vehicleStatsController = require('../controllers/vehicleStats.controller');
const {
  validateVehicleId: validateVehicleIdStats,
  validateUpdateStats
} = require('../validators/vehicleStats.validator');

// Routes pour les véhicules
router.post('/vehicles', validateCreateVehicle, garageController.createVehicle);
router.get('/vehicles', validateGetVehicles, garageController.getVehicles);
router.get('/vehicles/:id', validateVehicleId, garageController.getVehicle);
router.patch('/vehicles/:id', validateVehicleId, validateUpdateVehicle, garageController.updateVehicle);
router.delete('/vehicles/:id', validateVehicleId, garageController.deleteVehicle);
// Route pour les statistiques d'un véhicule (format alternatif compatible avec le frontend)
router.get('/vehicles/:id/stats', validateVehicleId, (req, res, next) => {
  req.params.vehicleId = req.params.id;
  return vehicleStatsController.getVehicleStats(req, res, next);
});
// Upload d'une seule photo (compatibilité)
router.post('/vehicles/:id/photo', validateVehicleId, uploadVehiclePhoto, garageController.uploadVehiclePhoto);

// Galerie de photos : ajouter plusieurs photos
router.get('/vehicles/:id/photos', validateVehicleId, garageController.listVehiclePhotos);
router.post('/vehicles/:id/photos', validateVehicleId, uploadVehiclePhotos, garageController.addVehiclePhotos);

// Galerie de photos : supprimer une photo
router.delete('/vehicles/:id/photos/:photoIndex', validateVehicleId, garageController.deleteVehiclePhoto);

// Routes pour les entrées odomètre
router.post('/vehicles/:id/odometer', validateVehicleId, validateCreateOdometer, garageController.createOdometer);
router.get('/vehicles/:id/odometer', validateVehicleId, validateGetOdometers, garageController.getOdometers);

// Routes pour les éléments de maintenance
router.post('/vehicles/:id/maintenance/items', validateVehicleId, validateCreateMaintenanceItem, garageController.createMaintenanceItem);
router.get('/vehicles/:id/maintenance/dashboard', validateVehicleId, garageController.getMaintenanceDashboard);
router.get('/vehicles/:id/maintenance/suggestions', validateVehicleId, garageController.getMaintenanceSuggestions);
router.patch('/vehicles/:id/maintenance/items/:itemId', validateVehicleId, validateMaintenanceItemId, validateUpdateMaintenanceItem, garageController.updateMaintenanceItem);
router.delete('/vehicles/:id/maintenance/items/:itemId', validateVehicleId, validateMaintenanceItemId, garageController.deleteMaintenanceItem);

// Routes pour les logs de maintenance
router.post('/vehicles/:id/maintenance/logs', validateVehicleId, uploadMaintenanceLogDocument, validateCreateMaintenanceLog, garageController.createMaintenanceLog);
router.get('/vehicles/:id/maintenance/logs', validateVehicleId, validateGetMaintenanceLogs, garageController.getMaintenanceLogs);
router.get('/vehicles/:id/maintenance/logs/:logId', validateVehicleId, validateMaintenanceLogId, garageController.getMaintenanceLog);
router.patch('/vehicles/:id/maintenance/logs/:logId', validateVehicleId, validateMaintenanceLogId, uploadMaintenanceLogDocument, validateUpdateMaintenanceLog, garageController.updateMaintenanceLog);
router.delete('/vehicles/:id/maintenance/logs/:logId', validateVehicleId, validateMaintenanceLogId, garageController.deleteMaintenanceLog);

// Routes pour les documents
router.post('/vehicles/:id/documents', validateVehicleId, uploadVehicleDocument, validateCreateDocument, garageController.createDocument);
router.get('/vehicles/:id/documents', validateVehicleId, validateGetDocuments, garageController.getDocuments);
router.get('/vehicles/:id/documents/:documentId', validateVehicleId, validateDocumentId, garageController.getDocument);
router.patch('/vehicles/:id/documents/:documentId', validateVehicleId, validateDocumentId, validateUpdateDocument, garageController.updateDocument);
router.delete('/vehicles/:id/documents/:documentId', validateVehicleId, validateDocumentId, garageController.deleteDocument);

// Routes pour la recherche vPIC (catalogue véhicules)
// Routes vPIC supprimées - utilisation de /api/catalog/carquery à la place

// Routes pour les statistiques véhicule
router.get('/vehicle-stats/:vehicleId', validateVehicleIdStats, vehicleStatsController.getVehicleStats);
router.post('/vehicle-stats/:vehicleId/update', validateVehicleIdStats, validateUpdateStats, vehicleStatsController.updateVehicleStats);

// Routes pour les rappels d'entretien
const maintenanceReminderController = require('../controllers/maintenanceReminder.controller');
const {
  validateCreateReminder,
  validateUpdateReminder,
  validateSnooze,
  validateMarkAsDone
} = require('../validators/maintenanceReminder.validator');
router.get('/maintenance-reminders', maintenanceReminderController.getReminders);
router.post('/maintenance-reminders', validateCreateReminder, maintenanceReminderController.createReminder);
router.get('/maintenance-reminders/:id', maintenanceReminderController.getReminderById);
router.patch('/maintenance-reminders/:id', validateUpdateReminder, maintenanceReminderController.updateReminder);
router.delete('/maintenance-reminders/:id', maintenanceReminderController.deleteReminder);
router.post('/maintenance-reminders/:id/snooze', validateSnooze, maintenanceReminderController.snoozeReminder);
router.post('/maintenance-reminders/:id/done', validateMarkAsDone, maintenanceReminderController.markAsDone);

module.exports = router;

