const vehicleStatsService = require('../services/vehicleStats.service');
const { NotFoundError, ForbiddenError } = require('../utils/errors');
const Vehicle = require('../models/Vehicle');

/**
 * Récupérer les statistiques d'un véhicule
 */
exports.getVehicleStats = async (req, res, next) => {
  try {
    const { vehicleId } = req.params;
    const userId = req.user._id;

    // Vérifier que le véhicule appartient à l'utilisateur
    const vehicle = await Vehicle.findById(vehicleId);
    if (!vehicle) {
      throw new NotFoundError('Véhicule non trouvé');
    }

    if (vehicle.ownerUserId.toString() !== userId.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas autorisé à voir ces statistiques');
    }

    const stats = await vehicleStatsService.getVehicleStats(vehicleId);

    res.json({
      success: true,
      data: { stats }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Mettre à jour les statistiques d'un véhicule
 */
exports.updateVehicleStats = async (req, res, next) => {
  try {
    const { vehicleId } = req.params;
    const rideData = req.body;
    const userId = req.user._id;

    // Vérifier que le véhicule appartient à l'utilisateur
    const vehicle = await Vehicle.findById(vehicleId);
    if (!vehicle) {
      throw new NotFoundError('Véhicule non trouvé');
    }

    if (vehicle.ownerUserId.toString() !== userId.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas autorisé à modifier ces statistiques');
    }

    const stats = await vehicleStatsService.updateStatsOnRideCompletion(vehicleId, rideData);

    res.json({
      success: true,
      message: 'Statistiques mises à jour avec succès',
      data: { stats }
    });
  } catch (error) {
    next(error);
  }
};






