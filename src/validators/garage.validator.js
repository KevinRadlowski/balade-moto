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

// Validation pour la création d'un véhicule
exports.validateCreateVehicle = [
  // Champs de base
  body('type')
    .notEmpty()
    .withMessage('Le type est requis')
    .isIn(['moto', 'voiture'])
    .withMessage('Le type doit être "moto" ou "voiture"'),
  
  // Compatibilité avec anciens champs
  body('name')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Le nom ne peut pas dépasser 100 caractères'),
  body('nickname')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Le surnom ne peut pas dépasser 100 caractères'),
  
  // Marque et modèle - obligatoires si selectionSource='CATALOG', 'CATALOG_LOCAL' ou 'SUGGESTION'
  body('make')
    .optional()
    .trim()
    .isLength({ max: 50 })
    .withMessage('La marque ne peut pas dépasser 50 caractères')
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if ((selectionSource === 'CATALOG' || selectionSource === 'CATALOG_LOCAL' || selectionSource === 'SUGGESTION') && (!value || value.trim().length === 0)) {
        throw new Error(`La marque est requise lorsque selectionSource="${selectionSource}"`);
      }
      return true;
    }),
  body('brand')
    .optional()
    .trim()
    .isLength({ max: 50 })
    .withMessage('La marque ne peut pas dépasser 50 caractères'),
  body('model')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Le modèle ne peut pas dépasser 100 caractères')
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if ((selectionSource === 'CATALOG' || selectionSource === 'CATALOG_LOCAL' || selectionSource === 'SUGGESTION') && (!value || value.trim().length === 0)) {
        throw new Error(`Le modèle est requis lorsque selectionSource="${selectionSource}"`);
      }
      return true;
    }),
  body('year')
    .optional()
    .isInt({ min: 1900, max: new Date().getFullYear() + 1 })
    .withMessage(`L'année doit être entre 1900 et ${new Date().getFullYear() + 1}`)
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if ((selectionSource === 'CATALOG' || selectionSource === 'CATALOG_LOCAL' || selectionSource === 'SUGGESTION') && !value) {
        throw new Error(`L'année est requise lorsque selectionSource="${selectionSource}"`);
      }
      return true;
    }),
  
  // Moteur (optionnel)
  body('engine.fuel')
    .optional()
    .isIn(['essence', 'diesel', 'electrique', 'hybride', 'autre'])
    .withMessage('Le carburant doit être: essence, diesel, electrique, hybride ou autre'),
  body('engine.displacementCc')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('La cylindrée ne peut pas être négative'),
  body('engine.powerHp')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('La puissance (ch) ne peut pas être négative'),
  body('engine.powerKw')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('La puissance (kW) ne peut pas être négative'),
  body('engine.transmission')
    .optional()
    .isIn(['manuelle', 'automatique', 'cvt', 'autre'])
    .withMessage('La transmission doit être: manuelle, automatique, cvt ou autre'),
  
  // Autres champs optionnels
  body('trim')
    .optional()
    .trim()
    .isLength({ max: 50 })
    .withMessage('La finition ne peut pas dépasser 50 caractères'),
  body('odometerCurrentKm')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le kilométrage ne peut pas être négatif'),
  body('purchaseDate')
    .optional()
    .isISO8601()
    .withMessage('La date doit être au format ISO 8601'),
  body('purchase.date')
    .optional()
    .isISO8601()
    .withMessage('La date d\'achat doit être au format ISO 8601'),
  body('purchase.price')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le prix ne peut pas être négatif'),
  body('purchase.sellerType')
    .optional()
    .isIn(['particulier', 'professionnel', 'concessionnaire', 'autre'])
    .withMessage('Le type de vendeur doit être: particulier, professionnel, concessionnaire ou autre'),
  body('insurance.company')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Le nom de la compagnie ne peut pas dépasser 100 caractères'),
  body('insurance.policyNumber')
    .optional()
    .trim()
    .isLength({ max: 50 })
    .withMessage('Le numéro de police ne peut pas dépasser 50 caractères'),
  body('insurance.renewalDate')
    .optional()
    .isISO8601()
    .withMessage('La date de renouvellement doit être au format ISO 8601'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('La description ne peut pas dépasser 1000 caractères'),
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Les notes ne peuvent pas dépasser 2000 caractères'),
  body('enableRecommendedMaintenancePack')
    .optional()
    .isBoolean()
    .withMessage('enableRecommendedMaintenancePack doit être un booléen'),
  
  // Champs pour le catalogue externe (nouveau format unifié)
  body('selectionSource')
    .optional()
    .isIn(['MANUAL', 'CATALOG', 'CATALOG_LOCAL', 'SUGGESTION'])
    .withMessage('selectionSource doit être "MANUAL", "CATALOG", "CATALOG_LOCAL" ou "SUGGESTION"'),
  
  // Nouveau format catalog (recommandé)
  body('catalog.provider')
    .optional()
    .isIn(['VPIC', 'CARQUERY'])
    .withMessage('catalog.provider doit être "VPIC" ou "CARQUERY"'),
  body('catalog.makeId')
    .optional()
    .isString()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('catalog.makeId doit être une chaîne de caractères (ex: "554e4b55")')
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if (value && selectionSource !== 'VPIC' && selectionSource !== 'CATALOG') {
        throw new Error('catalog.makeId ne peut être fourni que si selectionSource="CATALOG" ou "VPIC"');
      }
      return true;
    }),
  body('catalog.modelId')
    .optional()
    .isString()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('catalog.modelId doit être une chaîne de caractères (ex: "a0ed90ee")')
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if (value && selectionSource !== 'VPIC' && selectionSource !== 'CATALOG') {
        throw new Error('catalog.modelId ne peut être fourni que si selectionSource="CATALOG" ou "VPIC"');
      }
      return true;
    }),
  body('catalog.raw')
    .optional()
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if (value && selectionSource !== 'VPIC' && selectionSource !== 'CATALOG') {
        throw new Error('catalog.raw ne peut être fourni que si selectionSource="CATALOG" ou "VPIC"');
      }
      return true;
    }),
  
  // Ancien format vpic (déprécié, conservé pour compatibilité)
  body('vpic.makeId')
    .optional()
    .custom((value, { req }) => {
      if (value === undefined || value === null) return true;
      // Accepter Number (ancien format) ou String (nouveau format)
      if (typeof value !== 'number' && typeof value !== 'string') {
        throw new Error('vpic.makeId doit être un nombre (déprécié) ou une chaîne de caractères');
      }
      if (typeof value === 'number' && value < 1) {
        throw new Error('vpic.makeId (number) doit être un entier positif');
      }
      if (typeof value === 'string' && value.trim().length === 0) {
        throw new Error('vpic.makeId (string) ne peut pas être vide');
      }
      const selectionSource = req.body.selectionSource;
      if (value && selectionSource !== 'VPIC' && selectionSource !== 'CATALOG') {
        throw new Error('vpic.makeId ne peut être fourni que si selectionSource="CATALOG" ou "VPIC"');
      }
      return true;
    }),
  body('vpic.modelId')
    .optional()
    .custom((value, { req }) => {
      if (value === undefined || value === null) return true;
      // Accepter Number (ancien format) ou String (nouveau format)
      if (typeof value !== 'number' && typeof value !== 'string') {
        throw new Error('vpic.modelId doit être un nombre (déprécié) ou une chaîne de caractères');
      }
      if (typeof value === 'number' && value < 1) {
        throw new Error('vpic.modelId (number) doit être un entier positif');
      }
      if (typeof value === 'string' && value.trim().length === 0) {
        throw new Error('vpic.modelId (string) ne peut pas être vide');
      }
      const selectionSource = req.body.selectionSource;
      if (value && selectionSource !== 'VPIC' && selectionSource !== 'CATALOG') {
        throw new Error('vpic.modelId ne peut être fourni que si selectionSource="CATALOG" ou "VPIC"');
      }
      return true;
    }),
  
  // Format externalCatalog (nouveau format unifié)
  body('externalCatalog.provider')
    .optional()
    .isIn(['CARAPI', 'LOCAL_FR', 'SUGGESTION'])
    .withMessage('externalCatalog.provider doit être "CARAPI", "LOCAL_FR" ou "SUGGESTION"')
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if (value && !['CATALOG', 'CATALOG_LOCAL', 'SUGGESTION'].includes(selectionSource)) {
        throw new Error('externalCatalog.provider ne peut être fourni que si selectionSource="CATALOG", "CATALOG_LOCAL" ou "SUGGESTION"');
      }
      // Validation de cohérence
      if (value === 'SUGGESTION' && selectionSource !== 'SUGGESTION') {
        throw new Error('externalCatalog.provider="SUGGESTION" ne peut être utilisé que si selectionSource="SUGGESTION"');
      }
      if ((value === 'CARAPI' || value === 'LOCAL_FR') && selectionSource === 'SUGGESTION') {
        throw new Error('externalCatalog.provider ne peut pas être "CARAPI" ou "LOCAL_FR" lorsque selectionSource="SUGGESTION"');
      }
      return true;
    }),
  body('externalCatalog.makeId')
    .optional()
    .isString()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('externalCatalog.makeId doit être une chaîne de caractères')
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if (value && !['CATALOG', 'CATALOG_LOCAL'].includes(selectionSource)) {
        throw new Error('externalCatalog.makeId ne peut être fourni que si selectionSource="CATALOG" ou "CATALOG_LOCAL"');
      }
      return true;
    }),
  body('externalCatalog.modelId')
    .optional()
    .isString()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('externalCatalog.modelId doit être une chaîne de caractères')
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if (value && !['CATALOG', 'CATALOG_LOCAL'].includes(selectionSource)) {
        throw new Error('externalCatalog.modelId ne peut être fourni que si selectionSource="CATALOG" ou "CATALOG_LOCAL"');
      }
      return true;
    }),
  body('externalCatalog.make')
    .optional()
    .isString()
    .trim()
    .isLength({ min: 1, max: 50 })
    .withMessage('externalCatalog.make doit être une chaîne de caractères')
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if (value && selectionSource !== 'SUGGESTION') {
        throw new Error('externalCatalog.make ne peut être fourni que si selectionSource="SUGGESTION"');
      }
      return true;
    }),
  body('externalCatalog.model')
    .optional()
    .isString()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('externalCatalog.model doit être une chaîne de caractères')
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if (value && selectionSource !== 'SUGGESTION') {
        throw new Error('externalCatalog.model ne peut être fourni que si selectionSource="SUGGESTION"');
      }
      return true;
    }),
  body('externalCatalog.raw')
    .optional()
    .custom((value, { req }) => {
      const selectionSource = req.body.selectionSource;
      if (value && !['CATALOG', 'CATALOG_LOCAL', 'SUGGESTION'].includes(selectionSource)) {
        throw new Error('externalCatalog.raw ne peut être fourni que si selectionSource="CATALOG", "CATALOG_LOCAL" ou "SUGGESTION"');
      }
      return true;
    }),
  
  handleValidationErrors
];

// Validation pour la mise à jour d'un véhicule
exports.validateUpdateVehicle = [
  body('name')
    .optional()
    .trim()
    .notEmpty()
    .withMessage('Le nom ne peut pas être vide')
    .isLength({ max: 100 })
    .withMessage('Le nom ne peut pas dépasser 100 caractères'),
  body('brand')
    .optional()
    .trim()
    .isLength({ max: 50 })
    .withMessage('La marque ne peut pas dépasser 50 caractères'),
  body('model')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Le modèle ne peut pas dépasser 100 caractères'),
  body('year')
    .optional()
    .isInt({ min: 1900, max: new Date().getFullYear() + 1 })
    .withMessage(`L'année doit être entre 1900 et ${new Date().getFullYear() + 1}`),
  body('type')
    .optional()
    .isIn(['moto', 'voiture'])
    .withMessage('Le type doit être "moto" ou "voiture"'),
  body('color')
    .optional()
    .trim()
    .isLength({ max: 30 })
    .withMessage('La couleur ne peut pas dépasser 30 caractères'),
  body('odometerCurrentKm')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le kilométrage ne peut pas être négatif'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('La description ne peut pas dépasser 1000 caractères'),
  handleValidationErrors
];

// Validation pour la liste des véhicules
exports.validateGetVehicles = [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Le numéro de page doit être un entier positif'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('La limite doit être entre 1 et 100'),
  query('type')
    .optional()
    .isIn(['moto', 'voiture'])
    .withMessage('Le type doit être "moto" ou "voiture"'),
  handleValidationErrors
];

// Validation pour l'ID de véhicule
exports.validateVehicleId = [
  param('id')
    .isMongoId()
    .withMessage('ID de véhicule invalide'),
  handleValidationErrors
];

// Validation pour la création d'une entrée odomètre
exports.validateCreateOdometer = [
  body('km')
    .isFloat({ min: 0 })
    .withMessage('Le kilométrage est requis et ne peut pas être négatif'),
  body('date')
    .optional()
    .isISO8601()
    .withMessage('La date doit être au format ISO 8601'),
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Les notes ne peuvent pas dépasser 500 caractères'),
  handleValidationErrors
];

// Validation pour la liste des entrées odomètre
exports.validateGetOdometers = [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Le numéro de page doit être un entier positif'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('La limite doit être entre 1 et 100'),
  handleValidationErrors
];

// Validation pour la création d'un élément de maintenance
exports.validateCreateMaintenanceItem = [
  body('type')
    .isIn([
      'vidange',
      'filtre_huile',
      'filtre_air',
      'filtre_essence',
      'bougies',
      'freins',
      'pneus',
      'batterie',
      'chaines',
      'liquide_refroidissement',
      'liquide_freins',
      'revision',
      'autre'
    ])
    .withMessage('Type de maintenance invalide'),
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Le nom de la maintenance est requis')
    .isLength({ max: 100 })
    .withMessage('Le nom ne peut pas dépasser 100 caractères'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('La description ne peut pas dépasser 1000 caractères'),
  body('intervalKm')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('L\'intervalle kilométrique ne peut pas être négatif'),
  body('intervalDays')
    .optional()
    .isInt({ min: 0 })
    .withMessage('L\'intervalle en jours ne peut pas être négatif'),
  body('lastDoneAtKm')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le kilométrage ne peut pas être négatif'),
  body('lastDoneAtDate')
    .optional()
    .isISO8601()
    .withMessage('La date doit être au format ISO 8601'),
  body('cost')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le coût ne peut pas être négatif'),
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Les notes ne peuvent pas dépasser 500 caractères'),
  handleValidationErrors
];

// Validation pour la mise à jour d'un élément de maintenance
exports.validateUpdateMaintenanceItem = [
  body('type')
    .optional()
    .isIn([
      'vidange',
      'filtre_huile',
      'filtre_air',
      'filtre_essence',
      'bougies',
      'freins',
      'pneus',
      'batterie',
      'chaines',
      'liquide_refroidissement',
      'liquide_freins',
      'revision',
      'autre'
    ])
    .withMessage('Type de maintenance invalide'),
  body('name')
    .optional()
    .trim()
    .notEmpty()
    .withMessage('Le nom ne peut pas être vide')
    .isLength({ max: 100 })
    .withMessage('Le nom ne peut pas dépasser 100 caractères'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('La description ne peut pas dépasser 1000 caractères'),
  body('intervalKm')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('L\'intervalle kilométrique ne peut pas être négatif'),
  body('intervalDays')
    .optional()
    .isInt({ min: 0 })
    .withMessage('L\'intervalle en jours ne peut pas être négatif'),
  body('cost')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le coût ne peut pas être négatif'),
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Les notes ne peuvent pas dépasser 500 caractères'),
  handleValidationErrors
];

// Validation pour la création d'un log de maintenance
exports.validateCreateMaintenanceLog = [
  body('maintenanceItem')
    .optional()
    .isMongoId()
    .withMessage('ID d\'élément de maintenance invalide'),
  
  // Nouveau format: category (prioritaire)
  body('category')
    .optional()
    .isIn([
      'vidange',
      'filtre_huile',
      'filtre_air',
      'filtre_essence',
      'bougies',
      'freins',
      'pneus',
      'batterie',
      'chaines',
      'liquide_refroidissement',
      'liquide_freins',
      'revision',
      'autre'
    ])
    .withMessage('Catégorie de maintenance invalide'),
  
  // Ancien format: type (compatibilité)
  body('type')
    .optional()
    .isIn([
      'vidange',
      'filtre_huile',
      'filtre_air',
      'filtre_essence',
      'bougies',
      'freins',
      'pneus',
      'batterie',
      'chaines',
      'liquide_refroidissement',
      'liquide_freins',
      'revision',
      'autre'
    ])
    .withMessage('Type de maintenance invalide')
    .custom((value, { req }) => {
      // Si type est fourni mais pas category, c'est OK (compatibilité)
      // Si les deux sont fournis, category a la priorité
      return true;
    }),
  
  // Validation: category OU type doit être présent
  body('category')
    .custom((value, { req }) => {
      if (!value && !req.body.type) {
        throw new Error('La catégorie (category) ou le type (type) est requis');
      }
      return true;
    }),
  
  // Nouveau format: label (prioritaire)
  body('label')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Le libellé ne peut pas dépasser 200 caractères'),
  
  // Ancien format: description (compatibilité)
  body('description')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('La description ne peut pas dépasser 1000 caractères'),
  
  // Validation: label OU description doit être présent
  body('label')
    .custom((value, { req }) => {
      if (!value && (!req.body.description || req.body.description.trim().length === 0)) {
        throw new Error('Le libellé (label) ou la description (description) est requis');
      }
      return true;
    }),
  
  // Nouveau format: kmAtService (prioritaire)
  body('kmAtService')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le kilométrage (kmAtService) doit être un nombre positif'),
  
  // Ancien format: km (compatibilité)
  body('km')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le kilométrage (km) doit être un nombre positif'),
  
  // Validation: kmAtService OU km doit être présent
  body('kmAtService')
    .custom((value, { req }) => {
      const hasKmAtService = value !== undefined && value !== null;
      const hasKm = req.body.km !== undefined && req.body.km !== null;
      if (!hasKmAtService && !hasKm) {
        throw new Error('Le kilométrage (kmAtService) ou (km) est requis');
      }
      return true;
    }),
  
  body('date')
    .optional()
    .isISO8601()
    .withMessage('La date doit être au format ISO 8601'),
  body('cost')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le coût ne peut pas être négatif'),
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Les notes ne peuvent pas dépasser 500 caractères'),
  
  // invoiceFileUrl est optionnel si un fichier est uploadé (req.file)
  body('invoiceFileUrl')
    .optional({ checkFalsy: true })
    .custom((value, { req }) => {
      // Si un fichier est uploadé, invoiceFileUrl n'est pas requis
      if (req.file) {
        return true;
      }
      // Si pas de fichier uploadé, invoiceFileUrl est optionnel (pas de validation URL)
      return true;
    })
    .isLength({ max: 500 })
    .withMessage('L\'URL ne peut pas dépasser 500 caractères'),
  
  handleValidationErrors
];

// Validation pour la liste des logs de maintenance
exports.validateGetMaintenanceLogs = [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Le numéro de page doit être un entier positif'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('La limite doit être entre 1 et 100'),
  handleValidationErrors
];

// Validation pour l'ID d'un log de maintenance
exports.validateMaintenanceLogId = [
  param('logId')
    .isMongoId()
    .withMessage('ID de log de maintenance invalide'),
  handleValidationErrors
];

// Validation pour la mise à jour d'un log de maintenance
exports.validateUpdateMaintenanceLog = [
  body('label')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Le libellé ne peut pas dépasser 200 caractères'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('La description ne peut pas dépasser 1000 caractères'),
  body('category')
    .optional()
    .isIn([
      'vidange',
      'filtre_huile',
      'filtre_air',
      'filtre_essence',
      'bougies',
      'freins',
      'pneus',
      'batterie',
      'chaines',
      'liquide_refroidissement',
      'liquide_freins',
      'revision',
      'autre'
    ])
    .withMessage('Catégorie de maintenance invalide'),
  body('type')
    .optional()
    .isIn([
      'vidange',
      'filtre_huile',
      'filtre_air',
      'filtre_essence',
      'bougies',
      'freins',
      'pneus',
      'batterie',
      'chaines',
      'liquide_refroidissement',
      'liquide_freins',
      'revision',
      'autre'
    ])
    .withMessage('Type de maintenance invalide'),
  body('kmAtService')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le kilométrage (kmAtService) doit être un nombre positif'),
  body('km')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le kilométrage (km) doit être un nombre positif'),
  body('date')
    .optional()
    .isISO8601()
    .withMessage('La date doit être au format ISO 8601'),
  body('cost')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Le coût ne peut pas être négatif'),
  body('garageName')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Le nom du garage ne peut pas dépasser 100 caractères'),
  body('invoiceFileUrl')
    .optional({ checkFalsy: true })
    .custom((value, { req }) => {
      // Si un fichier est uploadé, invoiceFileUrl n'est pas requis
      if (req.file) {
        return true;
      }
      return true;
    })
    .isLength({ max: 500 })
    .withMessage('L\'URL ne peut pas dépasser 500 caractères'),
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Les notes ne peuvent pas dépasser 500 caractères'),
  handleValidationErrors
];

// Validation pour l'ID d'élément de maintenance
exports.validateMaintenanceItemId = [
  param('itemId')
    .isMongoId()
    .withMessage('ID d\'élément de maintenance invalide'),
  handleValidationErrors
];

// Validation pour la création d'un document
exports.validateCreateDocument = [
  body('type')
    .isIn(['ASSURANCE', 'CT', 'FACTURE', 'AUTRE'])
    .withMessage('Le type doit être ASSURANCE, CT, FACTURE ou AUTRE'),
  body('label')
    .trim()
    .notEmpty()
    .withMessage('Le libellé est requis')
    .isLength({ max: 200 })
    .withMessage('Le libellé ne peut pas dépasser 200 caractères'),
  // fileUrl est optionnel si un fichier est uploadé (req.file)
  body('fileUrl')
    .optional({ checkFalsy: true })
    .custom((value, { req }) => {
      // Si un fichier est uploadé, fileUrl n'est pas requis
      if (req.file) {
        return true;
      }
      // Si pas de fichier uploadé, fileUrl est requis
      if (!value || (typeof value === 'string' && value.trim().length === 0)) {
        throw new Error('L\'URL du fichier est requise ou un fichier doit être uploadé');
      }
      return true;
    })
    .custom((value, { req }) => {
      // Si un fichier est uploadé, on ignore la validation URL
      if (req.file) {
        return true;
      }
      // Si fileUrl est fourni, il doit être une URL valide
      if (value && typeof value === 'string' && value.trim().length > 0) {
        try {
          const url = new URL(value.trim());
          if (!['http:', 'https:'].includes(url.protocol)) {
            throw new Error('L\'URL doit commencer par http:// ou https://');
          }
        } catch (e) {
          if (e.message.includes('commencer par')) {
            throw e;
          }
          throw new Error('L\'URL doit être valide');
        }
      }
      return true;
    })
    .custom((value, { req }) => {
      // Validation de longueur uniquement si fileUrl est fourni
      if (value && typeof value === 'string' && value.length > 500) {
        throw new Error('L\'URL ne peut pas dépasser 500 caractères');
      }
      return true;
    }),
  body('date')
    .optional()
    .isISO8601()
    .withMessage('La date doit être au format ISO 8601'),
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Les notes ne peuvent pas dépasser 500 caractères'),
  handleValidationErrors
];

// Validation pour la mise à jour d'un document
exports.validateUpdateDocument = [
  body('type')
    .optional()
    .isIn(['ASSURANCE', 'CT', 'FACTURE', 'AUTRE'])
    .withMessage('Le type doit être ASSURANCE, CT, FACTURE ou AUTRE'),
  body('label')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Le libellé ne peut pas dépasser 200 caractères'),
  body('fileUrl')
    .optional()
    .trim()
    .isURL()
    .withMessage('L\'URL doit être valide')
    .isLength({ max: 500 })
    .withMessage('L\'URL ne peut pas dépasser 500 caractères'),
  body('date')
    .optional()
    .isISO8601()
    .withMessage('La date doit être au format ISO 8601'),
  body('notes')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Les notes ne peuvent pas dépasser 500 caractères'),
  handleValidationErrors
];

// Validation pour la récupération des documents
exports.validateGetDocuments = [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('La page doit être un entier positif'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('La limite doit être entre 1 et 100'),
  query('type')
    .optional()
    .isIn(['ASSURANCE', 'CT', 'FACTURE', 'AUTRE'])
    .withMessage('Le type doit être ASSURANCE, CT, FACTURE ou AUTRE'),
  handleValidationErrors
];

// Validation pour l'ID d'un document
exports.validateDocumentId = [
  param('documentId').isMongoId().withMessage('ID de document invalide'),
  handleValidationErrors
];

