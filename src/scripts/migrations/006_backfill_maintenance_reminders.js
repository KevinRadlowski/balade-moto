/**
 * Migration: Backfill initial des rappels d'entretien basés sur MaintenanceItem existants
 * 
 * Cette migration:
 * - Crée des MaintenanceReminder basés sur les MaintenanceItem existants
 * - Calcule les dates d'échéance basées sur les intervalles
 */

const mongoose = require('mongoose');
require('dotenv').config();

const MaintenanceItem = require('../../models/MaintenanceItem');
const MaintenanceReminder = require('../../models/MaintenanceReminder');
const Vehicle = require('../../models/Vehicle');

async function migrate() {
  try {
    console.log('🔄 Début du backfill: Création des rappels d\'entretien...');
    
    // Connecter à MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/balades-moto';
    await mongoose.connect(mongoUri);
    console.log('✅ Connecté à MongoDB');

    // Récupérer tous les MaintenanceItem actifs
    const maintenanceItems = await MaintenanceItem.find({});
    console.log(`📊 ${maintenanceItems.length} items d'entretien trouvés`);

    let created = 0;
    let skipped = 0;

    for (const item of maintenanceItems) {
      // Vérifier si un rappel existe déjà pour cet item
      const existingReminder = await MaintenanceReminder.findOne({
        userId: item.ownerUserId,
        vehicleId: item.vehicleId,
        type: item.type || 'other'
      });

      if (existingReminder) {
        skipped++;
        continue;
      }

      // Récupérer le véhicule pour obtenir le kilométrage actuel
      const vehicle = await Vehicle.findById(item.vehicleId);
      if (!vehicle) {
        console.log(`⚠️  Véhicule ${item.vehicleId} non trouvé, skip`);
        skipped++;
        continue;
      }

      // Calculer la prochaine échéance
      let nextDueKm = null;
      let nextDueDate = null;

      if (item.intervalKm && vehicle.odometerCurrentKm) {
        nextDueKm = (item.lastDoneKm || vehicle.odometerCurrentKm) + item.intervalKm;
      }

      if (item.intervalMonths && item.lastDoneDate) {
        const nextDate = new Date(item.lastDoneDate);
        nextDate.setMonth(nextDate.getMonth() + item.intervalMonths);
        nextDueDate = nextDate;
      } else if (item.intervalMonths) {
        // Si pas de lastDoneDate, utiliser la date d'aujourd'hui + interval
        const nextDate = new Date();
        nextDate.setMonth(nextDate.getMonth() + item.intervalMonths);
        nextDueDate = nextDate;
      }

      // Créer le rappel
      const reminder = new MaintenanceReminder({
        userId: item.ownerUserId,
        vehicleId: item.vehicleId,
        type: item.type || 'other',
        description: item.description || `Entretien ${item.type || 'général'}`,
        intervalKm: item.intervalKm || null,
        intervalMonths: item.intervalMonths || null,
        lastDoneKm: item.lastDoneKm || null,
        lastDoneDate: item.lastDoneDate || null,
        nextDueKm: nextDueKm,
        nextDueDate: nextDueDate,
        status: 'active'
      });

      await reminder.save();
      created++;
    }

    console.log(`✅ Backfill terminé: ${created} rappels créés, ${skipped} déjà existants ou ignorés`);
    
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

