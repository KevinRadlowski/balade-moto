const Ride = require('../models/Ride');
const { BadRequestError, NotFoundError } = require('../utils/errors');

/**
 * @swagger
 * /api/admin/rides:
 *   get:
 *     summary: Liste des balades (admin)
 *     tags: [Admin Rides]
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
 *         name: query
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Liste des balades
 */
exports.getRides = async (req, res, next) => {
  try {
    // Standardiser la pagination avec limites strictes
    const pagination = require('../utils/pagination');
    const maxLimit = parseInt(process.env.PAGINATION_MAX_LIMIT) || 50;
    const defaultLimit = parseInt(process.env.PAGINATION_DEFAULT_LIMIT) || 20;
    
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(maxLimit, Math.max(1, parseInt(req.query.limit, 10) || defaultLimit));
    const skip = (page - 1) * limit;
    const { query } = req.query;

    const filter = {};
    if (query && query.trim().length > 0) {
      // Recherche par titre (regex safe)
      filter.titre = { $regex: query.trim(), $options: 'i' };
    }

    const rides = await Ride.find(filter)
      .populate('organisateur', 'email pseudo')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await Ride.countDocuments(filter);

    // Ajouter headers de pagination
    const paginationHeaders = pagination.buildPaginationHeaders({
      nextCursor: null,
      hasNextPage: page * limit < total
    });
    Object.keys(paginationHeaders).forEach(key => {
      res.setHeader(key, paginationHeaders[key]);
    });

    res.json({
      success: true,
      data: {
        rides,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit),
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/admin/rides/:id:
 *   delete:
 *     summary: Supprimer une balade (admin)
 *     tags: [Admin Rides]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Balade supprimée
 */
exports.deleteRide = async (req, res, next) => {
  try {
    const { id } = req.params;

    const ride = await Ride.findById(id);
    if (!ride) {
      throw new NotFoundError('Balade');
    }

    await Ride.findByIdAndDelete(id);

    res.json({
      success: true,
      message: 'Balade supprimée',
    });
  } catch (error) {
    next(error);
  }
};

