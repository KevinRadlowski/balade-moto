/**
 * Script de vérification et synchronisation des index MongoDB
 * 
 * Ce script :
 * 1. Se connecte à MongoDB
 * 2. Synchronise tous les index définis dans les modèles Mongoose
 * 3. Affiche un rapport des index créés/modifiés
 * 
 * Usage: npm run db:indexes
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Importer tous les modèles pour que Mongoose enregistre leurs index
const Ride = require('../src/models/Ride');
const Group = require('../src/models/Group');
const Message = require('../src/models/Message');
const User = require('../src/models/User');
const Like = require('../src/models/Like');
const Rating = require('../src/models/Rating');
const Vehicle = require('../src/models/Vehicle');
const Review = require('../src/models/Review');
const RouteCache = require('../src/models/RouteCache');
const PromoCode = require('../src/models/PromoCode');
const Reputation = require('../src/models/Reputation');
const VehicleStats = require('../src/models/VehicleStats');
const Feedback = require('../src/models/Feedback');
const MaintenanceReminder = require('../src/models/MaintenanceReminder');
const Achievement = require('../src/models/Achievement');
const VehicleDocument = require('../src/models/VehicleDocument');
const MaintenanceItem = require('../src/models/MaintenanceItem');
const OdometerEntry = require('../src/models/OdometerEntry');
const MaintenanceLog = require('../src/models/MaintenanceLog');
const VehicleReminder = require('../src/models/VehicleReminder');
const Referral = require('../src/models/Referral');
const CatalogProposal = require('../src/models/CatalogProposal');
const CatalogMeta = require('../src/models/CatalogMeta');
const CatalogApprovedEntry = require('../src/models/CatalogApprovedEntry');
const NotificationSent = require('../src/models/NotificationSent');

async function ensureIndexes() {
  try {
    console.log('🔌 Connexion à MongoDB...');
    const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides';
    await mongoose.connect(mongoUri);
    console.log('✅ Connecté à MongoDB\n');

    const models = [
      { name: 'Ride', model: Ride },
      { name: 'Group', model: Group },
      { name: 'Message', model: Message },
      { name: 'User', model: User },
      { name: 'Like', model: Like },
      { name: 'Rating', model: Rating },
      { name: 'Vehicle', model: Vehicle },
      { name: 'Review', model: Review },
      { name: 'RouteCache', model: RouteCache },
      { name: 'PromoCode', model: PromoCode },
      { name: 'Reputation', model: Reputation },
      { name: 'VehicleStats', model: VehicleStats },
      { name: 'Feedback', model: Feedback },
      { name: 'MaintenanceReminder', model: MaintenanceReminder },
      { name: 'Achievement', model: Achievement },
      { name: 'VehicleDocument', model: VehicleDocument },
      { name: 'MaintenanceItem', model: MaintenanceItem },
      { name: 'OdometerEntry', model: OdometerEntry },
      { name: 'MaintenanceLog', model: MaintenanceLog },
      { name: 'VehicleReminder', model: VehicleReminder },
      { name: 'Referral', model: Referral },
      { name: 'CatalogProposal', model: CatalogProposal },
      { name: 'CatalogMeta', model: CatalogMeta },
      { name: 'CatalogApprovedEntry', model: CatalogApprovedEntry },
      { name: 'NotificationSent', model: NotificationSent },
    ];

    console.log('📝 Synchronisation des index...\n');

    for (const { name, model } of models) {
      try {
        console.log(`  🔄 ${name}...`);
        await model.syncIndexes();
        console.log(`  ✅ ${name} - Index synchronisés`);
      } catch (error) {
        console.error(`  ❌ ${name} - Erreur: ${error.message}`);
      }
    }

    console.log('\n📊 Rapport des index par collection:\n');

    // Afficher les index de chaque collection
    for (const { name, model } of models) {
      try {
        const collectionName = model.collection.name;
        const indexes = await model.collection.indexes();
        
        console.log(`📦 ${name} (${collectionName}):`);
        indexes.forEach((index, idx) => {
          const keys = Object.keys(index.key).map(k => `${k}:${index.key[k]}`).join(', ');
          const options = [];
          if (index.unique) options.push('unique');
          if (index.sparse) options.push('sparse');
          if (index.expireAfterSeconds) options.push(`expire:${index.expireAfterSeconds}s`);
          const opts = options.length > 0 ? ` [${options.join(', ')}]` : '';
          console.log(`   ${idx + 1}. { ${keys} }${opts}`);
        });
        console.log('');
      } catch (error) {
        console.error(`  ❌ Erreur lors de la récupération des index pour ${name}: ${error.message}`);
      }
    }

    console.log('✅ Synchronisation terminée avec succès !');
    console.log('\n💡 Pour vérifier les index dans MongoDB directement:');
    console.log('   db.rides.getIndexes()');
    console.log('   db.groups.getIndexes()');
    console.log('   db.messages.getIndexes()');

    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Erreur:', error.message);
    if (error.stack) {
      console.error(error.stack);
    }
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Exécuter le script
ensureIndexes();

