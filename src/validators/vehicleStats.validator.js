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

// Validation pour récupérer les stats
exports.validateVehicleId = [
  param('vehicleId')
    .isMongoId()
    .withMessage('vehicleId doit être un ID MongoDB valide'),
  handleValidationErrors
];

// Validation pour mettre à jour les stats
exports.validateUpdateStats = [
  param('vehicleId')
    .isMongoId()
    .withMessage('vehicleId doit être un ID MongoDB valide'),
  body('distanceKm')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('distanceKm doit être un nombre positif'),
  body('cost')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('cost doit être un nombre positif'),
  handleValidationErrors
];


