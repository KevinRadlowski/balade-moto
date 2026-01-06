/**
 * Tests pour le soft delete et les claims (claim-organizer, claim-admin)
 * 
 * Ces tests vérifient :
 * - Le soft delete d'un utilisateur (anonymisation, isDeleted=true)
 * - La reprise d'organisation d'une balade si l'organisateur est supprimé
 * - La reprise d'administration d'un groupe si le créateur est supprimé ou s'il n'y a plus d'admin actif
 * - La gestion des cas de concurrence
 */

const mongoose = require('mongoose');
const User = require('../src/models/User');
const Ride = require('../src/models/Ride');
const Group = require('../src/models/Group');
const request = require('supertest');
const app = require('../src/app');
const jwt = require('jsonwebtoken');

// Helper pour créer un token JWT
function createToken(userId, role = 'MEMBER') {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET || 'test-secret', { expiresIn: '1h' });
}

describe('Soft Delete et Claims', () => {
  let user1, user2, user3;
  let ride1, group1;
  let token1, token2, token3;

  beforeAll(async () => {
    // Connexion à MongoDB de test
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/balades-moto-test', {
        useNewUrlParser: true,
        useUnifiedTopology: true
      });
    }

    // Nettoyer la base de données
    await User.deleteMany({});
    await Ride.deleteMany({});
    await Group.deleteMany({});
  });

  beforeEach(async () => {
    // Créer des utilisateurs de test
    user1 = new User({
      email: 'user1@test.com',
      password: 'password123',
      pseudo: 'user1',
      phoneE164: '+33612345678',
      phoneVerified: true,
      status: 'active',
      role: 'MEMBER'
    });
    await user1.save();
    token1 = createToken(user1._id, user1.role);

    user2 = new User({
      email: 'user2@test.com',
      password: 'password123',
      pseudo: 'user2',
      phoneE164: '+33612345679',
      phoneVerified: true,
      status: 'active',
      role: 'MEMBER'
    });
    await user2.save();
    token2 = createToken(user2._id, user2.role);

    user3 = new User({
      email: 'user3@test.com',
      password: 'password123',
      pseudo: 'user3',
      phoneE164: '+33612345680',
      phoneVerified: true,
      status: 'active',
      role: 'MEMBER'
    });
    await user3.save();
    token3 = createToken(user3._id, user3.role);

    // Créer une balade avec user1 comme organisateur
    ride1 = new Ride({
      titre: 'Test Ride',
      description: 'Test Description',
      typeVehicule: 'moto',
      date: new Date(Date.now() + 86400000), // Demain
      heure: '10:00',
      lieuDepart: 'Paris',
      lieuArrivee: 'Lyon',
      organisateur: user1._id,
      participants: [{ userId: user1._id }, { userId: user2._id }],
      visibilite: 'publique',
      status: 'scheduled'
    });
    await ride1.save();

    // Créer un groupe avec user1 comme créateur
    group1 = new Group({
      nom: 'Test Group',
      description: 'Test Description',
      createur: user1._id,
      membres: [
        { userId: user1._id, role: 'admin' },
        { userId: user2._id, role: 'membre' },
        { userId: user3._id, role: 'membre' }
      ],
      visibilite: 'publique'
    });
    await group1.save();
  });

  afterEach(async () => {
    // Nettoyer après chaque test
    await User.deleteMany({});
    await Ride.deleteMany({});
    await Group.deleteMany({});
  });

  afterAll(async () => {
    await mongoose.connection.close();
  });

  describe('Soft Delete', () => {
    test('devrait marquer un utilisateur comme supprimé et anonymiser ses données', async () => {
      const response = await request(app)
        .delete('/api/user/delete-account')
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      expect(response.body.success).toBe(true);

      // Vérifier que l'utilisateur est marqué comme supprimé
      const deletedUser = await User.findById(user1._id);
      expect(deletedUser.isDeleted).toBe(true);
      expect(deletedUser.deletedAt).toBeTruthy();
      expect(deletedUser.anonymizedAt).toBeTruthy();
      expect(deletedUser.email).toContain('deleted+');
      expect(deletedUser.email).toContain('@invalid.local');
      expect(deletedUser.pseudo).toBe('Utilisateur supprimé');
      expect(deletedUser.firstName).toBeNull();
      expect(deletedUser.lastName).toBeNull();
      expect(deletedUser.phoneE164).toBeNull();
      expect(deletedUser.avatarUrl).toBeNull();
      expect(deletedUser.refreshToken).toBeNull();
    });

    test('devrait bloquer l\'accès d\'un utilisateur supprimé', async () => {
      // Supprimer user1
      user1.isDeleted = true;
      user1.deletedAt = new Date();
      await user1.save();

      // Tenter de se connecter
      const response = await request(app)
        .get('/api/user/me')
        .set('Authorization', `Bearer ${token1}`)
        .expect(403);

      expect(response.body.success).toBe(false);
      expect(response.body.deleted).toBe(true);
    });

    test('devrait conserver les balades et groupes après suppression', async () => {
      // Supprimer user1
      await request(app)
        .delete('/api/user/delete-account')
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      // Vérifier que la balade existe toujours
      const ride = await Ride.findById(ride1._id);
      expect(ride).toBeTruthy();
      expect(ride.organisateur.toString()).toBe(user1._id.toString());

      // Vérifier que le groupe existe toujours
      const group = await Group.findById(group1._id);
      expect(group).toBeTruthy();
      expect(group.createur.toString()).toBe(user1._id.toString());
    });
  });

  describe('Claim Organizer', () => {
    test('devrait permettre à un participant de reprendre l\'organisation si l\'organisateur est supprimé', async () => {
      // Supprimer user1 (organisateur)
      user1.isDeleted = true;
      user1.deletedAt = new Date();
      await user1.save();

      // user2 (participant) reprend l'organisation
      const response = await request(app)
        .post(`/api/rides/${ride1._id}/claim-organizer`)
        .set('Authorization', `Bearer ${token2}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toContain('repris l\'organisation');

      // Vérifier que user2 est maintenant l'organisateur
      const updatedRide = await Ride.findById(ride1._id);
      expect(updatedRide.organisateur.toString()).toBe(user2._id.toString());
    });

    test('ne devrait pas permettre la reprise si l\'organisateur est toujours actif', async () => {
      const response = await request(app)
        .post(`/api/rides/${ride1._id}/claim-organizer`)
        .set('Authorization', `Bearer ${token2}`)
        .expect(409);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('toujours actif');
    });

    test('ne devrait pas permettre la reprise si l\'utilisateur n\'est pas participant', async () => {
      // Supprimer user1
      user1.isDeleted = true;
      user1.deletedAt = new Date();
      await user1.save();

      // user3 n'est pas participant
      const response = await request(app)
        .post(`/api/rides/${ride1._id}/claim-organizer`)
        .set('Authorization', `Bearer ${token3}`)
        .expect(403);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('participant');
    });
  });

  describe('Claim Admin', () => {
    test('devrait permettre à un membre de reprendre l\'administration si le créateur est supprimé', async () => {
      // Supprimer user1 (créateur)
      user1.isDeleted = true;
      user1.deletedAt = new Date();
      await user1.save();

      // user2 (membre) reprend l'administration
      const response = await request(app)
        .post(`/api/groups/${group1._id}/claim-admin`)
        .set('Authorization', `Bearer ${token2}`)
        .expect(200);

      expect(response.body.success).toBe(true);

      // Vérifier que user2 est maintenant admin et créateur
      const updatedGroup = await Group.findById(group1._id);
      expect(updatedGroup.createur.toString()).toBe(user2._id.toString());
      
      const user2Member = updatedGroup.membres.find(m => m.userId.toString() === user2._id.toString());
      expect(user2Member.role).toBe('admin');
    });

    test('ne devrait pas permettre la reprise s\'il existe encore un admin actif', async () => {
      // user1 est toujours actif et admin
      const response = await request(app)
        .post(`/api/groups/${group1._id}/claim-admin`)
        .set('Authorization', `Bearer ${token2}`)
        .expect(409);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('administrateurs actifs');
    });

    test('ne devrait pas permettre la reprise si l\'utilisateur n\'est pas membre', async () => {
      // Créer un utilisateur non membre
      const user4 = new User({
        email: 'user4@test.com',
        password: 'password123',
        pseudo: 'user4',
        phoneE164: '+33612345681',
        phoneVerified: true,
        status: 'active',
        role: 'MEMBER'
      });
      await user4.save();
      const token4 = createToken(user4._id, user4.role);

      // Supprimer user1
      user1.isDeleted = true;
      user1.deletedAt = new Date();
      await user1.save();

      // user4 n'est pas membre
      const response = await request(app)
        .post(`/api/groups/${group1._id}/claim-admin`)
        .set('Authorization', `Bearer ${token4}`)
        .expect(403);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('membre');
    });
  });

  describe('Normalisation des organisateurs/créateurs supprimés', () => {
    test('devrait normaliser l\'organisateur supprimé dans getRideById', async () => {
      // Supprimer user1
      user1.isDeleted = true;
      user1.deletedAt = new Date();
      await user1.save();

      const response = await request(app)
        .get(`/api/rides/${ride1._id}`)
        .set('Authorization', `Bearer ${token2}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.ride.organisateur.pseudo).toBe('Utilisateur supprimé');
      expect(response.body.data.ride.organisateur.isDeleted).toBe(true);
    });

    test('devrait normaliser le créateur supprimé dans getGroupById', async () => {
      // Supprimer user1
      user1.isDeleted = true;
      user1.deletedAt = new Date();
      await user1.save();

      const response = await request(app)
        .get(`/api/groups/${group1._id}`)
        .set('Authorization', `Bearer ${token2}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.group.createur.pseudo).toBe('Utilisateur supprimé');
      expect(response.body.data.group.createur.isDeleted).toBe(true);
    });
  });
});
