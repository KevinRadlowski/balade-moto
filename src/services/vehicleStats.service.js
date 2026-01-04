const VehicleStats = require('../models/VehicleStats');
const Vehicle = require('../models/Vehicle');
const Ride = require('../models/Ride');
const MaintenanceLog = require('../models/MaintenanceLog');

/**
 * Met à jour les statistiques d'un véhicule après une balade
 * @param {String} vehicleId - ID du véhicule
 * @param {Object} rideData - Données de la balade
 */
const updateStatsOnRideCompletion = async (vehicleId, rideData) => {
  try {
    const vehicle = await Vehicle.findById(vehicleId);
    if (!vehicle) {
      throw new Error('Véhicule non trouvé');
    }

    // Récupérer ou créer les stats
    let stats = await VehicleStats.findOne({ vehicleId });
    if (!stats) {
      stats = new VehicleStats({ vehicleId });
    }

    // Mettre à jour les compteurs
    stats.rideCount += 1;
    
    // Mettre à jour le kilométrage (si fourni dans rideData)
    if (rideData.distanceKm) {
      stats.totalKm += rideData.distanceKm;
    }

    // Mettre à jour le coût (si fourni)
    if (rideData.cost) {
      stats.totalCost += rideData.cost;
    }

    // Mettre à jour les stats mensuelles
    const now = new Date();
    const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    
    let monthlyStat = stats.monthlyStats.find(s => s.month === monthKey);
    if (!monthlyStat) {
      monthlyStat = {
        month: monthKey,
        km: 0,
        cost: 0,
        rides: 0
      };
      stats.monthlyStats.push(monthlyStat);
    }

    monthlyStat.rides += 1;
    if (rideData.distanceKm) {
      monthlyStat.km += rideData.distanceKm;
    }
    if (rideData.cost) {
      monthlyStat.cost += rideData.cost;
    }

    await stats.save();

    return stats;
  } catch (error) {
    console.error('Erreur lors de la mise à jour des stats:', error);
    throw error;
  }
};

/**
 * Récupère les statistiques d'un véhicule
 * @param {String} vehicleId - ID du véhicule
 * @returns {Promise<Object>} Statistiques du véhicule
 */
const getVehicleStats = async (vehicleId) => {
  try {
    let stats = await VehicleStats.findOne({ vehicleId });
    
    if (!stats) {
      // Créer des stats initiales
      const vehicle = await Vehicle.findById(vehicleId);
      if (!vehicle) {
        throw new Error('Véhicule non trouvé');
      }

      stats = new VehicleStats({
        vehicleId,
        totalKm: vehicle.odometerCurrentKm || 0,
        totalCost: 0,
        rideCount: 0,
        maintenanceCount: 0
      });

      await stats.save();
    }

    return stats;
  } catch (error) {
    console.error('Erreur lors de la récupération des stats:', error);
    throw error;
  }
};

/**
 * Prédit le prochain entretien basé sur l'usage
 * @param {String} vehicleId - ID du véhicule
 * @returns {Promise<Object>} Prédiction d'entretien
 */
const predictMaintenance = async (vehicleId) => {
  try {
    const vehicle = await Vehicle.findById(vehicleId);
    if (!vehicle) {
      throw new Error('Véhicule non trouvé');
    }

    const stats = await getVehicleStats(vehicleId);
    const maintenanceLogs = await MaintenanceLog.find({ vehicleId })
      .sort({ date: -1 })
      .limit(10);

    // Calculer la consommation moyenne (si disponible)
    let averageConsumption = null;
    if (stats.fuelConsumption && stats.fuelConsumption.averageLitersPer100km) {
      averageConsumption = stats.fuelConsumption.averageLitersPer100km;
    }

    // Prédire la prochaine vidange (tous les 5000-10000 km selon le type)
    const oilChangeInterval = vehicle.type === 'moto' ? 5000 : 10000;
    const lastOilChange = maintenanceLogs.find(log => 
      log.type === 'oil' || log.category === 'vidange'
    );
    
    const nextOilChangeKm = lastOilChange && lastOilChange.odometerKm
      ? lastOilChange.odometerKm + oilChangeInterval
      : (vehicle.odometerCurrentKm || 0) + oilChangeInterval;

    return {
      nextOilChangeKm,
      estimatedNextOilChangeDate: null, // TODO: Calculer basé sur l'usage moyen
      averageConsumption,
      recommendations: []
    };
  } catch (error) {
    console.error('Erreur lors de la prédiction d\'entretien:', error);
    throw error;
  }
};

module.exports = {
  updateStatsOnRideCompletion,
  getVehicleStats,
  predictMaintenance
};

