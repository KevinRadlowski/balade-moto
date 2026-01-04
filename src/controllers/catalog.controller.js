const catalogService = require('../services/catalogService');
const CatalogMeta = require('../models/CatalogMeta');
const { buildMakeBlocks } = require('../utils/catalog.utils');
const { BadRequestError } = require('../utils/errors');

/**
 * @swagger
 * /api/catalog/proposals:
 *   post:
 *     summary: Créer une proposition de catalogue
 *     tags: [Catalog]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - type
 *               - year
 *               - make
 *               - model
 *             properties:
 *               type:
 *                 type: string
 *                 enum: [voiture, moto]
 *               year:
 *                 type: integer
 *               make:
 *                 type: string
 *               model:
 *                 type: string
 *     responses:
 *       201:
 *         description: Proposition créée
 *       200:
 *         description: Proposition déjà existante
 */
exports.createProposal = async (req, res, next) => {
  try {
    const { type, year, make, model } = req.body;
    
    if (!type || !year || !make || !model) {
      throw new BadRequestError('type, year, make et model sont requis');
    }
    
    if (!['voiture', 'moto'].includes(type)) {
      throw new BadRequestError('type doit être "voiture" ou "moto"');
    }
    
    const result = await catalogService.createProposal(
      type,
      year,
      make,
      model,
      req.user._id
    );
    
    const statusCode = result.status === 'PENDING' ? 201 : 200;
    
    res.status(statusCode).json({
      success: true,
      data: result
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/catalog/approved:
 *   get:
 *     summary: Récupérer les entrées approuvées pour un type et une année
 *     tags: [Catalog]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: type
 *         required: true
 *         schema:
 *           type: string
 *           enum: [voiture, moto]
 *       - in: query
 *         name: year
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Liste des entrées approuvées
 */
exports.getApproved = async (req, res, next) => {
  try {
    const { type, year } = req.query;
    
    console.log('[Catalog] GET /api/catalog/approved - Query params:', { type, year });
    
    if (!type || !year) {
      throw new BadRequestError('type et year sont requis');
    }
    
    if (!['voiture', 'moto'].includes(type)) {
      throw new BadRequestError('type doit être "voiture" ou "moto"');
    }
    
    const yearNum = parseInt(year, 10);
    if (isNaN(yearNum)) {
      throw new BadRequestError('year doit être un nombre');
    }
    
    const entries = await catalogService.getApprovedEntries(type, yearNum);
    console.log('[Catalog] Found', entries.length, 'approved entries for', type, yearNum);
    
    const makeBlocks = buildMakeBlocks(entries);
    console.log('[Catalog] Built', makeBlocks.length, 'makeBlocks');
    if (makeBlocks.length > 0) {
      console.log('[Catalog] Sample makeBlock:', JSON.stringify(makeBlocks[0], null, 2));
    }
    
    res.json({
      success: true,
      data: {
        type,
        year: yearNum,
        makeBlocks
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/catalog/approved/makes:
 *   get:
 *     summary: Récupérer toutes les marques approuvées pour un type (toutes années)
 *     tags: [Catalog]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: type
 *         required: true
 *         schema:
 *           type: string
 *           enum: [voiture, moto]
 *     responses:
 *       200:
 *         description: Liste des marques approuvées
 */
exports.getApprovedMakes = async (req, res, next) => {
  try {
    const { type } = req.query;
    
    console.log('[Catalog] GET /api/catalog/approved/makes - Query params:', { type });
    
    if (!type) {
      throw new BadRequestError('type est requis');
    }
    
    if (!['voiture', 'moto'].includes(type)) {
      throw new BadRequestError('type doit être "voiture" ou "moto"');
    }
    
    const makes = await catalogService.getApprovedMakes(type);
    console.log('[Catalog] Found', makes.length, 'approved makes for', type);
    
    res.json({
      success: true,
      data: {
        type,
        makes: makes.sort()
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/catalog/version:
 *   get:
 *     summary: Récupérer la version du catalogue (pour invalidation de cache)
 *     tags: [Catalog]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Version du catalogue
 */
exports.getVersion = async (req, res, next) => {
  try {
    let meta = await CatalogMeta.findOne({ key: 'catalog_version' });
    
    // Si pas de meta, créer une entrée par défaut
    if (!meta) {
      meta = new CatalogMeta({
        key: 'catalog_version',
        version: new Date().toISOString()
      });
      await meta.save();
    }
    
    res.json({
      success: true,
      data: {
        version: meta.version
      }
    });
  } catch (error) {
    next(error);
  }
};
