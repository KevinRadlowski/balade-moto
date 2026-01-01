require('dotenv').config();
const mongoose = require('mongoose');
const Ride = require('../src/models/Ride');

// Connexion à MongoDB - utiliser la même configuration que l'app
const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/balades-moto';

async function insertMockRides() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connecté à MongoDB');

    // ID de l'organisateur (remplacez par un ID valide de votre base)
    const organisateurId = new mongoose.Types.ObjectId('6953c913bb17fb56a3af23fa');

    // Balades mockées avec des dates passées (28 et 29 décembre 2025)
    const mockRides = [
      {
        titre: "Deuxieme test de balade (Mock - 28 déc)",
        typeVehicule: "moto",
        date: new Date('2025-12-28T10:30:00.000Z'),
        heure: "11:30",
        lieuDepart: "45.727992, 4.976267",
        lieuArrivee: "45.740412, 4.989303",
        waypoints: [
          {
            type: "depart",
            address: "45.727992, 4.976267",
            coordinates: {
              type: "Point",
              coordinates: [4.976266913377185, 45.72799188325398]
            },
            order: 0
          },
          {
            type: "checkpoint",
            address: "45.743903, 5.708717",
            coordinates: {
              type: "Point",
              coordinates: [5.7087174924710204, 45.74390293977301]
            },
            order: 1
          },
          {
            type: "arrivee",
            address: "45.740412, 4.989303",
            coordinates: {
              type: "Point",
              coordinates: [4.989303453961829, 45.740412150666394]
            },
            order: 2
          }
        ],
        localisation: {
          type: "Point",
          coordinates: [4.976266913377185, 45.72799188325398]
        },
        rayon: 50,
        organisateur: organisateurId,
        visibilite: "publique",
        participants: [organisateurId],
        likes: [],
        noteMoyenne: 0,
        notes: []
      },
      {
        titre: "Test de notation (Mock - 28 déc)",
        typeVehicule: "moto",
        date: new Date('2025-12-28T07:20:00.000Z'),
        heure: "08:20",
        lieuDepart: "45.739215, 4.984780",
        lieuArrivee: "45.688920, 5.001946",
        waypoints: [
          {
            type: "depart",
            address: "45.739215, 4.984780",
            coordinates: {
              type: "Point",
              coordinates: [4.984779703857436, 45.73921506410556]
            },
            order: 0
          },
          {
            type: "checkpoint",
            address: "45.698945, 4.967614",
            coordinates: {
              type: "Point",
              coordinates: [4.9676135661621235, 45.69894546332706]
            },
            order: 1
          },
          {
            type: "arrivee",
            address: "45.688920, 5.001946",
            coordinates: {
              type: "Point",
              coordinates: [5.0019458415527485, 45.68892037002641]
            },
            order: 2
          }
        ],
        localisation: {
          type: "Point",
          coordinates: [4.984779703857436, 45.73921506410556]
        },
        rayon: 0,
        organisateur: organisateurId,
        visibilite: "publique",
        participants: [organisateurId],
        likes: [],
        noteMoyenne: 0,
        notes: []
      },
      {
        titre: "Balade autour du périph Parisien (Mock - 29 déc)",
        description: "Balade périph parisien",
        typeVehicule: "voiture",
        date: new Date('2025-12-29T10:30:00.000Z'),
        heure: "11:30",
        lieuDepart: "48.901125, 2.336441",
        lieuArrivee: "48.900404, 2.328742",
        waypoints: [
          {
            type: "depart",
            address: "48.901125, 2.336441",
            coordinates: {
              type: "Point",
              coordinates: [2.3364408137220805, 48.90112456900216]
            },
            order: 0
          },
          {
            type: "checkpoint",
            address: "48.866903, 2.413743",
            coordinates: {
              type: "Point",
              coordinates: [2.4137432335095577, 48.86690329861679]
            },
            order: 1
          },
          {
            type: "arrivee",
            address: "48.900404, 2.328742",
            coordinates: {
              type: "Point",
              coordinates: [2.3287419768781215, 48.900404256450116]
            },
            order: 2
          }
        ],
        localisation: {
          type: "Point",
          coordinates: [2.3364408137220805, 48.90112456900216]
        },
        rayon: 30,
        organisateur: organisateurId,
        visibilite: "publique",
        participants: [organisateurId],
        likes: [],
        noteMoyenne: 0,
        notes: []
      },
      {
        titre: "Balade autour de chassieu (Mock - 29 déc)",
        description: "Petite balade sur le périph autour de chassieu",
        typeVehicule: "moto",
        date: new Date('2025-12-29T11:00:00.000Z'),
        heure: "12:00",
        lieuDepart: "45.740847, 4.986324",
        lieuArrivee: "45.752195, 4.987061",
        waypoints: [
          {
            type: "depart",
            address: "45.740847, 4.986324",
            coordinates: {
              type: "Point",
              coordinates: [4.986323913038042, 45.74084714077236]
            },
            order: 0
          },
          {
            type: "checkpoint",
            address: "45.735336, 4.903583",
            coordinates: {
              type: "Point",
              coordinates: [4.903583129346636, 45.73533591642358]
            },
            order: 1
          },
          {
            type: "arrivee",
            address: "45.752195, 4.987061",
            coordinates: {
              type: "Point",
              coordinates: [4.987061105560788, 45.75219530421838]
            },
            order: 2
          }
        ],
        localisation: {
          type: "Point",
          coordinates: [4.986323913038042, 45.74084714077236]
        },
        rayon: 50,
        organisateur: organisateurId,
        visibilite: "publique",
        participants: [organisateurId],
        likes: [],
        noteMoyenne: 0,
        notes: []
      }
    ];

    // Insérer les balades
    const insertedRides = await Ride.insertMany(mockRides);
    console.log(`✅ ${insertedRides.length} balades mockées insérées avec succès:`);
    insertedRides.forEach((ride, index) => {
      console.log(`  ${index + 1}. "${ride.titre}" - Date: ${ride.date.toISOString()}, Heure: ${ride.heure}`);
    });

    await mongoose.disconnect();
    console.log('✅ Déconnecté de MongoDB');
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

insertMockRides();

