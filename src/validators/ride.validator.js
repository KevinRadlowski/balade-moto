const { body, query, param, validationResult } = require('express-validator');

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

// Validation pour la création d'une balade
exports.validateCreateRide = [
  body('titre')
    .trim()
    .notEmpty()
    .withMessage('Le titre est requis')
    .isLength({ max: 200 })
    .withMessage('Le titre ne peut pas dépasser 200 caractères'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('La description ne peut pas dépasser 2000 caractères'),
  body('typeVehicule')
    .isIn(['moto', 'voiture'])
    .withMessage('Le type de véhicule doit être "moto" ou "voiture"'),
  body('date')
    .notEmpty()
    .withMessage('La date est requise')
    .isISO8601()
    .withMessage('La date doit être au format ISO 8601')
    .custom((value) => {
      const date = new Date(value);
      if (date < new Date()) {
        throw new Error('La date de la balade doit être dans le futur');
      }
      return true;
    }),
  body('heure')
    .notEmpty()
    .withMessage('L\'heure est requise')
    .matches(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/)
    .withMessage('Format d\'heure invalide (HH:MM)'),
  body('rayon')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le rayon doit être un nombre positif'),
  body('visibilite')
    .optional()
    .isIn(['publique', 'privee'])
    .withMessage('La visibilité doit être "publique" ou "privee"'),
  body('waypoints')
    .optional()
    .isArray({ min: 2 })
    .withMessage('Les waypoints doivent être un tableau d\'au moins 2 éléments')
    .custom((waypoints) => {
      if (!waypoints || waypoints.length < 2) {
        throw new Error('Au moins 2 waypoints sont requis (départ et arrivée)');
      }
      
      const hasDepart = waypoints.some(w => w.type === 'depart');
      const hasArrivee = waypoints.some(w => w.type === 'arrivee');
      
      if (!hasDepart || !hasArrivee) {
        throw new Error('Les waypoints doivent contenir un départ et une arrivée');
      }
      
      // Valider chaque waypoint
      waypoints.forEach((wp, index) => {
        if (!wp.type || !['depart', 'checkpoint', 'arrivee'].includes(wp.type)) {
          throw new Error(`Waypoint ${index}: type invalide`);
        }
        if (!wp.address || typeof wp.address !== 'string') {
          throw new Error(`Waypoint ${index}: adresse requise`);
        }
        if (!wp.coordinates || !wp.coordinates.coordinates || !Array.isArray(wp.coordinates.coordinates)) {
          throw new Error(`Waypoint ${index}: coordonnées invalides`);
        }
        const [lng, lat] = wp.coordinates.coordinates;
        if (typeof lng !== 'number' || typeof lat !== 'number' ||
            lng < -180 || lng > 180 || lat < -90 || lat > 90) {
          throw new Error(`Waypoint ${index}: coordonnées hors limites`);
        }
      });
      
      return true;
    }),
  body('lieuDepart')
    .optional()
    .custom((value, { req }) => {
      // Si waypoints sont fournis, lieuDepart n'est pas requis
      if (req.body.waypoints && Array.isArray(req.body.waypoints) && req.body.waypoints.length >= 2) {
        return true;
      }
      // Sinon, lieuDepart est requis
      if (!value) {
        throw new Error('Le lieu de départ est requis si aucun waypoint n\'est fourni');
      }
      return true;
    }),
  body('lieuArrivee')
    .optional()
    .custom((value, { req }) => {
      // Si waypoints sont fournis, lieuArrivee n'est pas requis
      if (req.body.waypoints && Array.isArray(req.body.waypoints) && req.body.waypoints.length >= 2) {
        return true;
      }
      // Sinon, lieuArrivee est requis
      if (!value) {
        throw new Error('Le lieu d\'arrivée est requis si aucun waypoint n\'est fourni');
      }
      return true;
    }),
  handleValidationErrors
];

// Validation pour la mise à jour d'une balade
exports.validateUpdateRide = [
  param('id')
    .isMongoId()
    .withMessage('ID de balade invalide'),
  body('titre')
    .optional()
    .trim()
    .notEmpty()
    .withMessage('Le titre ne peut pas être vide')
    .isLength({ max: 200 })
    .withMessage('Le titre ne peut pas dépasser 200 caractères'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('La description ne peut pas dépasser 2000 caractères'),
  body('typeVehicule')
    .optional()
    .isIn(['moto', 'voiture'])
    .withMessage('Le type de véhicule doit être "moto" ou "voiture"'),
  body('date')
    .optional()
    .isISO8601()
    .withMessage('La date doit être au format ISO 8601')
    .custom((value) => {
      if (value) {
        const date = new Date(value);
        if (date < new Date()) {
          throw new Error('La date de la balade doit être dans le futur');
        }
      }
      return true;
    }),
  body('heure')
    .optional()
    .matches(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/)
    .withMessage('Format d\'heure invalide (HH:MM)'),
  body('rayon')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le rayon doit être un nombre positif'),
  body('visibilite')
    .optional()
    .isIn(['publique', 'privee'])
    .withMessage('La visibilité doit être "publique" ou "privee"'),
  handleValidationErrors
];

// Validation pour les paramètres de recherche
exports.validateGetRides = [
  query('typeVehicule')
    .optional()
    .isIn(['moto', 'voiture'])
    .withMessage('Le type de véhicule doit être "moto" ou "voiture"'),
  query('dateDebut')
    .optional()
    .isISO8601()
    .withMessage('La date de début doit être au format ISO 8601'),
  query('dateFin')
    .optional()
    .isISO8601()
    .withMessage('La date de fin doit être au format ISO 8601'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('La page doit être un entier positif')
    .toInt(),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('La limite doit être entre 1 et 100')
    .toInt(),
  query('sortBy')
    .optional()
    .isIn(['date', 'titre', 'createdAt'])
    .withMessage('Le tri doit être par date, titre ou createdAt'),
  query('sortOrder')
    .optional()
    .isIn(['asc', 'desc'])
    .withMessage('L\'ordre de tri doit être asc ou desc'),
  handleValidationErrors
];

// Validation pour les paramètres de recherche géospatiale
exports.validateGetRidesNearby = [
  query('latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('La latitude doit être entre -90 et 90')
    .toFloat(),
  query('longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('La longitude doit être entre -180 et 180')
    .toFloat(),
  query('rayon')
    .isFloat({ min: 0, max: 1000 })
    .withMessage('Le rayon doit être entre 0 et 1000 km')
    .toFloat(),
  query('typeVehicule')
    .optional()
    .isIn(['moto', 'voiture'])
    .withMessage('Le type de véhicule doit être "moto" ou "voiture"'),
  query('dateDebut')
    .optional()
    .isISO8601()
    .withMessage('La date de début doit être au format ISO 8601'),
  query('dateFin')
    .optional()
    .isISO8601()
    .withMessage('La date de fin doit être au format ISO 8601'),
  handleValidationErrors
];

// Validation pour les paramètres ID
exports.validateRideId = [
  param('id')
    .isMongoId()
    .withMessage('ID de balade invalide'),
  handleValidationErrors
];

