const mongoose = require('mongoose');
require('dotenv').config();

async function fixPseudoIndex() {
  try {
    // Connexion à MongoDB
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides');
    console.log('✅ Connecté à MongoDB');

    const db = mongoose.connection.db;
    const collection = db.collection('users');

    // Lister les index existants
    const indexes = await collection.indexes();
    console.log('\n📋 Index existants:');
    indexes.forEach(index => {
      console.log(`  - ${index.name}: ${JSON.stringify(index.key)}`);
    });

    // Supprimer l'ancien index sur pseudo s'il existe
    try {
      // Essayer de supprimer par nom
      await collection.dropIndex('pseudo_1');
      console.log('\n✅ Ancien index pseudo_1 supprimé');
    } catch (error) {
      if (error.code === 27 || error.codeName === 'IndexNotFound') {
        console.log('\n⚠️  Index pseudo_1 n\'existe pas, on continue...');
      } else {
        // Essayer de supprimer tous les index sur pseudo
        try {
          const indexes = await collection.indexes();
          const pseudoIndex = indexes.find(idx => idx.key && idx.key.pseudo);
          if (pseudoIndex) {
            await collection.dropIndex(pseudoIndex.name);
            console.log(`\n✅ Ancien index ${pseudoIndex.name} supprimé`);
          }
        } catch (err) {
          console.log('\n⚠️  Impossible de supprimer l\'ancien index, on continue...');
        }
      }
    }

    // Recréer l'index avec sparse: true
    await collection.createIndex(
      { pseudo: 1 },
      { 
        unique: true,
        sparse: true,
        name: 'pseudo_1'
      }
    );
    console.log('✅ Nouvel index pseudo_1 créé avec sparse: true');

    // Vérifier les index
    const newIndexes = await collection.indexes();
    console.log('\n📋 Nouveaux index:');
    newIndexes.forEach(index => {
      if (index.name === 'pseudo_1') {
        console.log(`  - ${index.name}: ${JSON.stringify(index.key)} (sparse: ${index.sparse})`);
      }
    });

    console.log('\n✅ Correction terminée !');
    await mongoose.connection.close();
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

fixPseudoIndex();

