const liveRideService = require('../services/liveRide.service');
const { NotFoundError, ForbiddenError, BadRequestError } = require('../utils/errors');

/**
 * Démarrer une balade en mode live
 */
exports.startLiveRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const ride = await liveRideService.startLiveRide(id, userId);

    res.json({
      success: true,
      message: 'Balade démarrée avec succès',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Mettre en pause une balade live
 */
exports.pauseLiveRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const ride = await liveRideService.pauseLiveRide(id, userId);

    res.json({
      success: true,
      message: 'Balade mise en pause',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Reprendre une balade en pause
 */
exports.resumeLiveRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const ride = await liveRideService.resumeLiveRide(id, userId);

    res.json({
      success: true,
      message: 'Balade reprise',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Terminer une balade live
 */
exports.endLiveRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const ride = await liveRideService.endLiveRide(id, userId);

    res.json({
      success: true,
      message: 'Balade terminée',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Signaler un incident
 */
exports.reportIncident = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { description, location } = req.body;
    const userId = req.user._id;

    if (!description) {
      throw new BadRequestError('La description de l\'incident est requise');
    }

    const ride = await liveRideService.reportIncident(id, userId, {
      description,
      location
    });

    res.json({
      success: true,
      message: 'Incident signalé',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Récupérer le statut d'une balade live
 */
exports.getLiveRideStatus = async (req, res, next) => {
  try {
    const { id } = req.params;

    const status = await liveRideService.getLiveRideStatus(id);

    res.json({
      success: true,
      data: { status }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Envoyer un heartbeat
 */
exports.sendHeartbeat = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { location } = req.body;
    const userId = req.user._id;

    const status = await liveRideService.sendHeartbeat(id, userId, location);

    res.json({
      success: true,
      data: { status }
    });
  } catch (error) {
    next(error);
  }
};



