const { body, param, query, validationResult } = require('express-validator');

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

// Validation pour la création d'un feedback
exports.validateCreateFeedback = [
  body('entityType')
    .isIn(['ride', 'user'])
    .withMessage('entityType doit être "ride" ou "user"'),
  body('entityId')
    .notEmpty()
    .withMessage('entityId est requis')
    .isMongoId()
    .withMessage('entityId doit être un ID MongoDB valide'),
  body('type')
    .isIn(['rating', 'review', 'suggestion', 'bug_report'])
    .withMessage('type doit être "rating", "review", "suggestion" ou "bug_report"'),
  body('rating')
    .optional()
    .isInt({ min: 1, max: 5 })
    .withMessage('rating doit être entre 1 et 5'),
  body('comment')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Le commentaire ne peut pas dépasser 2000 caractères'),
  handleValidationErrors
];

// Validation pour la mise à jour d'un feedback
exports.validateUpdateFeedback = [
  param('id')
    .isMongoId()
    .withMessage('ID invalide'),
  body('rating')
    .optional()
    .isInt({ min: 1, max: 5 })
    .withMessage('rating doit être entre 1 et 5'),
  body('comment')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Le commentaire ne peut pas dépasser 2000 caractères'),
  handleValidationErrors
];

// Validation pour la suppression d'un feedback
exports.validateFeedbackId = [
  param('id')
    .isMongoId()
    .withMessage('ID invalide'),
  handleValidationErrors
];



