/**
 * Tests d'intégration pour les routes rides
 * Teste les endpoints avec une base de données de test
 */

const request = require('supertest');
const mongoose = require('mongoose');
const { app } = require('../../src/app');
const User = require('../../src/models/User');
const Ride = require('../../src/models/Ride');
const jwt = require('jsonwebtoken');
require('dotenv').config();

// Base de données de test
const TEST_DB_URI = process.env.TEST_MONGO_URI || 'mongodb://localhost:27017/ridetogether_test';

describe('Ride Routes Integration', () => {
  let authToken;
  let testUser;
  let testRide;

  beforeAll(async () => {
    // Connexion à la DB de test
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(TEST_DB_URI);
    }

    // Créer un utilisateur de test
    testUser = new User({
      email: 'test@example.com',
      password: 'hashedpassword',
      pseudo: 'testuser',
      firstName: 'Test',
      lastName: 'User',
      phoneE164: '+33612345678',
      phoneVerified: true,
      status: 'active'
    });
    await testUser.save();

    // Générer un token JWT
    authToken = jwt.sign(
      { userId: testUser._id },
      process.env.JWT_SECRET || 'test-secret',
      { expiresIn: '1h' }
    );
  });

  afterAll(async () => {
    // Nettoyer la DB de test
    await User.deleteMany({});
    await Ride.deleteMany({});
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    // Nettoyer les rides avant chaque test
    await Ride.deleteMany({});
  });

  describe('GET /api/rides', () => {
    it('devrait retourner une liste de balades avec pagination', async () => {
      // Créer quelques balades de test
      const rides = [
        {
          titre: 'Balade 1',
          description: 'Description 1',
          typeVehicule: 'moto',
          date: new Date(Date.now() + 86400000),
          heure: '10:00',
          lieuDepart: 'Paris',
          lieuArrivee: 'Lyon',
          organisateur: testUser._id,
          visibilite: 'publique',
          participants: [{ userId: testUser._id }],
          status: 'scheduled'
        },
        {
          titre: 'Balade 2',
          description: 'Description 2',
          typeVehicule: 'moto',
          date: new Date(Date.now() + 172800000),
          heure: '14:00',
          lieuDepart: 'Lyon',
          lieuArrivee: 'Marseille',
          organisateur: testUser._id,
          visibilite: 'publique',
          participants: [{ userId: testUser._id }],
          status: 'scheduled'
        }
      ];

      await Ride.insertMany(rides);

      const response = await request(app)
        .get('/api/rides')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ page: 1, limit: 10 })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.rides).toBeDefined();
      expect(Array.isArray(response.body.data.rides)).toBe(true);
      expect(response.body.data.pagination).toBeDefined();
      expect(response.body.data.pagination.page).toBe(1);
      expect(response.body.data.pagination.limit).toBe(10);
    });

    it('devrait filtrer par typeVehicule', async () => {
      await Ride.create({
        titre: 'Balade moto',
        typeVehicule: 'moto',
        date: new Date(Date.now() + 86400000),
        heure: '10:00',
        lieuDepart: 'Paris',
        lieuArrivee: 'Lyon',
        organisateur: testUser._id,
        visibilite: 'publique',
        participants: [{ userId: testUser._id }]
      });

      await Ride.create({
        titre: 'Balade voiture',
        typeVehicule: 'voiture',
        date: new Date(Date.now() + 86400000),
        heure: '10:00',
        lieuDepart: 'Paris',
        lieuArrivee: 'Lyon',
        organisateur: testUser._id,
        visibilite: 'publique',
        participants: [{ userId: testUser._id }]
      });

      const response = await request(app)
        .get('/api/rides')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ typeVehicule: 'moto' })
        .expect(200);

      expect(response.body.data.rides.every(ride => ride.typeVehicule === 'moto')).toBe(true);
    });
  });

  describe('GET /api/rides/:id', () => {
    it('devrait retourner une balade par ID', async () => {
      const ride = await Ride.create({
        titre: 'Balade test',
        description: 'Description test',
        typeVehicule: 'moto',
        date: new Date(Date.now() + 86400000),
        heure: '10:00',
        lieuDepart: 'Paris',
        lieuArrivee: 'Lyon',
        organisateur: testUser._id,
        visibilite: 'publique',
        participants: [{ userId: testUser._id }],
        status: 'scheduled'
      });

      const response = await request(app)
        .get(`/api/rides/${ride._id}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.ride).toBeDefined();
      expect(response.body.data.ride.titre).toBe('Balade test');
    });

    it('devrait retourner 404 si la balade n\'existe pas', async () => {
      const fakeId = new mongoose.Types.ObjectId();

      await request(app)
        .get(`/api/rides/${fakeId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);
    });
  });

  describe('POST /api/rides', () => {
    it('devrait créer une nouvelle balade', async () => {
      const rideData = {
        titre: 'Nouvelle balade',
        description: 'Description',
        typeVehicule: 'moto',
        date: new Date(Date.now() + 86400000).toISOString(),
        heure: '10:00',
        lieuDepart: 'Paris',
        lieuArrivee: 'Lyon',
        visibilite: 'publique'
      };

      const response = await request(app)
        .post('/api/rides')
        .set('Authorization', `Bearer ${authToken}`)
        .send(rideData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.ride).toBeDefined();
      expect(response.body.data.ride.titre).toBe('Nouvelle balade');
      expect(response.body.data.ride.organisateur).toBeDefined();
    });

    it('devrait refuser une balade avec une date dans le passé', async () => {
      const rideData = {
        titre: 'Balade passée',
        typeVehicule: 'moto',
        date: new Date(Date.now() - 86400000).toISOString(), // Hier
        heure: '10:00',
        lieuDepart: 'Paris',
        lieuArrivee: 'Lyon'
      };

      const response = await request(app)
        .post('/api/rides')
        .set('Authorization', `Bearer ${authToken}`)
        .send(rideData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBeDefined();
    });
  });

  describe('PUT /api/rides/:id', () => {
    it('devrait mettre à jour une balade', async () => {
      const ride = await Ride.create({
        titre: 'Balade originale',
        typeVehicule: 'moto',
        date: new Date(Date.now() + 86400000),
        heure: '10:00',
        lieuDepart: 'Paris',
        lieuArrivee: 'Lyon',
        organisateur: testUser._id,
        visibilite: 'publique',
        participants: [{ userId: testUser._id }],
        status: 'scheduled'
      });

      const response = await request(app)
        .put(`/api/rides/${ride._id}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ titre: 'Balade modifiée' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.ride.titre).toBe('Balade modifiée');
    });

    it('devrait refuser la mise à jour si l\'utilisateur n\'est pas l\'organisateur', async () => {
      // Créer un autre utilisateur
      const otherUser = new User({
        email: 'other@example.com',
        password: 'hashedpassword',
        pseudo: 'otheruser',
        phoneE164: '+33612345679',
        phoneVerified: true,
        status: 'active'
      });
      await otherUser.save();

      const ride = await Ride.create({
        titre: 'Balade d\'un autre',
        typeVehicule: 'moto',
        date: new Date(Date.now() + 86400000),
        heure: '10:00',
        lieuDepart: 'Paris',
        lieuArrivee: 'Lyon',
        organisateur: otherUser._id,
        visibilite: 'publique',
        participants: [{ userId: otherUser._id }],
        status: 'scheduled'
      });

      await request(app)
        .put(`/api/rides/${ride._id}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ titre: 'Tentative de modification' })
        .expect(403);

      await User.deleteOne({ _id: otherUser._id });
    });
  });

  describe('DELETE /api/rides/:id', () => {
    it('devrait supprimer une balade', async () => {
      const ride = await Ride.create({
        titre: 'Balade à supprimer',
        typeVehicule: 'moto',
        date: new Date(Date.now() + 86400000),
        heure: '10:00',
        lieuDepart: 'Paris',
        lieuArrivee: 'Lyon',
        organisateur: testUser._id,
        visibilite: 'publique',
        participants: [{ userId: testUser._id }],
        status: 'scheduled'
      });

      await request(app)
        .delete(`/api/rides/${ride._id}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      // Vérifier que la balade a été supprimée
      const deletedRide = await Ride.findById(ride._id);
      expect(deletedRide).toBeNull();
    });
  });
});

