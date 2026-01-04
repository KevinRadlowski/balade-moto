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

// Validation pour calculateRoute
exports.validateCalculateRoute = [
  query('origin')
    .trim()
    .notEmpty()
    .withMessage('Le paramètre origin est requis')
    .isLength({ min: 1, max: 500 })
    .withMessage('L\'origine doit faire entre 1 et 500 caractères')
    .custom((value) => {
      // Vérifier qu'il n'y a pas de caractères dangereux
      if (/[<>\"'&]/.test(value)) {
        throw new Error('L\'origine contient des caractères non autorisés');
      }
      return true;
    }),
  query('destination')
    .trim()
    .notEmpty()
    .withMessage('Le paramètre destination est requis')
    .isLength({ min: 1, max: 500 })
    .withMessage('La destination doit faire entre 1 et 500 caractères')
    .custom((value) => {
      if (/[<>\"'&]/.test(value)) {
        throw new Error('La destination contient des caractères non autorisés');
      }
      return true;
    }),
  query('waypoints')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Les waypoints ne peuvent pas dépasser 2000 caractères')
    .custom((value) => {
      if (value && /[<>\"'&]/.test(value)) {
        throw new Error('Les waypoints contiennent des caractères non autorisés');
      }
      return true;
    }),
  handleValidationErrors
];

// Validation pour geocodeAddress
exports.validateGeocodeAddress = [
  query('address')
    .trim()
    .notEmpty()
    .withMessage('Le paramètre address est requis')
    .isLength({ min: 1, max: 500 })
    .withMessage('L\'adresse doit faire entre 1 et 500 caractères')
    .custom((value) => {
      if (/[<>\"'&]/.test(value)) {
        throw new Error('L\'adresse contient des caractères non autorisés');
      }
      return true;
    }),
  handleValidationErrors
];

// Validation pour reverseGeocode
exports.validateReverseGeocode = [
  query('lat')
    .notEmpty()
    .withMessage('Le paramètre lat est requis')
    .isFloat({ min: -90, max: 90 })
    .withMessage('La latitude doit être entre -90 et 90')
    .toFloat(),
  query('lng')
    .notEmpty()
    .withMessage('Le paramètre lng est requis')
    .isFloat({ min: -180, max: 180 })
    .withMessage('La longitude doit être entre -180 et 180')
    .toFloat(),
  handleValidationErrors
];




