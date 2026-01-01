const mongoose = require('mongoose');
require('dotenv').config();

async function resetDatabase() {
  try {
    console.log('🔌 Connexion à MongoDB...');
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides');
    console.log('✅ Connecté à MongoDB\n');

    const db = mongoose.connection.db;
    const dbName = db.databaseName;

    // Lister toutes les collections
    const collections = await db.listCollections().toArray();
    console.log(`📋 Collections trouvées dans "${dbName}":`);
    collections.forEach(col => {
      console.log(`  - ${col.name}`);
    });

    if (collections.length === 0) {
      console.log('\n⚠️  Aucune collection à supprimer');
    } else {
      console.log(`\n🗑️  Suppression de ${collections.length} collection(s)...`);
      
      // Supprimer toutes les collections
      for (const collection of collections) {
        try {
          await db.collection(collection.name).drop();
          console.log(`  ✅ Collection "${collection.name}" supprimée`);
        } catch (error) {
          console.warn(`  ⚠️  Erreur lors de la suppression de "${collection.name}":`, error.message);
        }
      }
    }

    // Recréer les index pour les collections principales
    console.log('\n📝 Recréation des index...');
    
    // Index pour users
    try {
      const usersCollection = db.collection('users');
      await usersCollection.createIndex({ email: 1 }, { unique: true, background: true });
      await usersCollection.createIndex(
        { pseudo: 1 },
        { unique: true, sparse: true, name: 'pseudo_1', background: true }
      );
      console.log('  ✅ Index pour "users" créés');
    } catch (error) {
      console.warn('  ⚠️  Erreur lors de la création des index pour "users":', error.message);
    }

    // Index pour rides
    try {
      const ridesCollection = db.collection('rides');
      await ridesCollection.createIndex({ localisation: '2dsphere' });
      await ridesCollection.createIndex({ organisateur: 1 });
      await ridesCollection.createIndex({ date: 1 });
      console.log('  ✅ Index pour "rides" créés');
    } catch (error) {
      console.warn('  ⚠️  Erreur lors de la création des index pour "rides":', error.message);
    }

    // Index pour messages
    try {
      const messagesCollection = db.collection('messages');
      await messagesCollection.createIndex({ idBalade: 1, date: -1 });
      await messagesCollection.createIndex({ idGroupe: 1, date: -1 });
      await messagesCollection.createIndex({ auteur: 1 });
      console.log('  ✅ Index pour "messages" créés');
    } catch (error) {
      console.warn('  ⚠️  Erreur lors de la création des index pour "messages":', error.message);
    }

    // Index pour ratings
    try {
      const ratingsCollection = db.collection('ratings');
      await ratingsCollection.createIndex({ utilisateur: 1, balade: 1 }, { unique: true });
      await ratingsCollection.createIndex({ balade: 1, dateNote: -1 });
      console.log('  ✅ Index pour "ratings" créés');
    } catch (error) {
      console.warn('  ⚠️  Erreur lors de la création des index pour "ratings":', error.message);
    }

    // Index pour likes
    try {
      const likesCollection = db.collection('likes');
      await likesCollection.createIndex({ utilisateur: 1, balade: 1 }, { unique: true });
      await likesCollection.createIndex({ balade: 1, dateLike: -1 });
      await likesCollection.createIndex({ utilisateur: 1 });
      console.log('  ✅ Index pour "likes" créés');
    } catch (error) {
      console.warn('  ⚠️  Erreur lors de la création des index pour "likes":', error.message);
    }

    // Index pour groups
    try {
      const groupsCollection = db.collection('groups');
      await groupsCollection.createIndex({ createur: 1 });
      await groupsCollection.createIndex({ visibilite: 1 });
      console.log('  ✅ Index pour "groups" créés');
    } catch (error) {
      console.warn('  ⚠️  Erreur lors de la création des index pour "groups":', error.message);
    }

    // Vérifier le résultat
    const finalCollections = await db.listCollections().toArray();
    console.log(`\n📊 État final: ${finalCollections.length} collection(s) dans "${dbName}"`);

    console.log('\n✅ Base de données réinitialisée avec succès !');
    console.log('   Tous les index ont été recréés correctement.');
    console.log('   Vous pouvez maintenant créer de nouveaux utilisateurs et données.');
    
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

// Demander confirmation avant de supprimer
const readline = require('readline');
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log('⚠️  ATTENTION : Cette opération va supprimer TOUTES les données de la base de données !');
console.log('   Base de données:', process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides');
console.log('');

rl.question('Êtes-vous sûr de vouloir continuer ? (tapez "OUI" pour confirmer): ', (answer) => {
  rl.close();
  
  if (answer.trim().toUpperCase() === 'OUI') {
    resetDatabase();
  } else {
    console.log('\n❌ Opération annulée.');
    process.exit(0);
  }
});



