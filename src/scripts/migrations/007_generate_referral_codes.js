/**
 * Migration: Génération des codes de parrainage pour les utilisateurs existants
 * 
 * Cette migration:
 * - Génère un code de parrainage unique pour chaque utilisateur qui n'en a pas
 * - Utilise le même algorithme que le hook pre-save du modèle User
 */

const mongoose = require('mongoose');
require('dotenv').config();
const crypto = require('crypto');

const User = require('../../models/User');

async function generateReferralCode(userId) {
  let code;
  let isUnique = false;
  let attempts = 0;
  
  while (!isUnique && attempts < 10) {
    // Générer un code de 8 caractères (lettres majuscules et chiffres)
    code = crypto.randomBytes(4).toString('hex').toUpperCase();
    const existing = await User.findOne({ referralCode: code });
    if (!existing) {
      isUnique = true;
    }
    attempts++;
  }
  
  if (isUnique) {
    return code;
  } else {
    // Fallback : utiliser l'ID avec un préfixe
    return `REF${userId.toString().slice(-8).toUpperCase()}`;
  }
}

async function migrate() {
  try {
    console.log('🔄 Début de la migration: Génération des codes de parrainage...');
    
    // Connecter à MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/balades-moto';
    await mongoose.connect(mongoUri);
    console.log('✅ Connecté à MongoDB');

    // Récupérer tous les utilisateurs sans code de parrainage
    const usersWithoutCode = await User.find({
      $or: [
        { referralCode: { $exists: false } },
        { referralCode: null },
        { referralCode: '' }
      ]
    });

    console.log(`📊 ${usersWithoutCode.length} utilisateur(s) sans code de parrainage trouvé(s)`);

    let updated = 0;
    let errors = 0;

    for (const user of usersWithoutCode) {
      try {
        const code = await generateReferralCode(user._id);
        user.referralCode = code;
        await user.save();
        updated++;
        console.log(`  ✅ ${user.pseudo} (${user.email}): ${code}`);
      } catch (error) {
        errors++;
        console.error(`  ❌ Erreur pour ${user.pseudo} (${user.email}):`, error.message);
      }
    }

    console.log(`\n✅ Migration terminée:`);
    console.log(`   - ${updated} utilisateur(s) mis à jour`);
    if (errors > 0) {
      console.log(`   - ${errors} erreur(s)`);
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

module.exports = { migrate };
