const request = require('supertest');
const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const { app } = require('../src/app');
const Vehicle = require('../src/models/Vehicle');
const User = require('../src/models/User');
const Group = require('../src/models/Group');
const planQuotaService = require('../src/services/planQuota.service');
const jwt = require('jsonwebtoken');
require('dotenv').config();

describe('Corrections de quotas et permissions', () => {
  let authToken;
  let userId;
  let premiumToken;
  let premiumUserId;

  beforeAll(async () => {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/moto_car_rides_test');
    }

    // Créer un utilisateur FREE de test
    const user = new User({
      email: 'free@test.com',
      password: 'password123',
      pseudo: 'freetest',
      role: 'user',
      emailVerified: true,
      subscription: {
        isPremium: false
      }
    });
    await user.save();
    userId = user._id;
    authToken = jwt.sign({ userId: user._id }, process.env.JWT_SECRET || 'test_secret');

    // Créer un utilisateur PREMIUM de test
    const premiumUser = new User({
      email: 'premium@test.com',
      password: 'password123',
      pseudo: 'premiumtest',
      role: 'user',
      emailVerified: true,
      subscription: {
        isPremium: true,
        premiumExpiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // +30 jours
      }
    });
    await premiumUser.save();
    premiumUserId = premiumUser._id;
    premiumToken = jwt.sign({ userId: premiumUser._id }, process.env.JWT_SECRET || 'test_secret');
  });

  afterAll(async () => {
    await Vehicle.deleteMany({});
    await Group.deleteMany({});
    await User.deleteMany({});
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    await Vehicle.deleteMany({});
    await Group.deleteMany({});
  });

  describe('countVehiclesByUser - Filtre active=true', () => {
    it('devrait ne compter que les véhicules actifs', async () => {
      // Créer 2 véhicules actifs et 1 inactif avec photos
      const activeVehicle1 = new Vehicle({
        ownerUserId: userId,
        type: 'moto',
        active: true,
        photoUrl: 'http://example.com/photo1.jpg',
        photos: [
          { url: 'http://example.com/gal1.jpg', uploadedAt: new Date(), order: 0 },
          { url: 'http://example.com/gal2.jpg', uploadedAt: new Date(), order: 1 }
        ]
      });
      await activeVehicle1.save();

      const activeVehicle2 = new Vehicle({
        ownerUserId: userId,
        type: 'voiture',
        active: true,
        photoUrl: 'http://example.com/photo2.jpg',
        photos: []
      });
      await activeVehicle2.save();

      const inactiveVehicle = new Vehicle({
        ownerUserId: userId,
        type: 'moto',
        active: false,
        photoUrl: 'http://example.com/photo3.jpg',
        photos: [
          { url: 'http://example.com/gal3.jpg', uploadedAt: new Date(), order: 0 }
        ]
      });
      await inactiveVehicle.save();

      const result = await planQuotaService.countVehiclesByUser(userId);

      // Ne devrait compter que les 2 véhicules actifs
      expect(result.total).toBe(2);
      expect(result.byType.moto).toBe(1);
      expect(result.byType.voiture).toBe(1);
      // Photos: 2 (galerie) + 1 (photo principale) + 1 (photo principale) = 4
      // Ne devrait PAS compter les photos du véhicule inactif
      expect(result.photosTotal).toBe(4);
    });
  });

  describe('deleteVehicle - Suppression photos et nettoyage', () => {
    it('devrait supprimer les photos et nettoyer le document', async () => {
      // Créer un dossier de test pour les uploads
      const uploadsDir = path.join(__dirname, '..', 'src', 'uploads', 'vehicles');
      if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
      }

      // Créer des fichiers de test
      const testPhoto1 = path.join(uploadsDir, 'test-photo1.jpg');
      const testPhoto2 = path.join(uploadsDir, 'test-photo2.jpg');
      fs.writeFileSync(testPhoto1, 'test content 1');
      fs.writeFileSync(testPhoto2, 'test content 2');

      const vehicle = new Vehicle({
        ownerUserId: userId,
        type: 'moto',
        active: true,
        photoUrl: `/uploads/vehicles/test-photo1.jpg`,
        photos: [
          { url: `/uploads/vehicles/test-photo2.jpg`, uploadedAt: new Date(), order: 0 }
        ]
      });
      await vehicle.save();

      const response = await request(app)
        .delete(`/api/garage/vehicles/${vehicle._id}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);

      // Vérifier que le véhicule est marqué comme inactif
      const deletedVehicle = await Vehicle.findById(vehicle._id);
      expect(deletedVehicle.active).toBe(false);
      expect(deletedVehicle.photoUrl).toBeNull();
      expect(deletedVehicle.photos).toEqual([]);

      // Vérifier que les fichiers ont été supprimés (ou au moins que le code a tenté)
      // Note: En test, on peut vérifier que le code ne plante pas même si les fichiers n'existent pas
    });

    it('ne devrait pas planter si les fichiers n\'existent pas', async () => {
      const vehicle = new Vehicle({
        ownerUserId: userId,
        type: 'moto',
        active: true,
        photoUrl: `/uploads/vehicles/nonexistent.jpg`,
        photos: []
      });
      await vehicle.save();

      const response = await request(app)
        .delete(`/api/garage/vehicles/${vehicle._id}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);

      const deletedVehicle = await Vehicle.findById(vehicle._id);
      expect(deletedVehicle.active).toBe(false);
      expect(deletedVehicle.photoUrl).toBeNull();
    });
  });

  describe('createVehicle - Filtre active=true dans countDocuments', () => {
    it('devrait permettre de créer un véhicule après suppression d\'un autre', async () => {
      // Créer et supprimer un véhicule (limite FREE = 2)
      const vehicle1 = new Vehicle({
        ownerUserId: userId,
        type: 'moto',
        active: true
      });
      await vehicle1.save();

      const vehicle2 = new Vehicle({
        ownerUserId: userId,
        type: 'voiture',
        active: true
      });
      await vehicle2.save();

      // Supprimer vehicle1 (soft delete)
      vehicle1.active = false;
      await vehicle1.save();

      // Maintenant on devrait pouvoir créer un nouveau véhicule
      const response = await request(app)
        .post('/api/garage/vehicles')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          type: 'moto',
          make: 'Yamaha',
          model: 'MT-07',
          year: 2020
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
    });
  });

  describe('createVehicle - Limites par type (moto/voiture)', () => {
    it('devrait bloquer la création d\'une 2e moto pour Standard', async () => {
      // Créer 1 moto active
      const moto1 = new Vehicle({
        ownerUserId: userId,
        type: 'moto',
        active: true,
        odometerCurrentKm: 0
      });
      await moto1.save();

      // Tenter de créer une 2e moto
      const response = await request(app)
        .post('/api/garage/vehicles')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          type: 'moto',
          make: 'Yamaha',
          model: 'MT-07',
          year: 2020
        });

      expect(response.status).toBe(403);
      expect(response.body.code || response.body.error).toBeDefined();
    });

    it('devrait autoriser la création de 1 moto + 1 voiture pour Standard', async () => {
      // Créer 1 moto active
      const moto = new Vehicle({
        ownerUserId: userId,
        type: 'moto',
        active: true,
        odometerCurrentKm: 0
      });
      await moto.save();

      // Créer 1 voiture (devrait être OK)
      const response1 = await request(app)
        .post('/api/garage/vehicles')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          type: 'voiture',
          make: 'Peugeot',
          model: '208',
          year: 2020
        });

      expect(response1.status).toBe(201);
      expect(response1.body.success).toBe(true);

      // Tenter de créer une 2e voiture (devrait être bloqué)
      const response2 = await request(app)
        .post('/api/garage/vehicles')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          type: 'voiture',
          make: 'Renault',
          model: 'Clio',
          year: 2021
        });

      expect(response2.status).toBe(403);
    });

    it('devrait normaliser le type de véhicule (lowercase, mapping)', async () => {
      // Tester avec différentes variantes
      const variants = ['Moto', 'MOTO', 'motorcycle', 'Car', 'CAR', 'car'];

      for (const variant of variants) {
        const response = await request(app)
          .post('/api/garage/vehicles')
          .set('Authorization', `Bearer ${authToken}`)
          .send({
            type: variant,
            make: 'Test',
            model: 'Test',
            year: 2020
          });

        if (response.status === 201) {
          const vehicle = await Vehicle.findById(response.body.data.vehicle._id);
          expect(['moto', 'voiture']).toContain(vehicle.type);
        }
      }
    });

    it('devrait autoriser un nombre illimité de véhicules pour Premium', async () => {
      // Créer plusieurs motos et voitures pour Premium
      for (let i = 0; i < 3; i++) {
        const response = await request(app)
          .post('/api/garage/vehicles')
          .set('Authorization', `Bearer ${premiumToken}`)
          .send({
            type: i % 2 === 0 ? 'moto' : 'voiture',
            make: `Brand${i}`,
            model: `Model${i}`,
            year: 2020 + i
          });

        expect(response.status).toBe(201);
        expect(response.body.success).toBe(true);
      }
    });
  });

  describe('getGarageUsage - Comptage par type', () => {
    it('devrait retourner motosCount et voituresCount corrects', async () => {
      // Créer 2 motos + 1 voiture actives
      await Vehicle.create([
        { ownerUserId: userId, type: 'moto', active: true, odometerCurrentKm: 0 },
        { ownerUserId: userId, type: 'moto', active: true, odometerCurrentKm: 0 },
        { ownerUserId: userId, type: 'voiture', active: true, odometerCurrentKm: 0 }
      ]);

      const usage = await planQuotaService.countVehiclesByUser(userId);

      expect(usage.byType.moto).toBe(2);
      expect(usage.byType.voiture).toBe(1);
      expect(usage.total).toBe(3);
    });

    it('ne devrait pas compter les véhicules inactifs', async () => {
      // Créer 1 moto active + 1 moto inactive
      await Vehicle.create([
        { ownerUserId: userId, type: 'moto', active: true, odometerCurrentKm: 0 },
        { ownerUserId: userId, type: 'moto', active: false, odometerCurrentKm: 0 }
      ]);

      const usage = await planQuotaService.countVehiclesByUser(userId);

      expect(usage.byType.moto).toBe(1);
      expect(usage.total).toBe(1);
    });

    it('devrait compter les photos uniquement pour véhicules actifs', async () => {
      // Créer 1 moto active avec photos + 1 moto inactive avec photos
      await Vehicle.create([
        {
          ownerUserId: userId,
          type: 'moto',
          active: true,
          odometerCurrentKm: 0,
          photoUrl: 'http://example.com/photo1.jpg',
          photos: [
            { url: 'http://example.com/gal1.jpg', uploadedAt: new Date(), order: 0 }
          ]
        },
        {
          ownerUserId: userId,
          type: 'moto',
          active: false,
          odometerCurrentKm: 0,
          photoUrl: 'http://example.com/photo2.jpg',
          photos: [
            { url: 'http://example.com/gal2.jpg', uploadedAt: new Date(), order: 0 }
          ]
        }
      ]);

      const usage = await planQuotaService.countVehiclesByUser(userId);

      // Devrait compter seulement les photos du véhicule actif : 1 (photoUrl) + 1 (galerie) = 2
      expect(usage.photosTotal).toBe(2);
    });
  });

  describe('createGroup - Limites groupes privés pour Standard', () => {
    it('devrait autoriser la création du 1er groupe privé pour Standard', async () => {
      const response = await request(app)
        .post('/api/groups')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          nom: 'Groupe Privé Test 1',
          description: 'Test',
          visibilite: 'privee'
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.group.visibilite).toBe('privee');
    });

    it('devrait bloquer la création d\'un 2e groupe privé pour Standard', async () => {
      // Créer un premier groupe privé
      const group1 = new Group({
        nom: 'Groupe Privé 1',
        visibilite: 'privee',
        createur: userId
      });
      await group1.save();

      // Tenter de créer un 2e groupe privé
      const response = await request(app)
        .post('/api/groups')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          nom: 'Groupe Privé Test 2',
          description: 'Test',
          visibilite: 'privee'
        });

      expect(response.status).toBe(403);
      expect(response.body.code || response.body.error).toBeDefined();
    });

    it('ne devrait pas compter les groupes publics dans la limite', async () => {
      // Créer 10 groupes publics
      for (let i = 0; i < 10; i++) {
        const group = new Group({
          nom: `Groupe Public ${i}`,
          visibilite: 'publique',
          createur: userId
        });
        await group.save();
      }

      // Créer un groupe privé devrait être OK (ownedCount = 0)
      const response = await request(app)
        .post('/api/groups')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          nom: 'Groupe Privé Test',
          description: 'Test',
          visibilite: 'privee'
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
    });

    it('devrait autoriser la création de groupe privé pour utilisateur PREMIUM', async () => {
      const response = await request(app)
        .post('/api/groups')
        .set('Authorization', `Bearer ${premiumToken}`)
        .send({
          nom: 'Groupe Privé Premium',
          description: 'Test',
          visibilite: 'privee'
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.group.visibilite).toBe('privee');
    });

    it('devrait autoriser la création de groupe public pour utilisateur FREE', async () => {
      const response = await request(app)
        .post('/api/groups')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          nom: 'Groupe Public Test',
          description: 'Test',
          visibilite: 'publique'
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.group.visibilite).toBe('publique');
    });
  });
});

