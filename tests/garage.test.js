const request = require('supertest');
const mongoose = require('mongoose');
const { app } = require('../src/app');
const Vehicle = require('../src/models/Vehicle');
const Odometer = require('../src/models/Odometer');
const Maintenance = require('../src/models/Maintenance');
const MaintenanceLog = require('../src/models/MaintenanceLog');
const User = require('../src/models/User');
const jwt = require('jsonwebtoken');
require('dotenv').config();

describe('Système de Garage', () => {
  let authToken;
  let userId;
  let vehicleId;

  beforeAll(async () => {
    // Connexion à MongoDB de test
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides_test');
    }

    // Créer un utilisateur de test
    const user = new User({
      email: 'garage@test.com',
      password: 'password123',
      pseudo: 'garagetest',
      role: 'user',
      emailVerified: true
    });
    await user.save();
    userId = user._id;

    // Générer un token JWT
    authToken = jwt.sign({ userId: user._id }, process.env.JWT_SECRET || 'test_secret');
  });

  afterAll(async () => {
    // Nettoyer la base de données de test
    await MaintenanceLog.deleteMany({});
    await Maintenance.deleteMany({});
    await Odometer.deleteMany({});
    await Vehicle.deleteMany({});
    await User.deleteMany({});
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    // Nettoyer les données avant chaque test
    await MaintenanceLog.deleteMany({});
    await Maintenance.deleteMany({});
    await Odometer.deleteMany({});
    await Vehicle.deleteMany({});
  });

  describe('POST /api/garage/vehicles', () => {
    test('Devrait créer un véhicule avec succès', async () => {
      const response = await request(app)
        .post('/api/garage/vehicles')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          nom: 'Ma Moto',
          marque: 'Yamaha',
          modele: 'MT-07',
          annee: 2020,
          type: 'moto',
          couleur: 'Noir',
          kilometrageInitial: 5000,
          dateAchat: '2020-01-15',
          description: 'Ma première moto'
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.vehicle.nom).toBe('Ma Moto');
      expect(response.body.data.vehicle.marque).toBe('Yamaha');
      expect(response.body.data.vehicle.kilometrageActuel).toBe(5000);
      
      vehicleId = response.body.data.vehicle._id;
    });

    test('Devrait rejeter la création sans authentification', async () => {
      const response = await request(app)
        .post('/api/garage/vehicles')
        .send({
          nom: 'Ma Moto',
          marque: 'Yamaha',
          modele: 'MT-07',
          annee: 2020,
          type: 'moto',
          kilometrageInitial: 5000,
          dateAchat: '2020-01-15'
        });

      expect(response.status).toBe(401);
    });

    test('Devrait rejeter un véhicule avec des données invalides', async () => {
      const response = await request(app)
        .post('/api/garage/vehicles')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          nom: 'Ma Moto',
          marque: 'Yamaha',
          // modele manquant
          annee: 2020,
          type: 'moto',
          kilometrageInitial: 5000,
          dateAchat: '2020-01-15'
        });

      expect(response.status).toBe(400);
    });
  });

  describe('GET /api/garage/vehicles', () => {
    beforeEach(async () => {
      // Créer quelques véhicules de test
      const vehicle1 = new Vehicle({
        proprietaire: userId,
        nom: 'Moto 1',
        marque: 'Yamaha',
        modele: 'MT-07',
        annee: 2020,
        type: 'moto',
        kilometrageInitial: 5000,
        kilometrageActuel: 5000,
        dateAchat: new Date('2020-01-15')
      });
      await vehicle1.save();

      const vehicle2 = new Vehicle({
        proprietaire: userId,
        nom: 'Voiture 1',
        marque: 'Peugeot',
        modele: '208',
        annee: 2019,
        type: 'voiture',
        kilometrageInitial: 10000,
        kilometrageActuel: 10000,
        dateAchat: new Date('2019-06-01')
      });
      await vehicle2.save();
    });

    test('Devrait récupérer tous les véhicules de l\'utilisateur', async () => {
      const response = await request(app)
        .get('/api/garage/vehicles')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.vehicles.length).toBeGreaterThanOrEqual(2);
      expect(response.body.data.pagination).toBeDefined();
    });

    test('Devrait filtrer par type', async () => {
      const response = await request(app)
        .get('/api/garage/vehicles?type=moto')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.vehicles.every(v => v.type === 'moto')).toBe(true);
    });
  });

  describe('POST /api/garage/vehicles/:vehicleId/odometers', () => {
    beforeEach(async () => {
      const vehicle = new Vehicle({
        proprietaire: userId,
        nom: 'Test Moto',
        marque: 'Yamaha',
        modele: 'MT-07',
        annee: 2020,
        type: 'moto',
        kilometrageInitial: 5000,
        kilometrageActuel: 5000,
        dateAchat: new Date('2020-01-15')
      });
      await vehicle.save();
      vehicleId = vehicle._id;
    });

    test('Devrait créer une entrée de compteur avec succès', async () => {
      const response = await request(app)
        .post(`/api/garage/vehicles/${vehicleId}/odometers`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          kilometrage: 6000,
          notes: 'Kilométrage après voyage'
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.odometer.kilometrage).toBe(6000);

      // Vérifier que le kilométrage du véhicule a été mis à jour
      const vehicle = await Vehicle.findById(vehicleId);
      expect(vehicle.kilometrageActuel).toBe(6000);
    });

    test('Devrait rejeter un kilométrage inférieur au kilométrage actuel', async () => {
      const response = await request(app)
        .post(`/api/garage/vehicles/${vehicleId}/odometers`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          kilometrage: 4000
        });

      expect(response.status).toBe(400);
    });
  });

  describe('POST /api/garage/vehicles/:vehicleId/maintenances', () => {
    beforeEach(async () => {
      const vehicle = new Vehicle({
        proprietaire: userId,
        nom: 'Test Moto',
        marque: 'Yamaha',
        modele: 'MT-07',
        annee: 2020,
        type: 'moto',
        kilometrageInitial: 5000,
        kilometrageActuel: 5000,
        dateAchat: new Date('2020-01-15')
      });
      await vehicle.save();
      vehicleId = vehicle._id;
    });

    test('Devrait créer une maintenance avec succès', async () => {
      const response = await request(app)
        .post(`/api/garage/vehicles/${vehicleId}/maintenances`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          type: 'vidange',
          description: 'Vidange complète',
          kilometrage: 5000,
          cout: 50,
          notes: 'Première vidange'
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.maintenance.type).toBe('vidange');
      expect(response.body.data.maintenance.description).toBe('Vidange complète');

      // Vérifier qu'un log a été créé
      const logs = await MaintenanceLog.find({ vehicule: vehicleId });
      expect(logs.length).toBeGreaterThan(0);
    });
  });

  describe('Ownership checks', () => {
    let otherUserId;
    let otherVehicleId;

    beforeEach(async () => {
      // Créer un autre utilisateur
      const otherUser = new User({
        email: 'other@test.com',
        password: 'password123',
        pseudo: 'othertest',
        role: 'user',
        emailVerified: true
      });
      await otherUser.save();
      otherUserId = otherUser._id;

      // Créer un véhicule pour cet autre utilisateur
      const vehicle = new Vehicle({
        proprietaire: otherUserId,
        nom: 'Autre Moto',
        marque: 'Honda',
        modele: 'CBR',
        annee: 2021,
        type: 'moto',
        kilometrageInitial: 0,
        kilometrageActuel: 0,
        dateAchat: new Date('2021-01-01')
      });
      await vehicle.save();
      otherVehicleId = vehicle._id;
    });

    test('Devrait empêcher l\'accès à un véhicule d\'un autre utilisateur', async () => {
      const response = await request(app)
        .get(`/api/garage/vehicles/${otherVehicleId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(403);
    });

    test('Devrait empêcher la modification d\'un véhicule d\'un autre utilisateur', async () => {
      const response = await request(app)
        .put(`/api/garage/vehicles/${otherVehicleId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          nom: 'Nom modifié'
        });

      expect(response.status).toBe(403);
    });
  });
});





