/**
 * Migration 005: Migrer la structure des participants
 * 
 * Migre les participants de [ObjectId] vers [{ userId: ObjectId, ... }]
 * 
 * Usage: node src/scripts/migrations/005_migrate_participants_structure.js
 */

const mongoose = require('mongoose');
require('dotenv').config();

const Ride = require('../../models/Ride');

async function migrate() {
  try {
    console.log('🔄 Début de la migration: Structure des participants...');
    
    // Connecter à MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/balades-moto';
    await mongoose.connect(mongoUri);
    console.log('✅ Connecté à MongoDB');

    // Récupérer toutes les balades
    const rides = await Ride.find({});
    console.log(`📊 ${rides.length} balades trouvées`);

    let migrated = 0;
    let skipped = 0;

    for (const ride of rides) {
      // Vérifier si la migration est nécessaire
      // Si le premier participant est déjà un objet avec userId, la migration a déjà été faite
      if (ride.participants.length > 0 && typeof ride.participants[0] === 'object' && ride.participants[0].userId) {
        skipped++;
        continue;
      }

      // Migrer les participants
      const oldParticipants = ride.participants;
      const newParticipants = oldParticipants.map(participantId => {
        // Si c'est déjà un ObjectId, le convertir en objet
        if (participantId && participantId.toString) {
          return {
            userId: participantId
          };
        }
        // Si c'est déjà un objet mais sans userId, essayer de récupérer l'ID
        if (participantId && participantId._id) {
          return {
            userId: participantId._id
          };
        }
        return participantId;
      }).filter(p => p && p.userId); // Filtrer les valeurs null/undefined

      ride.participants = newParticipants;
      await ride.save();
      migrated++;
    }

    console.log(`✅ Migration terminée: ${migrated} balades migrées, ${skipped} déjà à jour`);
    
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

module.exports = { migrate };
