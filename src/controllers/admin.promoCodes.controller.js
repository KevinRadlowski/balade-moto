const promoCodeService = require('../services/promoCode.service');
const PromoCode = require('../models/PromoCode');
const { BadRequestError, NotFoundError } = require('../utils/errors');

/**
 * @swagger
 * /api/admin/promo-codes/generate:
 *   post:
 *     summary: Générer des codes promotionnels (admin)
 *     tags: [Admin Promo Codes]
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
 *               - count
 *             properties:
 *               type:
 *                 type: string
 *                 enum: [DISCOUNT_PERCENT, GRANT_PREMIUM_MONTHS, GRANT_PREMIUM_PERMANENT]
 *               count:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 100
 *               discountPercent:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 100
 *                 description: Requis si type=DISCOUNT_PERCENT
 *               premiumMonths:
 *                 type: integer
 *                 minimum: 1
 *                 description: Requis si type=GRANT_PREMIUM_MONTHS
 *               usageLimit:
 *                 type: integer
 *                 minimum: 1
 *                 default: 1
 *               validFrom:
 *                 type: string
 *                 format: date-time
 *               validUntil:
 *                 type: string
 *                 format: date-time
 *               metadata:
 *                 type: object
 *     responses:
 *       201:
 *         description: Codes générés avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 data:
 *                   type: object
 *                   properties:
 *                     codes:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           code:
 *                             type: string
 *                             description: Code en clair (uniquement à la création)
 *                           prefix:
 *                             type: string
 *                           id:
 *                             type: string
 */
exports.generatePromoCodes = async (req, res, next) => {
  try {
    const {
      type,
      count,
      discountPercent,
      premiumMonths,
      usageLimit,
      validFrom,
      validUntil,
      metadata
    } = req.body;

    const createdBy = req.user._id;

    const codes = await promoCodeService.generatePromoCodes({
      type,
      count,
      discountPercent,
      premiumMonths,
      usageLimit,
      validFrom,
      validUntil,
      createdBy,
      metadata
    });

    // Retourner les codes en clair UNIQUEMENT à la création
    // IMPORTANT: Ne jamais logger les codes en clair (déjà géré dans le service)
    res.status(201).json({
      success: true,
      message: `${codes.length} code(s) promotionnel(s) généré(s)`,
      data: {
        codes: codes.map(c => ({
          id: c.id,
          code: c.codePlain, // Code en clair uniquement à la création - NE JAMAIS LOGGER
          prefix: c.codePrefix
        }))
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/admin/promo-codes:
 *   get:
 *     summary: Liste des codes promotionnels (admin)
 *     tags: [Admin Promo Codes]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *       - in: query
 *         name: active
 *         schema:
 *           type: boolean
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *           enum: [DISCOUNT_PERCENT, GRANT_PREMIUM_MONTHS, GRANT_PREMIUM_PERMANENT]
 *       - in: query
 *         name: prefix
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Liste des codes promotionnels
 */
exports.listPromoCodes = async (req, res, next) => {
  try {
    // Support de `skip` et `limit` (ou `page` en fallback)
    let skip = 0;
    let limit = 50;
    
    if (req.query.skip !== undefined) {
      skip = parseInt(req.query.skip, 10) || 0;
    } else if (req.query.page !== undefined) {
      const page = parseInt(req.query.page, 10) || 1;
      limit = parseInt(req.query.limit, 10) || 50;
      skip = (page - 1) * limit;
    } else {
      limit = parseInt(req.query.limit, 10) || 50;
    }

    // Validation des paramètres
    if (skip < 0) skip = 0;
    if (limit < 1) limit = 1;
    if (limit > 100) limit = 100; // Limite max pour éviter les surcharges

    // Filtres
    const filter = {};
    
    if (req.query.active !== undefined) {
      filter.isActive = req.query.active === 'true' || req.query.active === true;
    }
    
    if (req.query.type) {
      const validTypes = ['DISCOUNT_PERCENT', 'GRANT_PREMIUM_MONTHS', 'GRANT_PREMIUM_PERMANENT'];
      if (validTypes.includes(req.query.type)) {
        filter.type = req.query.type;
      }
    }

    // Compter le total
    const total = await PromoCode.countDocuments(filter);

    // Récupérer les codes
    // IMPORTANT: Ne jamais exposer codeHash ou code en clair
    const items = await PromoCode.find(filter)
      .select('-codeHash') // Ne jamais exposer le hash complet
      .populate('createdBy', 'pseudo email')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean()
      .then(codes => codes.map(code => ({
        _id: code._id,
        codePrefix: code.codePrefix,
        type: code.type,
        discountPercent: code.discountPercent || null,
        premiumMonths: code.premiumMonths || null,
        usageLimit: code.usageLimit,
        usedCount: code.usedCount,
        isActive: code.isActive,
        validFrom: code.validFrom || null,
        validUntil: code.validUntil || null,
        createdAt: code.createdAt,
        updatedAt: code.updatedAt,
        createdBy: code.createdBy,
        metadata: code.metadata || {}
      })));

    res.status(200).json({
      success: true,
      data: {
        items,
        total
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/admin/promo-codes/{id}/deactivate:
 *   patch:
 *     summary: Désactiver un code promotionnel (admin)
 *     tags: [Admin Promo Codes]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Code désactivé avec succès
 *       404:
 *         description: Code non trouvé
 */
exports.deactivatePromoCode = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!id) {
      throw new BadRequestError('ID du code promotionnel requis');
    }

    await promoCodeService.deactivatePromoCode(id);

    res.status(200).json({
      success: true
    });
  } catch (error) {
    if (error.message === 'Code promotionnel non trouvé') {
      return next(new NotFoundError('Code promotionnel non trouvé'));
    }
    next(error);
  }
};

