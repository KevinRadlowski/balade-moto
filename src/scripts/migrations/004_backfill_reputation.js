/**
 * Migration: Backfill initial des scores de réputation pour les utilisateurs existants
 * 
 * Cette migration:
 * - Crée un document Reputation pour chaque utilisateur existant
 * - Calcule un score initial basé sur les balades passées
 * - Initialise les compteurs (rideCount, feedbackCount, etc.)
 */

const mongoose = require('mongoose');
require('dotenv').config();

const User = require('../../models/User');
const Ride = require('../../models/Ride');
const Reputation = require('../../models/Reputation');
const Rating = require('../../models/Rating');

async function migrate() {
  try {
    console.log('🔄 Début du backfill: Création des réputations initiales...');
    
    // Connecter à MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/balades-moto';
    await mongoose.connect(mongoUri);
    console.log('✅ Connecté à MongoDB');

    // Récupérer tous les utilisateurs
    const users = await User.find({});
    console.log(`📊 ${users.length} utilisateurs trouvés`);

    let created = 0;
    let skipped = 0;

    for (const user of users) {
      // Vérifier si une réputation existe déjà
      const existingReputation = await Reputation.findOne({ userId: user._id });
      if (existingReputation) {
        skipped++;
        continue;
      }

      // Compter les balades passées
      const ridesAsOrganizer = await Ride.countDocuments({
        organisateur: user._id,
        date: { $lt: new Date() }
      });
      
      const ridesAsParticipant = await Ride.countDocuments({
        'participants.userId': user._id,
        date: { $lt: new Date() }
      });
      
      const pastRides = ridesAsOrganizer + ridesAsParticipant;

      // Compter les notes reçues
      const ratings = await Rating.find({ utilisateur: user._id });
      const avgRating = ratings.length > 0
        ? ratings.reduce((sum, r) => sum + r.note, 0) / ratings.length
        : 0;

      // Calculer un score initial basé sur les données existantes
      let score = 50; // Score de base
      
      // Bonus pour nombre de balades
      if (pastRides > 0) {
        score += Math.min(pastRides * 2, 30); // Max +30 points
      }
      
      // Bonus pour notes moyennes
      if (avgRating >= 4.5) {
        score += 15;
      } else if (avgRating >= 4.0) {
        score += 10;
      } else if (avgRating >= 3.5) {
        score += 5;
      }

      // Créer la réputation
      const reputation = new Reputation({
        userId: user._id,
        score: Math.min(Math.max(score, 0), 100), // Clamp entre 0 et 100
        rideCount: pastRides,
        punctualityScore: 50, // Valeur par défaut
        cancellationRate: 0, // Valeur par défaut
        feedbackCount: ratings.length,
        level: 'bronze' // Sera mis à jour par le pre-save hook
      });

      await reputation.save();
      created++;
    }

    console.log(`✅ Backfill terminé: ${created} réputations créées, ${skipped} déjà existantes`);
    
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



