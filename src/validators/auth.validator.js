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
  body('phone')
    .custom((value) => {
      // Vérifier que le téléphone est fourni
      if (!value || typeof value !== 'string' || value.trim().length === 0) {
        throw new Error('Le numéro de téléphone est obligatoire pour créer un compte. Veuillez renseigner votre numéro au format international (ex: +33612345678 pour la France, +14155552671 pour les États-Unis).');
      }
      // Vérifier qu'il contient au moins des chiffres
      const digitsOnly = value.replace(/\D/g, '');
      if (digitsOnly.length < 8) {
        throw new Error('Le numéro de téléphone doit contenir au moins 8 chiffres. Format attendu: indicatif pays + numéro (ex: +33612345678 pour la France).');
      }
      return true;
    }),
  handleValidationErrors
];

// Validation pour la connexion
// Accepte soit 'email' (rétrocompatibilité) soit 'identifier' (email ou téléphone)
exports.validateLogin = [
  body('identifier')
    .optional()
    .custom((value, { req }) => {
      // Si identifier est fourni, valider selon le type
      if (value) {
        if (value.includes('@')) {
          // C'est un email
          const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
          if (!emailRegex.test(value)) {
            throw new Error('L\'email doit être valide');
          }
        } else {
          // C'est probablement un téléphone - validation basique (sera normalisé côté controller)
          const phoneRegex = /^[\d\s\+\-\(\)]+$/;
          if (!phoneRegex.test(value) || value.replace(/\D/g, '').length < 8) {
            throw new Error('Le numéro de téléphone doit être valide');
          }
        }
      }
      return true;
    }),
  body('email')
    .optional()
    .isEmail()
    .withMessage('L\'email doit être valide')
    .trim()
    .toLowerCase(), // Normaliser en minuscules (comme Mongoose le fait)
  body('password')
    .notEmpty()
    .withMessage('Le mot de passe est requis'),
  // Vérifier qu'au moins identifier ou email est fourni
  body().custom((value, { req }) => {
    if (!value.identifier && !value.email) {
      throw new Error('Veuillez fournir un email ou un identifiant (email/téléphone)');
    }
    return true;
  }),
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

