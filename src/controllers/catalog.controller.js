const carapiService = require('../services/carapi.service');
const CatalogCache = require('../models/CatalogCache');
const { BadRequestError } = require('../utils/errors');

/**
 * @swagger
 * tags:
 *   name: Catalog
 *   description: API de catalogue de véhicules via CarAPI.app
 */

/**
 * @swagger
 * /api/catalog/voiture/makes:
 *   get:
 *     summary: Liste les marques de voitures disponibles pour une année
 *     tags: [Catalog]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: year
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1900
 *         description: Année du véhicule
 *     responses:
 *       200:
 *         description: Liste des marques
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       name:
 *                         type: string
 *                 source:
 *                   type: string
 *                   example: carapi
 *                 cached:
 *                   type: boolean
 */
exports.getCarMakes = async (req, res, next) => {
  try {
    const { year } = req.query;

    if (!year) {
      throw new BadRequestError('Le paramètre year est requis');
    }

    const yearInt = parseInt(year);
    if (isNaN(yearInt) || yearInt < 1900 || yearInt > new Date().getFullYear() + 1) {
      throw new BadRequestError(`L'année doit être entre 1900 et ${new Date().getFullYear() + 1}`);
    }

    const cacheKey = CatalogCache.generateKey('carapi', 'voiture', 'makes', yearInt.toString());
    const cached = await CatalogCache.findOne({ key: cacheKey });
    const isCached = cached && cached.expiresAt > new Date();

    if (isCached && cached.data) {
      return res.json({
        items: cached.data,
        source: 'carapi',
        cached: true
      });
    }

    const makes = await carapiService.fetchCarMakes(yearInt);

    res.json({
      items: makes,
      source: 'carapi',
      cached: false
    });
  } catch (error) {
    console.error('[Catalog] Erreur getCarMakes:', {
      year: req.query.year,
      userId: req.user?._id,
      error: error.message
    });
    next(error);
  }
};

/**
 * @swagger
 * /api/catalog/voiture/models:
 *   get:
 *     summary: Liste les modèles de voitures disponibles pour une marque et une année
 *     tags: [Catalog]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: year
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1900
 *         description: Année du véhicule
 *       - in: query
 *         name: make
 *         required: true
 *         schema:
 *           type: string
 *         description: Nom ou ID de la marque
 *     responses:
 *       200:
 *         description: Liste des modèles
 */
exports.getCarModels = async (req, res, next) => {
  try {
    const { year, make } = req.query;

    if (!year) {
      throw new BadRequestError('Le paramètre year est requis');
    }

    if (!make || make.trim().length === 0) {
      throw new BadRequestError('Le paramètre make est requis');
    }

    const yearInt = parseInt(year);
    if (isNaN(yearInt) || yearInt < 1900 || yearInt > new Date().getFullYear() + 1) {
      throw new BadRequestError(`L'année doit être entre 1900 et ${new Date().getFullYear() + 1}`);
    }

    const sanitizedMake = encodeURIComponent(make.trim());
    
    // Essayer d'utiliser make comme makeId, sinon comme makeName
    const models = await carapiService.fetchCarModels(yearInt, sanitizedMake, sanitizedMake);

    res.json({
      items: models,
      source: 'carapi',
      cached: false
    });
  } catch (error) {
    console.error('[Catalog] Erreur getCarModels:', {
      year: req.query.year,
      make: req.query.make ? req.query.make.substring(0, 20) : undefined,
      userId: req.user?._id,
      error: error.message
    });
    next(error);
  }
};

/**
 * @swagger
 * /api/catalog/moto/makes:
 *   get:
 *     summary: Liste les marques de motos disponibles pour une année
 *     tags: [Catalog]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: year
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1900
 *         description: Année du véhicule
 *     responses:
 *       200:
 *         description: Liste des marques
 */
exports.getMotoMakes = async (req, res, next) => {
  try {
    const { year } = req.query;

    if (!year) {
      throw new BadRequestError('Le paramètre year est requis');
    }

    const yearInt = parseInt(year);
    if (isNaN(yearInt) || yearInt < 1900 || yearInt > new Date().getFullYear() + 1) {
      throw new BadRequestError(`L'année doit être entre 1900 et ${new Date().getFullYear() + 1}`);
    }

    const cacheKey = CatalogCache.generateKey('carapi', 'moto', 'makes', yearInt.toString());
    const cached = await CatalogCache.findOne({ key: cacheKey });
    const isCached = cached && cached.expiresAt > new Date();

    if (isCached && cached.data) {
      return res.json({
        items: cached.data,
        source: 'carapi',
        cached: true
      });
    }

    const makes = await carapiService.fetchMotoMakes(yearInt);

    res.json({
      items: makes,
      source: 'carapi',
      cached: false
    });
  } catch (error) {
    // Mapper les erreurs CarAPI en erreurs HTTP appropriées
    if (error.isCarApiError) {
      if (error.status === 502) {
        return res.status(502).json({
          success: false,
          message: error.message || 'Erreur lors de la communication avec CarAPI (Power Sports)'
        });
      }
      if (error.status === 401) {
        return res.status(401).json({
          success: false,
          message: 'Erreur d\'authentification CarAPI'
        });
      }
      if (error.status === 429) {
        return res.status(429).json({
          success: false,
          message: 'Trop de requêtes vers CarAPI, veuillez réessayer plus tard'
        });
      }
    }
    
    console.error('[Catalog] Erreur getMotoMakes:', {
      year: req.query.year,
      userId: req.user?._id,
      error: error.message,
      status: error.status,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
    next(error);
  }
};

/**
 * @swagger
 * /api/catalog/moto/models:
 *   get:
 *     summary: Liste les modèles de motos disponibles pour une marque et une année
 *     tags: [Catalog]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: year
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1900
 *         description: Année du véhicule
 *       - in: query
 *         name: make
 *         required: true
 *         schema:
 *           type: string
 *         description: Nom ou ID de la marque
 *     responses:
 *       200:
 *         description: Liste des modèles
 */
exports.getMotoModels = async (req, res, next) => {
  try {
    const { year, make, makeId } = req.query;

    if (!year) {
      throw new BadRequestError('Le paramètre year est requis');
    }

    // makeId est prioritaire, sinon utiliser make
    let makeIdValue = makeId || make;
    if (!makeIdValue || String(makeIdValue).trim().length === 0) {
      throw new BadRequestError('Le paramètre make ou makeId est requis');
    }

    const yearInt = parseInt(year);
    if (isNaN(yearInt) || yearInt < 1900 || yearInt > new Date().getFullYear() + 1) {
      throw new BadRequestError(`L'année doit être entre 1900 et ${new Date().getFullYear() + 1}`);
    }

    // Parser makeId comme entier positif
    const makeIdInt = parseInt(String(makeIdValue).trim(), 10);
    if (isNaN(makeIdInt) || makeIdInt <= 0) {
      throw new BadRequestError('makeId doit être un entier positif');
    }

    // Récupérer le nom de la marque si make est fourni (pour enrichir les modèles)
    const makeName = make && make !== makeId ? make.trim() : '';

    const cacheKey = CatalogCache.generateKey('carapi', 'moto', 'models', yearInt.toString(), makeIdInt.toString());
    const cached = await CatalogCache.findOne({ key: cacheKey });
    const isCached = cached && cached.expiresAt > new Date();

    if (isCached && cached.data) {
      return res.json({
        items: cached.data,
        source: 'carapi',
        cached: true
      });
    }

    const models = await carapiService.fetchMotoModels(yearInt, makeIdInt, makeName);

    res.json({
      items: models,
      source: 'carapi',
      cached: false
    });
  } catch (error) {
    // Mapper les erreurs CarAPI en erreurs HTTP appropriées
    if (error.isCarApiError) {
      if (error.status === 502) {
        return res.status(502).json({
          success: false,
          message: error.message || 'Erreur lors de la communication avec CarAPI (Power Sports)'
        });
      }
      if (error.status === 401) {
        return res.status(401).json({
          success: false,
          message: 'Erreur d\'authentification CarAPI'
        });
      }
      if (error.status === 429) {
        return res.status(429).json({
          success: false,
          message: 'Trop de requêtes vers CarAPI, veuillez réessayer plus tard'
        });
      }
    }
    
    console.error('[Catalog] Erreur getMotoModels:', {
      year: req.query.year,
      make: req.query.make ? req.query.make.substring(0, 20) : undefined,
      makeId: req.query.makeId,
      userId: req.user?._id,
      error: error.message,
      status: error.status
    });
    next(error);
  }
};

// Méthodes de compatibilité pour les anciennes routes CarQuery (dépréciées)
exports.getMakes = async (req, res, next) => {
  try {
    const { type } = req.query;
    
    if (!type || !['moto', 'voiture'].includes(type)) {
      throw new BadRequestError('Le paramètre type est requis et doit être "moto" ou "voiture"');
    }

    // Rediriger vers les nouveaux endpoints avec l'année actuelle par défaut
    const year = new Date().getFullYear();
    req.query.year = year;
    
    if (type === 'voiture') {
      return exports.getCarMakes(req, res, next);
    } else {
      return exports.getMotoMakes(req, res, next);
    }
  } catch (error) {
    next(error);
  }
};

exports.getModels = async (req, res, next) => {
  try {
    const { type } = req.query;
    
    if (!type || !['moto', 'voiture'].includes(type)) {
      throw new BadRequestError('Le paramètre type est requis et doit être "moto" ou "voiture"');
    }

    // Rediriger vers les nouveaux endpoints
    if (type === 'voiture') {
      return exports.getCarModels(req, res, next);
    } else {
      return exports.getMotoModels(req, res, next);
    }
  } catch (error) {
    next(error);
  }
};
