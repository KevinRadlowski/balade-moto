const mongoose = require('mongoose');
require('dotenv').config();

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI);

    console.log(`MongoDB connecté : ${conn.connection.host}`);

    // Corriger l'index pseudo s'il n'est pas sparse
    await fixPseudoIndex(conn.connection.db);
  } catch (error) {
    console.error(`Erreur de connexion MongoDB : ${error.message}`);
    process.exit(1);
  }
};

// Fonction pour corriger l'index pseudo
async function fixPseudoIndex(db) {
  try {
    const collection = db.collection('users');
    
    // Lister les index existants
    const indexes = await collection.indexes();
    
    // Trouver TOUS les index sur pseudo (y compris pseudo_1, pseudo_2, etc.)
    const pseudoIndexes = indexes.filter(idx => {
      return idx.key && idx.key.pseudo && idx.name !== '_id_';
    });
    
    // Si des index existent, vérifier s'ils sont corrects
    if (pseudoIndexes.length > 0) {
      const hasNonSparse = pseudoIndexes.some(idx => !idx.sparse);
      const hasMultiple = pseudoIndexes.length > 1;
      
      if (hasNonSparse || hasMultiple) {
        console.log(`🔧 Correction des index pseudo (${pseudoIndexes.length} index(s) trouvé(s))...`);
        
        // Supprimer TOUS les index sur pseudo
        for (const index of pseudoIndexes) {
          try {
            await collection.dropIndex(index.name);
            console.log(`  ✅ Index "${index.name}" supprimé`);
          } catch (error) {
            if (error.code !== 27 && error.codeName !== 'IndexNotFound') {
              console.warn(`  ⚠️  Erreur lors de la suppression de "${index.name}":`, error.message);
            }
          }
        }
        
        // Essayer aussi de supprimer par clé au cas où
        try {
          await collection.dropIndex({ pseudo: 1 });
        } catch (error) {
          // Ignorer si l'index n'existe pas
        }
        
        // Attendre que MongoDB finalise
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // Recréer UN SEUL index unique (plus besoin de sparse car le pseudo est obligatoire)
        try {
          await collection.createIndex(
            { pseudo: 1 },
            { unique: true, name: 'pseudo_1', background: false }
          );
          console.log('✅ Index pseudo recréé (unique, sans sparse car obligatoire)');
        } catch (error) {
          if (error.code === 85) {
            // Index existe déjà, vérifier
            const newIndexes = await collection.indexes();
            const newPseudoIndexes = newIndexes.filter(idx => idx.key && idx.key.pseudo && idx.name !== '_id_');
            if (newPseudoIndexes.length === 1) {
              console.log('✅ Index pseudo déjà correct');
            } else {
              console.warn('⚠️  Problème avec l\'index. Exécutez: npm run fix-all-pseudo');
            }
          } else {
            throw error;
          }
        }
      } else {
        // L'index existe et est unique
        console.log('✅ Index pseudo correct (unique)');
      }
    } else {
      // Si aucun index n'existe, le créer
      try {
        await collection.createIndex(
          { pseudo: 1 },
          { unique: true, name: 'pseudo_1', background: false }
        );
        console.log('✅ Index pseudo créé (unique)');
      } catch (error) {
        console.warn('⚠️  Erreur lors de la création de l\'index:', error.message);
      }
    }
  } catch (error) {
    console.error('❌ Erreur lors de la correction de l\'index pseudo:', error.message);
    console.error('   Exécutez manuellement: npm run fix-index');
    // Ne pas bloquer le démarrage si la correction échoue
  }
}

module.exports = connectDB;

