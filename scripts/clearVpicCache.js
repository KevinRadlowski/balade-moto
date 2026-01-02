const mongoose = require('mongoose');
require('dotenv').config();

async function clearVpicCache() {
  try {
    console.log('🔌 Connexion à MongoDB...');
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides');
    console.log('✅ Connecté à MongoDB\n');

    const VpicCache = require('../src/models/VpicCache');
    
    // Supprimer tous les caches vides (tableaux avec 0 éléments)
    const allCaches = await VpicCache.find({});
    console.log(`📋 Caches trouvés: ${allCaches.length}`);
    
    let deletedCount = 0;
    for (const cache of allCaches) {
      const dataLength = Array.isArray(cache.data) ? cache.data.length : 'N/A';
      if (Array.isArray(cache.data) && cache.data.length === 0) {
        await VpicCache.deleteOne({ _id: cache._id });
        deletedCount++;
        console.log(`  ❌ Supprimé: ${cache.key} (0 éléments)`);
      } else {
        console.log(`  ✅ Conservé: ${cache.key} (${dataLength} éléments)`);
      }
    }
    
    console.log(`\n✅ ${deletedCount} cache(s) vide(s) supprimé(s)\n`);
    
    await mongoose.disconnect();
    console.log('✅ Terminé');
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

clearVpicCache();
