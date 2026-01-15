const Group = require('../models/Group');
const { BadRequestError, NotFoundError } = require('../utils/errors');

/**
 * @swagger
 * /api/admin/groups:
 *   get:
 *     summary: Liste des groupes (admin)
 *     tags: [Admin Groups]
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
 *         description: Liste des groupes
 */
exports.getGroups = async (req, res, next) => {
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
      // Recherche par nom (regex safe)
      filter.nom = { $regex: query.trim(), $options: 'i' };
    }

    const groups = await Group.find(filter)
      .populate('createur', 'email pseudo')
      .populate('membres.userId', 'email pseudo')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await Group.countDocuments(filter);

    // Ajouter le nombre de membres
    // Ajouter le nombre de membres et mapper les champs
    const groupsWithCount = groups.map((group) => {
      const groupObj = group.toObject();
      groupObj.membersCount = group.membres?.length || 0;
      // Mapper createur vers createdBy pour compatibilité
      if (groupObj.createur) {
        groupObj.createdBy = groupObj.createur;
      }
      return groupObj;
    });

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
        groups: groupsWithCount,
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
 * /api/admin/groups/:id:
 *   delete:
 *     summary: Supprimer un groupe (admin)
 *     tags: [Admin Groups]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Groupe supprimé
 */
exports.deleteGroup = async (req, res, next) => {
  try {
    const { id } = req.params;

    const group = await Group.findById(id);
    if (!group) {
      throw new NotFoundError('Groupe');
    }

    await Group.findByIdAndDelete(id);

    res.json({
      success: true,
      message: 'Groupe supprimé',
    });
  } catch (error) {
    next(error);
  }
};

