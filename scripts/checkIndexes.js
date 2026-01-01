const mongoose = require('mongoose');
require('dotenv').config();

async function checkIndexes() {
  try {
    console.log('🔌 Connexion à MongoDB...');
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides');
    console.log('✅ Connecté à MongoDB\n');

    const db = mongoose.connection.db;
    const collection = db.collection('users');

    // Lister TOUS les index
    console.log('📋 TOUS les index sur la collection users:');
    const indexes = await collection.indexes();
    indexes.forEach((index, i) => {
      console.log(`\n${i + 1}. ${index.name}:`);
      console.log(`   Key: ${JSON.stringify(index.key)}`);
      console.log(`   Unique: ${index.unique || false}`);
      console.log(`   Sparse: ${index.sparse !== undefined ? index.sparse : 'non défini'}`);
      console.log(`   Background: ${index.background || false}`);
      console.log(`   Version: ${index.v || 'non défini'}`);
    });

    // Chercher tous les index sur pseudo
    console.log('\n🔍 Index sur le champ "pseudo":');
    const pseudoIndexes = indexes.filter(idx => idx.key && idx.key.pseudo);
    if (pseudoIndexes.length === 0) {
      console.log('  ❌ Aucun index trouvé sur pseudo');
    } else {
      pseudoIndexes.forEach((index, i) => {
        console.log(`\n  ${i + 1}. ${index.name}:`);
        console.log(`     Unique: ${index.unique || false}`);
        console.log(`     Sparse: ${index.sparse !== undefined ? index.sparse : 'non défini'}`);
        if (!index.sparse) {
          console.log(`     ⚠️  PROBLÈME: Cet index n'est PAS sparse !`);
        }
      });
      
      if (pseudoIndexes.length > 1) {
        console.log('\n  ⚠️  ATTENTION: Plusieurs index sur pseudo détectés !');
        console.log('     Il faut supprimer les doublons.');
      }
    }

    // Compter les utilisateurs avec pseudo: null
    const nullCount = await collection.countDocuments({ pseudo: null });
    console.log(`\n📊 Utilisateurs avec pseudo: null: ${nullCount}`);

    // Vérifier les utilisateurs
    const users = await collection.find({}).toArray();
    console.log(`\n👥 Total d'utilisateurs: ${users.length}`);
    users.forEach(user => {
      console.log(`  - ${user.email}: pseudo = ${user.pseudo === null ? 'null' : user.pseudo}`);
    });

    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Erreur:', error.message);
    process.exit(1);
  }
}

checkIndexes();



