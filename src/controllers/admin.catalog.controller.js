const catalogAdminService = require('../services/catalogAdminService');
const { BadRequestError } = require('../utils/errors');

/**
 * @swagger
 * /api/admin/catalog/proposals:
 *   get:
 *     summary: Liste des propositions (admin)
 *     tags: [Admin Catalog]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [PENDING, APPROVED, REJECTED]
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
 *     responses:
 *       200:
 *         description: Liste des propositions
 */
exports.getProposals = async (req, res, next) => {
  try {
    const { status, page, limit } = req.query;
    
    const pageNum = parseInt(page, 10) || 1;
    const limitNum = parseInt(limit, 10) || 50;
    
    if (status && !['PENDING', 'APPROVED', 'REJECTED'].includes(status)) {
      throw new BadRequestError('status doit être PENDING, APPROVED ou REJECTED');
    }
    
    const result = await catalogAdminService.getProposals(status, pageNum, limitNum);
    
    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/admin/catalog/proposals/:id/approve:
 *   post:
 *     summary: Approuver une proposition (admin)
 *     tags: [Admin Catalog]
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
 *         description: Proposition approuvée
 */
exports.approveProposal = async (req, res, next) => {
  try {
    const { id } = req.params;
    
    const result = await catalogAdminService.approveProposal(id, req.user._id);
    
    res.json({
      success: true,
      message: result.alreadyExists 
        ? 'Proposition approuvée (entrée déjà existante)'
        : 'Proposition approuvée et entrée créée',
      data: result
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/admin/catalog/proposals/:id/reject:
 *   post:
 *     summary: Rejeter une proposition (admin)
 *     tags: [Admin Catalog]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               reason:
 *                 type: string
 *     responses:
 *       200:
 *         description: Proposition rejetée
 */
exports.rejectProposal = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    
    const proposal = await catalogAdminService.rejectProposal(id, req.user._id, reason);
    
    res.json({
      success: true,
      message: 'Proposition rejetée',
      data: { proposal }
    });
  } catch (error) {
    next(error);
  }
};

