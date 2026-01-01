const mongoose = require('mongoose');
require('dotenv').config();

async function fixPseudoIndexFinal() {
  try {
    console.log('🔌 Connexion à MongoDB...');
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides');
    console.log('✅ Connecté à MongoDB\n');

    const db = mongoose.connection.db;
    const collection = db.collection('users');

    // Vérifier l'état actuel
    console.log('📋 État actuel:');
    const indexes = await collection.indexes();
    const pseudoIndex = indexes.find(idx => idx.name === 'pseudo_1' || (idx.key && idx.key.pseudo));
    
    if (pseudoIndex) {
      console.log(`  Index trouvé: ${pseudoIndex.name}`);
      console.log(`  Sparse: ${pseudoIndex.sparse || false}`);
      console.log(`  Unique: ${pseudoIndex.unique || false}`);
    }

    const nullCount = await collection.countDocuments({ pseudo: null });
    console.log(`  Utilisateurs avec pseudo: null: ${nullCount}\n`);

    // Supprimer l'index complètement
    console.log('🗑️  Suppression de l\'index pseudo_1...');
    try {
      await collection.dropIndex('pseudo_1');
      console.log('✅ Index supprimé');
    } catch (error) {
      if (error.code === 27 || error.codeName === 'IndexNotFound') {
        console.log('⚠️  Index n\'existe pas déjà');
      } else {
        console.warn('⚠️  Erreur:', error.message);
        // Essayer avec la clé
        try {
          await collection.dropIndex({ pseudo: 1 });
          console.log('✅ Index supprimé (méthode alternative)');
        } catch (err2) {
          console.warn('⚠️  Impossible de supprimer:', err2.message);
        }
      }
    }

    // Attendre que MongoDB finalise
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Recréer l'index avec sparse: true de manière explicite
    console.log('\n📝 Création du nouvel index sparse...');
    try {
      // Utiliser createIndex avec toutes les options explicites
      const result = await collection.createIndex(
        { pseudo: 1 },
        { 
          unique: true, 
          sparse: true, 
          name: 'pseudo_1',
          background: false  // Créer en foreground pour être sûr
        }
      );
      console.log('✅ Index créé:', result);
    } catch (error) {
      console.error('❌ Erreur lors de la création:', error.message);
      throw error;
    }

    // Vérifier le résultat
    console.log('\n📋 Vérification de l\'index créé:');
    const newIndexes = await collection.indexes();
    const newPseudoIndex = newIndexes.find(idx => idx.name === 'pseudo_1' || (idx.key && idx.key.pseudo));
    
    if (newPseudoIndex) {
      console.log(`  Nom: ${newPseudoIndex.name}`);
      console.log(`  Sparse: ${newPseudoIndex.sparse !== undefined ? newPseudoIndex.sparse : 'non défini'}`);
      console.log(`  Unique: ${newPseudoIndex.unique !== undefined ? newPseudoIndex.unique : 'non défini'}`);
      console.log(`  Key: ${JSON.stringify(newPseudoIndex.key)}`);
      
      if (!newPseudoIndex.sparse) {
        console.log('\n⚠️  ATTENTION: L\'index n\'est PAS sparse !');
        console.log('   Il faut le supprimer et le recréer manuellement dans MongoDB.');
      } else {
        console.log('\n✅ L\'index est correctement configuré avec sparse: true');
      }
    } else {
      console.log('❌ Index non trouvé après création !');
    }

    // Test : essayer de créer un deuxième utilisateur avec pseudo: null
    console.log('\n🧪 Test: Vérification des utilisateurs avec pseudo: null...');
    const finalNullCount = await collection.countDocuments({ pseudo: null });
    console.log(`  ${finalNullCount} utilisateur(s) avec pseudo: null`);
    
    if (finalNullCount > 1 && newPseudoIndex && newPseudoIndex.sparse) {
      console.log('  ✅ Plusieurs utilisateurs avec pseudo: null sont autorisés');
    } else if (finalNullCount === 1) {
      console.log('  ℹ️  Un seul utilisateur avec pseudo: null pour l\'instant (normal)');
    }

    console.log('\n✅ Correction terminée !');
    console.log('   Essayez maintenant de créer un deuxième compte utilisateur.');
    
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
    console.error('\n💡 Solution alternative:');
    console.error('   Exécutez dans MongoDB:');
    console.error('   db.users.dropIndex("pseudo_1")');
    console.error('   db.users.createIndex({ pseudo: 1 }, { unique: true, sparse: true, name: "pseudo_1" })');
    process.exit(1);
  }
}

fixPseudoIndexFinal();



