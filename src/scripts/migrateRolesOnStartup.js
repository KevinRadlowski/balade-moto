/**
 * Script de migration automatique des rôles utilisateur au démarrage
 * 
 * Normalise les rôles legacy vers MEMBER/ADMIN:
 * - "user" / "USER" / null / undefined -> "MEMBER"
 * - "admin" / "ADMIN" / "ADMINISTRATOR" -> "ADMIN"
 * 
 * Exécuté une seule fois au démarrage du serveur.
 */

const User = require('../models/User');

let migrationExecuted = false;

async function migrateRolesOnStartup() {
  // Éviter d'exécuter plusieurs fois
  if (migrationExecuted) {
    return;
  }
  
  try {
    console.log('🔄 Migration automatique des rôles utilisateur...');
    
    // Migration: user/USER/null/undefined -> MEMBER
    const resultMember = await User.updateMany(
      {
        $or: [
          { role: { $exists: false } },
          { role: null },
          { role: '' },
          { role: 'user' },
          { role: 'USER' }
        ]
      },
      { $set: { role: 'MEMBER' } }
    );
    
    // Migration: admin/ADMIN/ADMINISTRATOR -> ADMIN
    const resultAdmin = await User.updateMany(
      {
        role: { $in: ['admin', 'ADMIN', 'ADMINISTRATOR'] }
      },
      { $set: { role: 'ADMIN' } }
    );
    
    const totalMigrated = resultMember.modifiedCount + resultAdmin.modifiedCount;
    
    if (totalMigrated > 0) {
      console.log(`✅ Migration des rôles terminée:`);
      console.log(`   - ${resultMember.modifiedCount} utilisateur(s) migré(s) vers MEMBER`);
      console.log(`   - ${resultAdmin.modifiedCount} utilisateur(s) migré(s) vers ADMIN`);
      console.log(`   - Total: ${totalMigrated} utilisateur(s)`);
    } else {
      console.log('✅ Aucune migration nécessaire. Tous les rôles sont déjà normalisés.');
    }
    
    migrationExecuted = true;
  } catch (error) {
    // Ne pas faire crasher le serveur si la migration échoue
    // (peut arriver si la collection n'existe pas encore, etc.)
    console.warn('⚠️  Erreur lors de la migration des rôles (non bloquant):', error.message);
    console.warn('   Les utilisateurs seront normalisés automatiquement lors de leur prochaine connexion.');
  }
}

module.exports = migrateRolesOnStartup;

