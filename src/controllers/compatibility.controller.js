const compatibilityService = require('../services/compatibility.service');
const { BadRequestError } = require('../utils/errors');

/**
 * Vérifier la compatibilité entre deux utilisateurs
 */
exports.checkCompatibility = async (req, res, next) => {
  try {
    const { userId1, userId2, rideId } = req.query;

    if (!userId1 || !userId2) {
      throw new BadRequestError('userId1 et userId2 sont requis');
    }

    const compatibility = await compatibilityService.checkCompatibility(
      userId1,
      userId2,
      rideId || null
    );

    res.json({
      success: true,
      data: { compatibility }
    });
  } catch (error) {
    next(error);
  }
};






