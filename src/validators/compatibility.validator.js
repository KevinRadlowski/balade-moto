const { query, validationResult } = require('express-validator');

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

// Validation pour vérifier la compatibilité
exports.validateCheckCompatibility = [
  query('userId1')
    .notEmpty()
    .withMessage('userId1 est requis')
    .isMongoId()
    .withMessage('userId1 doit être un ID MongoDB valide'),
  query('userId2')
    .notEmpty()
    .withMessage('userId2 est requis')
    .isMongoId()
    .withMessage('userId2 doit être un ID MongoDB valide'),
  query('rideId')
    .optional()
    .isMongoId()
    .withMessage('rideId doit être un ID MongoDB valide'),
  handleValidationErrors
];



