const mongoose = require('mongoose');
require('dotenv').config();

async function fixIndex() {
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
        console.log(`  - ${index.name}: ${JSON.stringify(index.key)} (sparse: ${index.sparse || false})`);
      }
    });

    // Trouver l'index pseudo
    const pseudoIndex = indexes.find(idx => idx.name === 'pseudo_1' || (idx.key && idx.key.pseudo));
    
    if (pseudoIndex) {
      console.log(`\n🔧 Index pseudo trouvé: ${pseudoIndex.name}`);
      console.log(`   Sparse: ${pseudoIndex.sparse || false}`);
      
      if (!pseudoIndex.sparse) {
        console.log('\n⚠️  L\'index n\'est pas sparse, correction en cours...');
        
        try {
          // Supprimer l'ancien index
          await collection.dropIndex(pseudoIndex.name);
          console.log('✅ Ancien index supprimé');
        } catch (error) {
          if (error.code === 27 || error.codeName === 'IndexNotFound') {
            console.log('⚠️  Index déjà supprimé ou introuvable');
          } else {
            throw error;
          }
        }
        
        // Recréer l'index avec sparse: true
        await collection.createIndex(
          { pseudo: 1 },
          { unique: true, sparse: true, name: 'pseudo_1' }
        );
        console.log('✅ Nouvel index créé avec sparse: true');
      } else {
        console.log('\n✅ L\'index est déjà correct (sparse: true)');
      }
    } else {
      console.log('\n📝 Aucun index pseudo trouvé, création...');
      await collection.createIndex(
        { pseudo: 1 },
        { unique: true, sparse: true, name: 'pseudo_1' }
      );
      console.log('✅ Index créé avec sparse: true');
    }

    // Vérifier le résultat
    console.log('\n📋 Index après correction:');
    const newIndexes = await collection.indexes();
    const newPseudoIndex = newIndexes.find(idx => idx.name === 'pseudo_1' || (idx.key && idx.key.pseudo));
    if (newPseudoIndex) {
      console.log(`  - ${newPseudoIndex.name}: ${JSON.stringify(newPseudoIndex.key)} (sparse: ${newPseudoIndex.sparse || false})`);
    }

    console.log('\n✅ Correction terminée ! Vous pouvez maintenant créer plusieurs utilisateurs.');
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

fixIndex();



