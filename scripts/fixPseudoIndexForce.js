const mongoose = require('mongoose');
require('dotenv').config();

async function fixPseudoIndexForce() {
  try {
    console.log('🔌 Connexion à MongoDB...');
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides');
    console.log('✅ Connecté à MongoDB\n');

    const db = mongoose.connection.db;
    const collection = db.collection('users');

    // Lister les index existants
    console.log('📋 Index existants:');
    const indexes = await collection.indexes();
    indexes.forEach(index => {
      if (index.key && index.key.pseudo) {
        console.log(`  - ${index.name}: ${JSON.stringify(index.key)} (sparse: ${index.sparse || false}, unique: ${index.unique || false})`);
      }
    });

    // Supprimer TOUS les index sur pseudo (même s'ils sont déjà sparse)
    console.log('\n🔧 Suppression de tous les index sur pseudo...');
    try {
      await collection.dropIndex('pseudo_1');
      console.log('✅ Index pseudo_1 supprimé');
    } catch (error) {
      if (error.code === 27 || error.codeName === 'IndexNotFound') {
        console.log('⚠️  Index pseudo_1 n\'existe pas');
      } else {
        console.warn('⚠️  Erreur lors de la suppression:', error.message);
      }
    }

    // Essayer de supprimer par clé aussi
    try {
      await collection.dropIndex({ pseudo: 1 });
      console.log('✅ Index sur pseudo supprimé (méthode alternative)');
    } catch (error) {
      if (error.code === 27 || error.codeName === 'IndexNotFound') {
        // C'est normal, l'index n'existe peut-être pas
      } else {
        console.warn('⚠️  Erreur lors de la suppression alternative:', error.message);
      }
    }

    // Attendre un peu pour que MongoDB finalise la suppression
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Recréer l'index avec sparse: true
    console.log('\n📝 Création du nouvel index avec sparse: true...');
    try {
      await collection.createIndex(
        { pseudo: 1 },
        { 
          unique: true, 
          sparse: true, 
          name: 'pseudo_1',
          background: true
        }
      );
      console.log('✅ Nouvel index créé avec sparse: true');
    } catch (error) {
      if (error.code === 85) {
        console.log('⚠️  Index existe déjà, vérification...');
        // Vérifier l'index
        const newIndexes = await collection.indexes();
        const newPseudoIndex = newIndexes.find(idx => idx.name === 'pseudo_1' || (idx.key && idx.key.pseudo));
        if (newPseudoIndex) {
          console.log(`   Index trouvé: sparse=${newPseudoIndex.sparse}, unique=${newPseudoIndex.unique}`);
        }
      } else {
        throw error;
      }
    }

    // Vérifier le résultat
    console.log('\n📋 Index après correction:');
    const finalIndexes = await collection.indexes();
    const finalPseudoIndex = finalIndexes.find(idx => idx.name === 'pseudo_1' || (idx.key && idx.key.pseudo));
    if (finalPseudoIndex) {
      console.log(`  - ${finalPseudoIndex.name}:`);
      console.log(`    Sparse: ${finalPseudoIndex.sparse || false}`);
      console.log(`    Unique: ${finalPseudoIndex.unique || false}`);
      console.log(`    Key: ${JSON.stringify(finalPseudoIndex.key)}`);
    } else {
      console.log('  ⚠️  Aucun index pseudo trouvé !');
    }

    // Test : compter les utilisateurs avec pseudo: null
    const nullPseudoCount = await collection.countDocuments({ pseudo: null });
    console.log(`\n📊 Utilisateurs avec pseudo: null: ${nullPseudoCount}`);

    console.log('\n✅ Correction terminée !');
    console.log('   Vous pouvez maintenant créer plusieurs utilisateurs avec pseudo: null');
    
    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Erreur:', error.message);
    if (error.code) {
      console.error(`   Code: ${error.code}`);
    }
    if (error.codeName) {
      console.error(`   CodeName: ${error.codeName}`);
    }
    process.exit(1);
  }
}

fixPseudoIndexForce();



