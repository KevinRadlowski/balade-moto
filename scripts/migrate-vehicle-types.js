/**
 * Script de migration pour normaliser les types de véhicules
 * 
 * Ce script met à jour tous les véhicules existants pour s'assurer que le champ "type"
 * est bien en minuscules et correspond aux valeurs attendues : "moto" ou "voiture"
 * 
 * Usage: node scripts/migrate-vehicle-types.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Vehicle = require('../src/models/Vehicle');

// Mapping des valeurs possibles vers les valeurs standardisées
const typeMapping = {
  'motorcycle': 'moto',
  'Moto': 'moto',
  'MOTO': 'moto',
  'moto': 'moto',
  'car': 'voiture',
  'Car': 'voiture',
  'CAR': 'voiture',
  'voiture': 'voiture',
  'Voiture': 'voiture',
  'VOITURE': 'voiture',
  'auto': 'voiture',
  'Auto': 'voiture',
  'AUTO': 'voiture',
  'automobile': 'voiture',
  'Automobile': 'voiture',
  'AUTOMOBILE': 'voiture'
};

async function migrateVehicleTypes() {
  try {
    // Connexion à MongoDB
    const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides';
    await mongoose.connect(mongoUri);
    console.log('✅ Connecté à MongoDB');

    // Récupérer tous les véhicules
    const vehicles = await Vehicle.find({});
    console.log(`📊 ${vehicles.length} véhicule(s) trouvé(s)`);

    let updated = 0;
    let skipped = 0;
    let errors = 0;

    for (const vehicle of vehicles) {
      try {
        const currentType = vehicle.type;
        
        // Si le type est déjà correct, ignorer
        if (currentType === 'moto' || currentType === 'voiture') {
          skipped++;
          continue;
        }

        // Normaliser le type
        const normalizedType = typeMapping[currentType] || currentType?.toLowerCase()?.trim();

        // Valider que le type normalisé est valide
        if (!normalizedType || !['moto', 'voiture'].includes(normalizedType)) {
          console.warn(`⚠️  Véhicule ${vehicle._id}: type invalide "${currentType}" - ignoré`);
          errors++;
          continue;
        }

        // Mettre à jour le type
        vehicle.type = normalizedType;
        await vehicle.save();
        updated++;
        console.log(`✅ Véhicule ${vehicle._id}: "${currentType}" → "${normalizedType}"`);
      } catch (error) {
        console.error(`❌ Erreur lors de la mise à jour du véhicule ${vehicle._id}:`, error.message);
        errors++;
      }
    }

    console.log('\n📈 Résumé de la migration:');
    console.log(`   - ${updated} véhicule(s) mis à jour`);
    console.log(`   - ${skipped} véhicule(s) déjà corrects`);
    console.log(`   - ${errors} erreur(s)`);

    await mongoose.connection.close();
    console.log('✅ Migration terminée');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur lors de la migration:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Exécuter la migration
migrateVehicleTypes();


