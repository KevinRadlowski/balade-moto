const { param, body, validationResult } = require('express-validator');

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

// Validation pour l'ID de balade
exports.validateRideId = [
  param('id')
    .isMongoId()
    .withMessage('ID invalide'),
  handleValidationErrors
];

// Validation pour signaler un incident
exports.validateReportIncident = [
  param('id')
    .isMongoId()
    .withMessage('ID invalide'),
  body('description')
    .notEmpty()
    .withMessage('La description est requise')
    .trim()
    .isLength({ max: 500 })
    .withMessage('La description ne peut pas dépasser 500 caractères'),
  body('location')
    .optional()
    .isObject()
    .withMessage('location doit être un objet'),
  body('location.latitude')
    .optional()
    .isFloat({ min: -90, max: 90 })
    .withMessage('latitude doit être entre -90 et 90'),
  body('location.longitude')
    .optional()
    .isFloat({ min: -180, max: 180 })
    .withMessage('longitude doit être entre -180 et 180'),
  handleValidationErrors
];

// Validation pour heartbeat
exports.validateHeartbeat = [
  param('id')
    .isMongoId()
    .withMessage('ID invalide'),
  body('location')
    .optional()
    .isObject()
    .withMessage('location doit être un objet'),
  body('location.latitude')
    .optional()
    .isFloat({ min: -90, max: 90 })
    .withMessage('latitude doit être entre -90 et 90'),
  body('location.longitude')
    .optional()
    .isFloat({ min: -180, max: 180 })
    .withMessage('longitude doit être entre -180 et 180'),
  handleValidationErrors
];




