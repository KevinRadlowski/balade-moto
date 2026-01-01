const mongoose = require('mongoose');
require('dotenv').config();

const User = require('../src/models/User');
const Ride = require('../src/models/Ride');
const bcrypt = require('bcryptjs');

// Coordonnées GPS de test (Paris, Lyon, Marseille)
const mockLocations = [
  { name: 'Paris', lat: 48.8566, lng: 2.3522 },
  { name: 'Lyon', lat: 45.7640, lng: 4.8357 },
  { name: 'Marseille', lat: 43.2965, lng: 5.3698 },
  { name: 'Toulouse', lat: 43.6047, lng: 1.4442 },
  { name: 'Nice', lat: 43.7102, lng: 7.2620 }
];

async function generateMockData() {
  try {
    // Connexion à MongoDB
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Connecté à MongoDB');

    // Vérifier si des utilisateurs existent déjà
    const existingUsers = await User.find();
    let users = [];

    // Créer ou récupérer 3 utilisateurs de test
    const hashedPassword = await bcrypt.hash('password123', 10);
    
    // Vérifier/créer user1
    let user1 = existingUsers.find(u => u.email === 'test1@example.com');
    if (!user1) {
      console.log('📝 Création de l\'utilisateur test1...');
      user1 = new User({
        email: 'test1@example.com',
        password: hashedPassword,
        role: 'user',
        emailVerified: true,
        firstName: 'Jean',
        lastName: 'Dupont',
        pseudo: 'jean_moto',
        vehiclePreference: 'moto'
      });
      await user1.save();
    }
    users.push(user1);

    // Vérifier/créer user2
    let user2 = existingUsers.find(u => u.email === 'test2@example.com');
    if (!user2) {
      console.log('📝 Création de l\'utilisateur test2...');
      user2 = new User({
        email: 'test2@example.com',
        password: hashedPassword,
        role: 'user',
        emailVerified: true,
        firstName: 'Marie',
        lastName: 'Martin',
        pseudo: 'marie_rider',
        vehiclePreference: 'moto'
      });
      await user2.save();
    }
    users.push(user2);

    // Vérifier/créer user3
    let user3 = existingUsers.find(u => u.email === 'test3@example.com');
    if (!user3) {
      console.log('📝 Création de l\'utilisateur test3...');
      user3 = new User({
        email: 'test3@example.com',
        password: hashedPassword,
        role: 'user',
        emailVerified: true,
        firstName: 'Pierre',
        lastName: 'Bernard',
        pseudo: 'pierre_car',
        vehiclePreference: 'voiture'
      });
      await user3.save();
    }
    users.push(user3);

    console.log(`✅ ${users.length} utilisateurs disponibles`);

    // Vérifier si des balades existent déjà
    const existingRides = await Ride.find();
    
    if (existingRides.length === 0) {
      console.log('📝 Création de balades de test...');

      // Vérifier que nous avons au moins 3 utilisateurs
      if (users.length < 3) {
        console.error('❌ Erreur: Au moins 3 utilisateurs sont nécessaires pour créer les balades de test');
        await mongoose.disconnect();
        process.exit(1);
      }

      const now = new Date();
      
      // Balade 1 : Demain à Paris (moto)
      const ride1Date = new Date(now);
      ride1Date.setDate(ride1Date.getDate() + 1);
      ride1Date.setHours(10, 0, 0, 0);

      const ride1 = new Ride({
        titre: 'Balade en forêt de Fontainebleau',
        description: 'Belle balade en moto à travers la forêt de Fontainebleau. Départ depuis Paris, parcours d\'environ 150km.',
        typeVehicule: 'moto',
        date: ride1Date,
        heure: '10:00',
        lieuDepart: 'Paris, Place de la Bastille',
        lieuArrivee: 'Fontainebleau, Château',
        rayon: 50,
        organisateur: users[0]._id,
        visibilite: 'publique',
        participants: [users[0]._id, users[1]._id],
        localisation: {
          type: 'Point',
          coordinates: [2.3522, 48.8566] // Paris
        }
      });
      await ride1.save();
      console.log('✅ Balade 1 créée : Balade en forêt de Fontainebleau');

      // Balade 2 : Dans 3 jours à Lyon (moto)
      const ride2Date = new Date(now);
      ride2Date.setDate(ride2Date.getDate() + 3);
      ride2Date.setHours(14, 30, 0, 0);

      const ride2 = new Ride({
        titre: 'Route des Alpes - Col du Galibier',
        description: 'Ascension du mythique Col du Galibier. Départ de Lyon, retour prévu en fin d\'après-midi.',
        typeVehicule: 'moto',
        date: ride2Date,
        heure: '14:30',
        lieuDepart: 'Lyon, Place Bellecour',
        lieuArrivee: 'Col du Galibier',
        rayon: 200,
        organisateur: users[1]._id,
        visibilite: 'publique',
        participants: [users[1]._id],
        localisation: {
          type: 'Point',
          coordinates: [4.8357, 45.7640] // Lyon
        }
      });
      await ride2.save();
      console.log('✅ Balade 2 créée : Route des Alpes - Col du Galibier');

      // Balade 3 : Dans 5 jours à Marseille (voiture)
      const ride3Date = new Date(now);
      ride3Date.setDate(ride3Date.getDate() + 5);
      ride3Date.setHours(9, 0, 0, 0);

      const ride3 = new Ride({
        titre: 'Route des Calanques en voiture',
        description: 'Découverte des Calanques de Marseille en voiture. Parcours panoramique avec plusieurs arrêts photo.',
        typeVehicule: 'voiture',
        date: ride3Date,
        heure: '09:00',
        lieuDepart: 'Marseille, Vieux-Port',
        lieuArrivee: 'Cassis, Port',
        rayon: 30,
        organisateur: users[2]._id,
        visibilite: 'publique',
        participants: [users[2]._id, users[0]._id],
        localisation: {
          type: 'Point',
          coordinates: [5.3698, 43.2965] // Marseille
        }
      });
      await ride3.save();
      console.log('✅ Balade 3 créée : Route des Calanques en voiture');

      // Balade 4 : Passée (pour tester les notes)
      const pastRideDate = new Date(now);
      pastRideDate.setDate(pastRideDate.getDate() - 2);
      pastRideDate.setHours(10, 0, 0, 0);

      const ride4 = new Ride({
        titre: 'Balade côtière - Côte d\'Azur',
        description: 'Balade passée le long de la Côte d\'Azur. Excellente expérience !',
        typeVehicule: 'moto',
        date: pastRideDate,
        heure: '10:00',
        lieuDepart: 'Nice, Promenade des Anglais',
        lieuArrivee: 'Cannes, Croisette',
        rayon: 40,
        organisateur: users[0]._id,
        visibilite: 'publique',
        participants: [users[0]._id, users[1]._id, users[2]._id],
        localisation: {
          type: 'Point',
          coordinates: [7.2620, 43.7102] // Nice
        }
      });
      await ride4.save();
      console.log('✅ Balade 4 créée : Balade côtière (passée)');

      console.log(`\n✅ ${4} balades créées avec succès !`);
    } else {
      console.log(`ℹ️  ${existingRides.length} balades existent déjà`);
    }

    console.log('\n📊 Résumé :');
    console.log(`   - Utilisateurs : ${await User.countDocuments()}`);
    console.log(`   - Balades : ${await Ride.countDocuments()}`);
    console.log('\n✅ Données de test générées avec succès !');
    console.log('\n🔑 Comptes de test :');
    console.log('   Email: test1@example.com | Password: password123');
    console.log('   Email: test2@example.com | Password: password123');
    console.log('   Email: test3@example.com | Password: password123');

    await mongoose.disconnect();
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur lors de la génération des données de test:', error);
    await mongoose.disconnect();
    process.exit(1);
  }
}

generateMockData();

