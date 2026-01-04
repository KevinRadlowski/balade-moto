const { body, validationResult } = require('express-validator');

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

// Validation pour créer/mettre à jour le contact d'urgence
exports.validateEmergencyContact = [
  body('name')
    .notEmpty()
    .withMessage('Le nom est requis')
    .trim()
    .isLength({ max: 100 })
    .withMessage('Le nom ne peut pas dépasser 100 caractères'),
  body('phone')
    .notEmpty()
    .withMessage('Le téléphone est requis')
    .trim()
    .custom((value) => {
      // Vérifier si c'est un email valide
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (emailRegex.test(value)) {
        return true;
      }
      // Vérifier si c'est un numéro de téléphone valide
      // Format français: 0 suivi de 9 chiffres (ex: 0612345678 = 10 chiffres)
      // Format international: + suivi de 8-15 chiffres
      // Format numérique simple: 8-15 chiffres
      const phoneRegex = /^(\+?\d{8,15}|0\d{9})$/;
      if (phoneRegex.test(value)) {
        return true;
      }
      throw new Error('Le téléphone doit être un numéro valide (minimum 8 chiffres) ou un email');
    }),
  body('relation')
    .optional()
    .isIn(['family', 'friend', 'colleague', 'other'])
    .withMessage('relation doit être "family", "friend", "colleague" ou "other"'),
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Les notes ne peuvent pas dépasser 500 caractères'),
  handleValidationErrors
];

// Validation pour déclencher une alerte
exports.validateTriggerAlert = [
  body('reason')
    .notEmpty()
    .withMessage('La raison de l\'alerte est requise')
    .trim()
    .isLength({ max: 500 })
    .withMessage('La raison ne peut pas dépasser 500 caractères'),
  handleValidationErrors
];

