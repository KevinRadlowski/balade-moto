/**
 * Migration: Backfill initial des statistiques véhicule pour les véhicules existants
 * 
 * Cette migration:
 * - Crée un document VehicleStats pour chaque véhicule existant
 * - Calcule les stats initiales basées sur les données existantes
 */

const mongoose = require('mongoose');
require('dotenv').config();

const Vehicle = require('../../models/Vehicle');
const VehicleStats = require('../../models/VehicleStats');
const Ride = require('../../models/Ride');
const MaintenanceLog = require('../../models/MaintenanceLog');

async function migrate() {
  try {
    console.log('🔄 Début du backfill: Création des statistiques véhicule...');
    
    // Connecter à MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/balades-moto';
    await mongoose.connect(mongoUri);
    console.log('✅ Connecté à MongoDB');

    // Récupérer tous les véhicules actifs
    const vehicles = await Vehicle.find({ active: true });
    console.log(`📊 ${vehicles.length} véhicules actifs trouvés`);

    let created = 0;
    let skipped = 0;

    for (const vehicle of vehicles) {
      // Vérifier si des stats existent déjà
      const existingStats = await VehicleStats.findOne({ vehicleId: vehicle._id });
      if (existingStats) {
        skipped++;
        continue;
      }

      // Compter les balades où ce véhicule a été utilisé
      // Note: On suppose que le véhicule est lié via ownerUserId
      const rides = await Ride.find({
        organisateur: vehicle.ownerUserId,
        date: { $lt: new Date() }
      });

      // Compter les entretiens
      const maintenanceLogs = await MaintenanceLog.find({
        vehicleId: vehicle._id
      });

      // Calculer le coût total des entretiens
      const totalCost = maintenanceLogs.reduce((sum, log) => {
        return sum + (log.cost || 0);
      }, 0);

      // Créer les stats
      const stats = new VehicleStats({
        vehicleId: vehicle._id,
        totalKm: vehicle.odometerCurrentKm || 0,
        totalCost: totalCost,
        rideCount: rides.length,
        maintenanceCount: maintenanceLogs.length,
        fuelConsumption: {
          averageLitersPer100km: null,
          lastUpdated: null
        },
        monthlyStats: []
      });

      await stats.save();
      created++;
    }

    console.log(`✅ Backfill terminé: ${created} statistiques créées, ${skipped} déjà existantes`);
    
    await mongoose.disconnect();
    console.log('✅ Déconnexion de MongoDB');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur lors du backfill:', error);
    await mongoose.disconnect();
    process.exit(1);
  }
}

// Exécuter la migration
if (require.main === module) {
  migrate();
}

module.exports = migrate;



