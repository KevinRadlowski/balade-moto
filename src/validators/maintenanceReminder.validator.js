const { body, param, validationResult } = require('express-validator');

// Middleware pour gérer les erreurs de validation
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Erreurs de validation',
      errors: errors.array().map(err => ({
        field: err.path || err.param,
        message: err.msg,
        value: err.value
      }))
    });
  }
  next();
};

// Validation pour créer un rappel
exports.validateCreateReminder = [
  body('vehicleId')
    .notEmpty()
    .withMessage('vehicleId est requis')
    .isMongoId()
    .withMessage('vehicleId doit être un ID MongoDB valide'),
  body('type')
    .isIn(['oil', 'tire', 'brake', 'inspection', 'filter', 'battery', 'coolant', 'other'])
    .withMessage('type doit être une valeur valide'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('La description ne peut pas dépasser 500 caractères'),
  body('intervalKm')
    .optional()
    .isInt({ min: 0 })
    .withMessage('intervalKm doit être un nombre positif'),
  body('intervalMonths')
    .optional()
    .isInt({ min: 0 })
    .withMessage('intervalMonths doit être un nombre positif'),
  body('lastDoneKm')
    .optional()
    .isInt({ min: 0 })
    .withMessage('lastDoneKm doit être un nombre positif'),
  body('lastDoneDate')
    .optional()
    .isISO8601()
    .withMessage('lastDoneDate doit être au format ISO 8601'),
  handleValidationErrors
];

// Validation pour mettre à jour un rappel
exports.validateUpdateReminder = [
  param('id')
    .isMongoId()
    .withMessage('ID invalide'),
  body('type')
    .optional()
    .isIn(['oil', 'tire', 'brake', 'inspection', 'filter', 'battery', 'coolant', 'other'])
    .withMessage('type doit être une valeur valide'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('La description ne peut pas dépasser 500 caractères'),
  body('status')
    .optional()
    .isIn(['active', 'snoozed', 'completed', 'cancelled'])
    .withMessage('status doit être une valeur valide'),
  handleValidationErrors
];

// Validation pour snooze
exports.validateSnooze = [
  param('id')
    .isMongoId()
    .withMessage('ID invalide'),
  body('days')
    .notEmpty()
    .withMessage('days est requis')
    .isInt({ min: 1, max: 30 })
    .withMessage('days doit être entre 1 et 30'),
  handleValidationErrors
];

// Validation pour marquer comme terminé
exports.validateMarkAsDone = [
  param('id')
    .isMongoId()
    .withMessage('ID invalide'),
  body('odometerKm')
    .optional()
    .isInt({ min: 0 })
    .withMessage('odometerKm doit être un nombre positif'),
  handleValidationErrors
];


