const request = require('supertest');
const mongoose = require('mongoose');
const { app } = require('../src/app');
const Rating = require('../src/models/Rating');
const Ride = require('../src/models/Ride');
const User = require('../src/models/User');
const jwt = require('jsonwebtoken');
require('dotenv').config();

describe('Système de notation des balades', () => {
  let authToken;
  let userId;
  let rideId;
  let pastRideId;
  let futureRideId;

  beforeAll(async () => {
    // Connexion à MongoDB de test
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides_test');
    }

    // Créer un utilisateur de test
    const user = new User({
      email: 'test@example.com',
      password: 'password123',
      role: 'user',
      emailVerified: true
    });
    await user.save();
    userId = user._id;

    // Générer un token JWT
    authToken = jwt.sign({ userId: user._id }, process.env.JWT_SECRET || 'test_secret');

    // Créer une balade passée (pour les tests de notation)
    const pastDate = new Date();
    pastDate.setDate(pastDate.getDate() - 1); // Hier
    const pastRide = new Ride({
      titre: 'Balade passée',
      description: 'Test',
      typeVehicule: 'moto',
      date: pastDate,
      heure: '10:00',
      lieuDepart: 'Paris',
      lieuArrivee: 'Lyon',
      rayon: 100,
      organisateur: userId,
      participants: [userId],
      visibilite: 'publique'
    });
    await pastRide.save();
    pastRideId = pastRide._id;

    // Créer une balade future (pour tester qu'on ne peut pas noter)
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 1); // Demain
    const futureRide = new Ride({
      titre: 'Balade future',
      description: 'Test',
      typeVehicule: 'moto',
      date: futureDate,
      heure: '10:00',
      lieuDepart: 'Paris',
      lieuArrivee: 'Lyon',
      rayon: 100,
      organisateur: userId,
      participants: [userId],
      visibilite: 'publique'
    });
    await futureRide.save();
    futureRideId = futureRide._id;

    rideId = pastRideId;
  });

  afterAll(async () => {
    // Nettoyer la base de données de test
    await Rating.deleteMany({});
    await Ride.deleteMany({});
    await User.deleteMany({});
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    // Nettoyer les notes avant chaque test
    await Rating.deleteMany({});
  });

  describe('POST /api/ratings', () => {
    test('Devrait créer une note avec succès', async () => {
      const response = await request(app)
        .post('/api/ratings')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          balade: pastRideId.toString(),
          note: 5,
          commentaire: 'Excellente balade !'
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.rating.note).toBe(5);
      expect(response.body.data.rating.commentaire).toBe('Excellente balade !');
      expect(response.body.data.moyenneBalade).toBe(5);
    });

    test('Devrait rejeter une note sans authentification', async () => {
      const response = await request(app)
        .post('/api/ratings')
        .send({
          balade: pastRideId.toString(),
          note: 5
        });

      expect(response.status).toBe(401);
    });

    test('Devrait rejeter une note invalide (hors limites)', async () => {
      const response = await request(app)
        .post('/api/ratings')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          balade: pastRideId.toString(),
          note: 6
        });

      expect(response.status).toBe(400);
      expect(response.body.message).toContain('entre 1 et 5');
    });

    test('Devrait rejeter une note pour une balade future', async () => {
      const response = await request(app)
        .post('/api/ratings')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          balade: futureRideId.toString(),
          note: 5
        });

      expect(response.status).toBe(403);
      expect(response.body.message).toContain('après qu\'elle ait eu lieu');
    });

    test('Devrait empêcher de noter deux fois la même balade', async () => {
      // Première note
      await request(app)
        .post('/api/ratings')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          balade: pastRideId.toString(),
          note: 5
        });

      // Tentative de deuxième note
      const response = await request(app)
        .post('/api/ratings')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          balade: pastRideId.toString(),
          note: 4
        });

      expect(response.status).toBe(409);
      expect(response.body.message).toContain('déjà noté');
    });

    test('Devrait rejeter une note si l\'utilisateur n\'a pas participé', async () => {
      // Créer une balade où l'utilisateur n'est pas participant
      const otherUser = new User({
        email: 'other@example.com',
        password: 'password123',
        role: 'user',
        emailVerified: true
      });
      await otherUser.save();

      const otherRide = new Ride({
        titre: 'Autre balade',
        description: 'Test',
        typeVehicule: 'moto',
        date: new Date(Date.now() - 24 * 60 * 60 * 1000),
        heure: '10:00',
        lieuDepart: 'Paris',
        lieuArrivee: 'Lyon',
        rayon: 100,
        organisateur: otherUser._id,
        participants: [otherUser._id],
        visibilite: 'publique'
      });
      await otherRide.save();

      const response = await request(app)
        .post('/api/ratings')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          balade: otherRide._id.toString(),
          note: 5
        });

      expect(response.status).toBe(403);
      expect(response.body.message).toContain('participé');

      // Nettoyer
      await Ride.findByIdAndDelete(otherRide._id);
      await User.findByIdAndDelete(otherUser._id);
    });
  });

  describe('GET /api/ratings/ride/:rideId', () => {
    test('Devrait récupérer les notes d\'une balade', async () => {
      // Créer quelques notes
      const rating1 = new Rating({
        note: 5,
        commentaire: 'Super !',
        utilisateur: userId,
        balade: pastRideId
      });
      await rating1.save();

      const rating2 = new Rating({
        note: 4,
        commentaire: 'Bien',
        utilisateur: userId,
        balade: pastRideId
      });
      await rating2.save();

      const response = await request(app)
        .get(`/api/ratings/ride/${pastRideId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.ratings.length).toBeGreaterThanOrEqual(2);
      expect(response.body.data.moyenne).toBeGreaterThan(0);
    });

    test('Devrait retourner 404 pour une balade inexistante', async () => {
      const fakeId = new mongoose.Types.ObjectId();
      const response = await request(app)
        .get(`/api/ratings/ride/${fakeId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(404);
    });
  });

  describe('GET /api/ratings/:ratingId', () => {
    test('Devrait récupérer une note spécifique', async () => {
      const rating = new Rating({
        note: 5,
        commentaire: 'Test',
        utilisateur: userId,
        balade: pastRideId
      });
      await rating.save();

      const response = await request(app)
        .get(`/api/ratings/${rating._id}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.rating.note).toBe(5);
    });
  });
});

