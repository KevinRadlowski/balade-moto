const { body, param, validationResult } = require('express-validator');

/**
 * Middleware pour gérer les erreurs de validation
 */
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

/**
 * Validation pour la génération de codes promotionnels (admin)
 */
exports.validateGeneratePromoCodes = [
  body('type')
    .notEmpty()
    .withMessage('Le type est requis')
    .isIn(['DISCOUNT_PERCENT', 'GRANT_PREMIUM_MONTHS', 'GRANT_PREMIUM_PERMANENT'])
    .withMessage('Le type doit être DISCOUNT_PERCENT, GRANT_PREMIUM_MONTHS ou GRANT_PREMIUM_PERMANENT'),
  body('count')
    .notEmpty()
    .withMessage('Le nombre de codes est requis')
    .isInt({ min: 1, max: 500 })
    .withMessage('Le nombre de codes doit être entre 1 et 500'),
  body('discountPercent')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Le pourcentage de réduction doit être entre 1 et 100')
    .custom((value, { req }) => {
      if (req.body.type === 'DISCOUNT_PERCENT' && !value) {
        throw new Error('discountPercent est requis pour DISCOUNT_PERCENT');
      }
      if (req.body.type !== 'DISCOUNT_PERCENT' && value) {
        throw new Error('discountPercent ne doit être fourni que pour DISCOUNT_PERCENT');
      }
      return true;
    }),
  body('premiumMonths')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Le nombre de mois Premium doit être >= 1')
    .custom((value, { req }) => {
      if (req.body.type === 'GRANT_PREMIUM_MONTHS' && !value) {
        throw new Error('premiumMonths est requis pour GRANT_PREMIUM_MONTHS');
      }
      if (req.body.type !== 'GRANT_PREMIUM_MONTHS' && value) {
        throw new Error('premiumMonths ne doit être fourni que pour GRANT_PREMIUM_MONTHS');
      }
      return true;
    }),
  body('usageLimit')
    .optional()
    .isInt({ min: 1 })
    .withMessage('La limite d\'utilisation doit être >= 1'),
  body('validFrom')
    .optional()
    .isISO8601()
    .withMessage('validFrom doit être une date au format ISO 8601'),
  body('validUntil')
    .optional()
    .isISO8601()
    .withMessage('validUntil doit être une date au format ISO 8601')
    .custom((value, { req }) => {
      if (req.body.validFrom && value) {
        const from = new Date(req.body.validFrom);
        const until = new Date(value);
        if (until <= from) {
          throw new Error('validUntil doit être après validFrom');
        }
      }
      return true;
    }),
  body('metadata')
    .optional()
    .isObject()
    .withMessage('metadata doit être un objet'),
  handleValidationErrors
];

/**
 * Validation pour l'utilisation d'un code promotionnel
 */
exports.validateRedeemPromoCode = [
  body('code')
    .notEmpty()
    .withMessage('Le code est requis')
    .trim()
    .isLength({ min: 15, max: 20 })
    .withMessage('Le code doit avoir entre 15 et 20 caractères')
    .matches(/^RT-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/i)
    .withMessage('Format de code invalide. Format attendu: RT-XXXX-XXXX-XXXX'),
  handleValidationErrors
];

/**
 * Validation pour la désactivation d'un code (paramètre ID)
 */
exports.validatePromoCodeId = [
  param('id')
    .notEmpty()
    .withMessage('L\'ID du code est requis')
    .isMongoId()
    .withMessage('L\'ID doit être un ObjectId MongoDB valide'),
  handleValidationErrors
];

