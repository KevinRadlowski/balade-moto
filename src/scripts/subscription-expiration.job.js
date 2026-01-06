/**
 * Script de nettoyage des abonnements premium expirés
 * 
 * Ce script trouve tous les utilisateurs avec subscription.isPremium=true
 * et premiumExpiresAt < now, puis les normalise.
 * 
 * Le middleware subscriptionMiddleware reste la première ligne de défense,
 * ce script est un nettoyage périodique pour maintenir la cohérence de la base de données.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const subscriptionService = require('../services/subscription.service');
const connectDB = require('../config/db');

async function cleanupExpiredSubscriptions() {
  try {
    console.log('🔄 Démarrage du nettoyage des abonnements premium expirés...');

    // Connexion à MongoDB
    await connectDB();

    const now = new Date();
    
    // Trouver tous les utilisateurs avec premium actif mais expiration passée
    const expiredPremiumUsers = await User.find({
      'subscription.isPremium': true,
      'subscription.premiumExpiresAt': { $lt: now }
    });

    console.log(`📊 ${expiredPremiumUsers.length} utilisateur(s) avec premium expiré trouvé(s)`);

    if (expiredPremiumUsers.length === 0) {
      console.log('✅ Aucun abonnement expiré à nettoyer');
      await mongoose.connection.close();
      return;
    }

    let normalizedCount = 0;
    let errorCount = 0;

    // Normaliser chaque utilisateur
    for (const user of expiredPremiumUsers) {
      try {
        // Utiliser le service de normalisation
        await subscriptionService.normalizeSubscription(user);
        
        normalizedCount++;
        console.log(`✅ Utilisateur ${user._id} (${user.pseudo || user.email}) normalisé`);
      } catch (error) {
        errorCount++;
        console.error(`❌ Erreur lors de la normalisation de l'utilisateur ${user._id}:`, error.message);
      }
    }

    console.log('\n📈 Résumé du nettoyage:');
    console.log(`   - Utilisateurs trouvés: ${expiredPremiumUsers.length}`);
    console.log(`   - Normalisés avec succès: ${normalizedCount}`);
    console.log(`   - Erreurs: ${errorCount}`);
    console.log('✅ Nettoyage terminé');

    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur fatale lors du nettoyage:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Exécuter le script
cleanupExpiredSubscriptions();
