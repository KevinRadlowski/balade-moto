const mongoose = require('mongoose');
require('dotenv').config();

async function fixAllPseudoIndexes() {
  try {
    console.log('🔌 Connexion à MongoDB...');
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides');
    console.log('✅ Connecté à MongoDB\n');

    const db = mongoose.connection.db;
    const collection = db.collection('users');

    // Lister TOUS les index
    console.log('📋 Index existants:');
    const indexes = await collection.indexes();
    indexes.forEach(index => {
      console.log(`  - ${index.name}: ${JSON.stringify(index.key)}`);
    });

    // Trouver TOUS les index sur pseudo (y compris pseudo_1, pseudo_2, etc.)
    console.log('\n🔍 Recherche de tous les index sur pseudo...');
    const pseudoIndexes = indexes.filter(idx => {
      return idx.key && idx.key.pseudo && idx.name !== '_id_';
    });

    if (pseudoIndexes.length === 0) {
      console.log('  ℹ️  Aucun index sur pseudo trouvé');
    } else {
      console.log(`  ⚠️  ${pseudoIndexes.length} index(s) sur pseudo trouvé(s):`);
      pseudoIndexes.forEach(idx => {
        console.log(`     - ${idx.name} (sparse: ${idx.sparse !== undefined ? idx.sparse : 'non défini'})`);
      });
    }

    // Supprimer TOUS les index sur pseudo
    console.log('\n🗑️  Suppression de TOUS les index sur pseudo...');
    for (const index of pseudoIndexes) {
      try {
        await collection.dropIndex(index.name);
        console.log(`  ✅ Index "${index.name}" supprimé`);
      } catch (error) {
        if (error.code === 27 || error.codeName === 'IndexNotFound') {
          console.log(`  ⚠️  Index "${index.name}" n'existe pas`);
        } else {
          console.warn(`  ⚠️  Erreur lors de la suppression de "${index.name}":`, error.message);
        }
      }
    }

    // Attendre que MongoDB finalise
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Vérifier qu'il n'y a plus d'index sur pseudo
    const remainingIndexes = await collection.indexes();
    const remainingPseudoIndexes = remainingIndexes.filter(idx => {
      return idx.key && idx.key.pseudo && idx.name !== '_id_';
    });

    if (remainingPseudoIndexes.length > 0) {
      console.log('\n⚠️  Il reste des index sur pseudo, tentative de suppression par clé...');
      try {
        await collection.dropIndex({ pseudo: 1 });
        console.log('  ✅ Index supprimé par clé');
      } catch (error) {
        console.warn('  ⚠️  Impossible de supprimer par clé:', error.message);
      }
    }

    // Attendre à nouveau
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Créer UN SEUL index avec le nom explicite
    console.log('\n📝 Création d\'un NOUVEL index sparse unique...');
    try {
      const result = await collection.createIndex(
        { pseudo: 1 },
        { 
          unique: true, 
          sparse: true, 
          name: 'pseudo_1',  // Nom explicite pour éviter les auto-incréments
          background: false
        }
      );
      console.log(`  ✅ Index créé: ${result}`);
    } catch (error) {
      if (error.code === 85) {
        console.log('  ⚠️  Index existe déjà, vérification...');
        const checkIndexes = await collection.indexes();
        const checkPseudoIndex = checkIndexes.find(idx => idx.name === 'pseudo_1');
        if (checkPseudoIndex) {
          console.log(`     Sparse: ${checkPseudoIndex.sparse !== undefined ? checkPseudoIndex.sparse : 'non défini'}`);
        }
      } else {
        throw error;
      }
    }

    // Vérification finale
    console.log('\n📋 Vérification finale:');
    const finalIndexes = await collection.indexes();
    const finalPseudoIndexes = finalIndexes.filter(idx => {
      return idx.key && idx.key.pseudo && idx.name !== '_id_';
    });

    if (finalPseudoIndexes.length === 0) {
      console.log('  ❌ Aucun index sur pseudo trouvé après création !');
    } else if (finalPseudoIndexes.length > 1) {
      console.log(`  ⚠️  ATTENTION: ${finalPseudoIndexes.length} index(s) sur pseudo trouvé(s) !`);
      finalPseudoIndexes.forEach(idx => {
        console.log(`     - ${idx.name} (sparse: ${idx.sparse !== undefined ? idx.sparse : 'non défini'})`);
      });
    } else {
      const finalIndex = finalPseudoIndexes[0];
      console.log(`  ✅ 1 seul index trouvé: ${finalIndex.name}`);
      console.log(`     Sparse: ${finalIndex.sparse !== undefined ? finalIndex.sparse : 'non défini'}`);
      console.log(`     Unique: ${finalIndex.unique !== undefined ? finalIndex.unique : 'non défini'}`);
      
      if (!finalIndex.sparse) {
        console.log('\n  ❌ PROBLÈME: L\'index n\'est PAS sparse !');
        console.log('     Il faut le supprimer manuellement dans MongoDB.');
      } else {
        console.log('\n  ✅ L\'index est correctement configuré !');
      }
    }

    // Compter les utilisateurs
    const nullCount = await collection.countDocuments({ pseudo: null });
    console.log(`\n📊 Utilisateurs avec pseudo: null: ${nullCount}`);

    console.log('\n✅ Correction terminée !');
    console.log('   Essayez maintenant de créer un deuxième compte utilisateur.');
    
    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Erreur:', error.message);
    if (error.code) {
      console.error(`   Code: ${error.code}`);
    }
    process.exit(1);
  }
}

fixAllPseudoIndexes();



