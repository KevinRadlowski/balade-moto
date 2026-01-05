const { query, param, validationResult } = require('express-validator');

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

// Validation pour la recherche de marques
exports.validateGetMakes = [
  query('search')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Le terme de recherche ne peut pas dépasser 100 caractères'),
  handleValidationErrors
];

// Validation pour la recherche de modèles
exports.validateGetModels = [
  param('makeName')
    .trim()
    .notEmpty()
    .withMessage('Le nom de la marque est requis')
    .isLength({ max: 100 })
    .withMessage('Le nom de la marque ne peut pas dépasser 100 caractères'),
  query('year')
    .optional()
    .isInt({ min: 1900, max: new Date().getFullYear() + 1 })
    .withMessage(`L'année doit être entre 1900 et ${new Date().getFullYear() + 1}`),
  handleValidationErrors
];





