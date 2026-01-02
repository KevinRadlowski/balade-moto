const { query, validationResult } = require('express-validator');

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

// Validation pour la recherche de marques (nouveaux endpoints CarAPI avec year)
exports.validateGetMakes = [
  query('year')
    .trim()
    .notEmpty()
    .withMessage('Le paramètre year est requis')
    .isInt({ min: 1900, max: new Date().getFullYear() + 1 })
    .withMessage(`L'année doit être entre 1900 et ${new Date().getFullYear() + 1}`)
    .toInt(),
  handleValidationErrors
];

// Validation pour la recherche de marques (ancien endpoint CarQuery avec type - compatibilité)
exports.validateGetMakesLegacy = [
  query('type')
    .trim()
    .notEmpty()
    .withMessage('Le paramètre type est requis')
    .isIn(['moto', 'voiture'])
    .withMessage('Le type doit être "moto" ou "voiture"')
    .customSanitizer((value) => {
      return value ? value.trim().toLowerCase() : value;
    }),
  handleValidationErrors
];

// Validation pour la recherche de modèles
exports.validateGetModels = [
  query('year')
    .trim()
    .notEmpty()
    .withMessage('Le paramètre year est requis')
    .isInt({ min: 1900, max: new Date().getFullYear() + 1 })
    .withMessage(`L'année doit être entre 1900 et ${new Date().getFullYear() + 1}`)
    .toInt(),
  query('makeId')
    .optional()
    .trim()
    .isInt({ min: 1 })
    .withMessage('makeId doit être un entier positif')
    .toInt(),
  query('make')
    .optional()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Le nom de la marque doit contenir entre 1 et 100 caractères')
    .matches(/^[a-zA-Z0-9\s\-'&.\/]+$/)
    .withMessage('Le nom de la marque contient des caractères invalides')
    .customSanitizer((value) => {
      // Sanitize: trim et normaliser les espaces multiples
      return value ? value.trim().replace(/\s+/g, ' ') : value;
    }),
  // Validation personnalisée: makeId OU make doit être fourni
  query().custom((value) => {
    const makeId = value.makeId;
    const make = value.make;
    if (!makeId && (!make || make.trim().length === 0)) {
      throw new Error('Le paramètre make ou makeId est requis');
    }
    return true;
  }),
  handleValidationErrors
];

