/**
 * Migration: Normaliser les rôles utilisateur
 * 
 * Convertit les anciens rôles en minuscules vers les nouveaux rôles en majuscules:
 * - "user" -> "MEMBER"
 * - "admin" -> "ADMIN"
 * - null/undefined/"" -> "MEMBER"
 * 
 * Usage: npm run migrate:roles
 */

const mongoose = require('mongoose');
require('dotenv').config();

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI;

if (!MONGODB_URI) {
  console.error('❌ Erreur: MONGODB_URI ou MONGO_URI doit être défini dans .env');
  process.exit(1);
}

async function normalizeUserRoles() {
  let connection = null;
  
  try {
    console.log('🔌 Connexion à MongoDB...');
    connection = await mongoose.connect(MONGODB_URI);
    console.log(`✅ Connecté à: ${connection.connection.host}`);
    
    const User = mongoose.model('User', new mongoose.Schema({}, { strict: false }), 'users');
    
    // Compter les utilisateurs à migrer
    const countUser = await User.countDocuments({ role: 'user' });
    const countAdmin = await User.countDocuments({ role: 'admin' });
    const countMissing = await User.countDocuments({
      $or: [
        { role: { $exists: false } },
        { role: null },
        { role: '' }
      ]
    });
    
    console.log(`\n📊 Statistiques avant migration:`);
    console.log(`   - role="user": ${countUser}`);
    console.log(`   - role="admin": ${countAdmin}`);
    console.log(`   - role manquant/null/vide: ${countMissing}`);
    
    if (countUser === 0 && countAdmin === 0 && countMissing === 0) {
      console.log('\n✅ Aucune migration nécessaire. Tous les rôles sont déjà normalisés.');
      await mongoose.connection.close();
      process.exit(0);
    }
    
    // Migration: user -> MEMBER
    let resultUser = { modifiedCount: 0 };
    if (countUser > 0) {
      resultUser = await User.updateMany(
        { role: 'user' },
        { $set: { role: 'MEMBER' } }
      );
      console.log(`\n✅ Migration "user" -> "MEMBER": ${resultUser.modifiedCount} utilisateur(s) mis à jour`);
    }
    
    // Migration: admin -> ADMIN
    let resultAdmin = { modifiedCount: 0 };
    if (countAdmin > 0) {
      resultAdmin = await User.updateMany(
        { role: 'admin' },
        { $set: { role: 'ADMIN' } }
      );
      console.log(`✅ Migration "admin" -> "ADMIN": ${resultAdmin.modifiedCount} utilisateur(s) mis à jour`);
    }
    
    // Migration: null/undefined/"" -> MEMBER
    let resultMissing = { modifiedCount: 0 };
    if (countMissing > 0) {
      resultMissing = await User.updateMany(
        {
          $or: [
            { role: { $exists: false } },
            { role: null },
            { role: '' }
          ]
        },
        { $set: { role: 'MEMBER' } }
      );
      console.log(`✅ Migration manquant -> "MEMBER": ${resultMissing.modifiedCount} utilisateur(s) mis à jour`);
    }
    
    // Vérification finale
    const finalCountUser = await User.countDocuments({ role: 'user' });
    const finalCountAdmin = await User.countDocuments({ role: 'admin' });
    const finalCountMissing = await User.countDocuments({
      $or: [
        { role: { $exists: false } },
        { role: null },
        { role: '' }
      ]
    });
    
    console.log(`\n📊 Statistiques après migration:`);
    console.log(`   - role="user": ${finalCountUser} (devrait être 0)`);
    console.log(`   - role="admin": ${finalCountAdmin} (devrait être 0)`);
    console.log(`   - role manquant/null/vide: ${finalCountMissing} (devrait être 0)`);
    
    const totalMigrated = resultUser.modifiedCount + resultAdmin.modifiedCount + resultMissing.modifiedCount;
    
    console.log(`\n✅ Migration terminée avec succès!`);
    console.log(`   Résumé: ${resultUser.modifiedCount} user->MEMBER, ${resultAdmin.modifiedCount} admin->ADMIN, ${resultMissing.modifiedCount} missing->MEMBER`);
    console.log(`   Total: ${totalMigrated} utilisateur(s) migré(s)`);
    
    if (finalCountUser > 0 || finalCountAdmin > 0 || finalCountMissing > 0) {
      console.warn(`\n⚠️  Attention: Il reste des rôles non normalisés. Vérifiez manuellement.`);
    }
    
    await mongoose.connection.close();
    process.exit(0);
    
  } catch (error) {
    console.error('\n❌ Erreur lors de la migration:', error);
    if (connection) {
      await mongoose.connection.close().catch(() => {});
    }
    process.exit(1);
  }
}

// Exécuter la migration
normalizeUserRoles();

