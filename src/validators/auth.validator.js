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

// Validation pour l'inscription
exports.validateRegister = [
  body('email')
    .isEmail()
    .withMessage('L\'email doit être valide')
    .trim()
    .toLowerCase(), // Normaliser en minuscules (comme Mongoose le fait)
  body('password')
    .isLength({ min: 6 })
    .withMessage('Le mot de passe doit contenir au moins 6 caractères')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Le mot de passe doit contenir au moins une majuscule, une minuscule et un chiffre')
    .optional({ nullable: true }),
  body('pseudo')
    .trim()
    .isLength({ min: 3, max: 30 })
    .withMessage('Le pseudo doit contenir entre 3 et 30 caractères')
    .matches(/^[a-zA-Z0-9_-]+$/)
    .withMessage('Le pseudo ne peut contenir que des lettres, chiffres, tirets et underscores'),
  handleValidationErrors
];

// Validation pour la connexion
exports.validateLogin = [
  body('email')
    .isEmail()
    .withMessage('L\'email doit être valide')
    .trim()
    .toLowerCase(), // Normaliser en minuscules (comme Mongoose le fait)
  body('password')
    .notEmpty()
    .withMessage('Le mot de passe est requis'),
  handleValidationErrors
];

// Validation pour le refresh token
exports.validateRefreshToken = [
  body('refreshToken')
    .notEmpty()
    .withMessage('Le refresh token est requis')
    .isLength({ min: 80 })
    .withMessage('Le refresh token est invalide'),
  handleValidationErrors
];

// Validation pour la vérification d'email
exports.validateVerifyEmail = [
  body('token')
    .notEmpty()
    .withMessage('Le token de vérification est requis')
    .isLength({ min: 64 })
    .withMessage('Le token de vérification est invalide'),
  handleValidationErrors
];

// Validation pour la demande de renvoi d'email
exports.validateResendVerification = [
  body('email')
    .isEmail()
    .withMessage('L\'email doit être valide')
    .trim()
    .toLowerCase(), // Normaliser en minuscules (comme Mongoose le fait)
  handleValidationErrors
];

