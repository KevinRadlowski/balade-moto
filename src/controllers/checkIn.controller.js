const checkInService = require('../services/checkIn.service');
const { BadRequestError } = require('../utils/errors');

/**
 * Envoyer un heartbeat (signal de vie)
 */
exports.sendHeartbeat = async (req, res, next) => {
  try {
    const { location } = req.body;
    const userId = req.user._id;

    const status = await checkInService.sendHeartbeat(userId, location);

    res.json({
      success: true,
      data: { status }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Récupérer le statut de check-in
 */
exports.getCheckInStatus = async (req, res, next) => {
  try {
    const userId = req.user._id;

    const status = await checkInService.getCheckInStatus(userId);

    res.json({
      success: true,
      data: { status }
    });
  } catch (error) {
    next(error);
  }
};







