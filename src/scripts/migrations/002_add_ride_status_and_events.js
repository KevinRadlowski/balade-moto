/**
 * Migration: Ajouter status et rideEvents aux balades existantes
 * 
 * Cette migration:
 * - Ajoute le champ status='scheduled' aux balades existantes
 * - Initialise rideEvents comme tableau vide
 * - Ajoute ridingStyle=null pour compatibilité
 */

const mongoose = require('mongoose');
require('dotenv').config();

const Ride = require('../../models/Ride');

async function migrate() {
  try {
    console.log('🔄 Début de la migration: Ajout status et rideEvents aux balades...');
    
    // Connecter à MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/balades-moto';
    await mongoose.connect(mongoUri);
    console.log('✅ Connecté à MongoDB');

    // Mettre à jour toutes les balades existantes
    const result = await Ride.updateMany(
      {
        $or: [
          { status: { $exists: false } },
          { rideEvents: { $exists: false } },
          { ridingStyle: { $exists: false } }
        ]
      },
      {
        $set: {
          status: 'scheduled',
          rideEvents: [],
          ridingStyle: null
        }
      }
    );

    console.log(`✅ Migration terminée: ${result.modifiedCount} balades mises à jour`);
    
    // Vérifier les balades complétées (date passée)
    const completedRides = await Ride.updateMany(
      {
        date: { $lt: new Date() },
        status: 'scheduled'
      },
      {
        $set: {
          status: 'completed'
        }
      }
    );

    if (completedRides.modifiedCount > 0) {
      console.log(`✅ ${completedRides.modifiedCount} balades passées marquées comme 'completed'`);
    }

    await mongoose.disconnect();
    console.log('✅ Déconnexion de MongoDB');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur lors de la migration:', error);
    await mongoose.disconnect();
    process.exit(1);
  }
}

// Exécuter la migration
if (require.main === module) {
  migrate();
}

module.exports = migrate;






