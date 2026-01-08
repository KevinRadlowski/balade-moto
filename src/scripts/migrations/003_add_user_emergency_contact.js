/**
 * Migration: Ajouter emergencyContact et checkInStatus aux utilisateurs existants
 * 
 * Cette migration:
 * - Initialise emergencyContact comme objet vide/null
 * - Initialise checkInStatus avec isActive=false
 */

const mongoose = require('mongoose');
require('dotenv').config();

const User = require('../../models/User');

async function migrate() {
  try {
    console.log('🔄 Début de la migration: Ajout emergencyContact et checkInStatus aux utilisateurs...');
    
    // Connecter à MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/balades-moto';
    await mongoose.connect(mongoUri);
    console.log('✅ Connecté à MongoDB');

    // Mettre à jour tous les utilisateurs existants
    const result = await User.updateMany(
      {
        $or: [
          { emergencyContact: { $exists: false } },
          { checkInStatus: { $exists: false } }
        ]
      },
      {
        $set: {
          'checkInStatus.isActive': false,
          'checkInStatus.lastHeartbeat': null,
          'checkInStatus.lastLocation': null
        }
      }
    );

    console.log(`✅ Migration terminée: ${result.modifiedCount} utilisateurs mis à jour`);
    
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







