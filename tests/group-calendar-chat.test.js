const request = require('supertest');
const mongoose = require('mongoose');
const { app } = require('../src/app');
const Group = require('../src/models/Group');
const Ride = require('../src/models/Ride');
const Message = require('../src/models/Message');
const User = require('../src/models/User');
const MessageReport = require('../src/models/MessageReport');
const GroupMute = require('../src/models/GroupMute');
const Notification = require('../src/models/Notification');
const jwt = require('jsonwebtoken');
require('dotenv').config();

describe('Group Calendar & Chat Features', () => {
  let user1, user2, user3;
  let group1;
  let token1, token2, token3;
  let ride1, ride2;

  beforeAll(async () => {
    // Créer des utilisateurs de test
    user1 = await User.create({
      email: 'user1@test.com',
      password: 'password123',
      pseudo: 'user1',
      firstName: 'User',
      lastName: 'One'
    });

    user2 = await User.create({
      email: 'user2@test.com',
      password: 'password123',
      pseudo: 'user2',
      firstName: 'User',
      lastName: 'Two'
    });

    user3 = await User.create({
      email: 'user3@test.com',
      password: 'password123',
      pseudo: 'user3',
      firstName: 'User',
      lastName: 'Three'
    });

    // Générer des tokens
    token1 = jwt.sign({ userId: user1._id }, process.env.JWT_SECRET || 'test-secret');
    token2 = jwt.sign({ userId: user2._id }, process.env.JWT_SECRET || 'test-secret');
    token3 = jwt.sign({ userId: user3._id }, process.env.JWT_SECRET || 'test-secret');

    // Créer un groupe
    group1 = await Group.create({
      nom: 'Test Group',
      description: 'Test Description',
      visibilite: 'publique',
      createur: user1._id,
      membres: [
        { userId: user1._id, role: 'admin' },
        { userId: user2._id, role: 'membre' },
        { userId: user3._id, role: 'membre' }
      ]
    });

    // Créer des balades associées au groupe
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const nextWeek = new Date();
    nextWeek.setDate(nextWeek.getDate() + 7);

    ride1 = await Ride.create({
      titre: 'Test Ride 1',
      date: tomorrow,
      heureDepart: '10:00',
      pointDepart: { nom: 'Paris', lat: 48.8566, lng: 2.3522 },
      pointArrivee: { nom: 'Lyon', lat: 45.7640, lng: 4.8357 },
      organisateur: user1._id,
      visibilite: 'publique',
      groupId: group1._id
    });

    ride2 = await Ride.create({
      titre: 'Test Ride 2',
      date: nextWeek,
      heureDepart: '14:00',
      pointDepart: { nom: 'Lyon', lat: 45.7640, lng: 4.8357 },
      pointArrivee: { nom: 'Marseille', lat: 43.2965, lng: 5.3698 },
      organisateur: user2._id,
      visibilite: 'publique',
      groupId: group1._id
    });
  });

  afterAll(async () => {
    // Nettoyer les données de test
    await User.deleteMany({ email: { $in: ['user1@test.com', 'user2@test.com', 'user3@test.com'] } });
    await Group.deleteMany({ nom: 'Test Group' });
    await Ride.deleteMany({ titre: { $in: ['Test Ride 1', 'Test Ride 2'] } });
    await Message.deleteMany({ idGroupe: group1?._id });
    await MessageReport.deleteMany({ groupId: group1?._id });
    await GroupMute.deleteMany({ groupId: group1?._id });
    await Notification.deleteMany({ user: { $in: [user1?._id, user2?._id, user3?._id] } });
    await mongoose.connection.close();
  });

  describe('Group Calendar', () => {
    test('GET /api/groups/:groupId/rides - should return group rides in date range', async () => {
      const from = new Date();
      from.setDate(from.getDate() - 1);
      const to = new Date();
      to.setDate(to.getDate() + 10);

      const response = await request(app)
        .get(`/api/groups/${group1._id}/rides`)
        .query({ from: from.toISOString(), to: to.toISOString() })
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.items).toHaveLength(2);
      expect(response.body.data.items[0]).toHaveProperty('rideId');
      expect(response.body.data.items[0]).toHaveProperty('title');
    });

    test('GET /api/groups/:groupId/calendar.ics - should return valid ICS file', async () => {
      const from = new Date();
      from.setDate(from.getDate() - 1);
      const to = new Date();
      to.setDate(to.getDate() + 10);

      const response = await request(app)
        .get(`/api/groups/${group1._id}/calendar.ics`)
        .query({ from: from.toISOString(), to: to.toISOString() })
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      expect(response.headers['content-type']).toContain('text/calendar');
      expect(response.text).toContain('BEGIN:VCALENDAR');
      expect(response.text).toContain('BEGIN:VEVENT');
      expect(response.text).toContain('Test Ride 1');
      expect(response.text).toContain('UID:ridetogether-');
    });

    test('GET /api/groups/:groupId/rides - should return 403 for non-member', async () => {
      const nonMember = await User.create({
        email: 'nonmember@test.com',
        password: 'password123',
        pseudo: 'nonmember'
      });
      const nonMemberToken = jwt.sign({ userId: nonMember._id }, process.env.JWT_SECRET || 'test-secret');

      const privateGroup = await Group.create({
        nom: 'Private Group',
        visibilite: 'privee',
        createur: user1._id,
        membres: [{ userId: user1._id, role: 'admin' }]
      });

      await request(app)
        .get(`/api/groups/${privateGroup._id}/rides`)
        .set('Authorization', `Bearer ${nonMemberToken}`)
        .expect(403);

      await User.deleteOne({ _id: nonMember._id });
      await Group.deleteOne({ _id: privateGroup._id });
    });
  });

  describe('Mentions', () => {
    test('GET /api/groups/:groupId/members/suggest - should return member suggestions', async () => {
      const response = await request(app)
        .get(`/api/groups/${group1._id}/members/suggest`)
        .query({ q: 'user' })
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.suggestions).toBeInstanceOf(Array);
      expect(response.body.data.suggestions.length).toBeGreaterThan(0);
      expect(response.body.data.suggestions[0]).toHaveProperty('userId');
      expect(response.body.data.suggestions[0]).toHaveProperty('username');
    });

    test('POST /api/messages - should parse mentions and create notifications', async () => {
      const messageContent = 'Hello @user2 and @user3!';

      const response = await request(app)
        .post('/api/messages')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          conversationId: group1._id,
          type: 'group',
          content: messageContent
        })
        .expect(201);

      expect(response.body.success).toBe(true);
      const message = await Message.findById(response.body.data.message._id);
      expect(message.mentions).toHaveLength(2);

      // Vérifier les notifications
      const notifications = await Notification.find({
        user: { $in: [user2._id, user3._id] },
        type: 'mention'
      });
      expect(notifications.length).toBeGreaterThanOrEqual(2);
    });
  });

  describe('Threads', () => {
    let rootMessage;

    test('POST /api/messages - should create root message', async () => {
      const response = await request(app)
        .post('/api/messages')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          conversationId: group1._id,
          type: 'group',
          content: 'Root message for thread'
        })
        .expect(201);

      rootMessage = await Message.findById(response.body.data.message._id);
      expect(rootMessage.parentMessageId).toBeNull();
      expect(rootMessage.threadReplyCount).toBe(0);
    });

    test('POST /api/messages - should create reply in thread', async () => {
      const response = await request(app)
        .post('/api/messages')
        .set('Authorization', `Bearer ${token2}`)
        .send({
          conversationId: group1._id,
          type: 'group',
          content: 'Reply to root message',
          parentMessageId: rootMessage._id
        })
        .expect(201);

      const reply = await Message.findById(response.body.data.message._id);
      expect(reply.parentMessageId.toString()).toBe(rootMessage._id.toString());
      expect(reply.threadRootId.toString()).toBe(rootMessage._id.toString());

      // Vérifier que threadReplyCount a été incrémenté
      const updatedRoot = await Message.findById(rootMessage._id);
      expect(updatedRoot.threadReplyCount).toBe(1);
    });

    test('GET /api/messages/:messageId/thread - should return thread with replies', async () => {
      const response = await request(app)
        .get(`/api/messages/${rootMessage._id}/thread`)
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.root).toBeDefined();
      expect(response.body.data.replies).toBeInstanceOf(Array);
      expect(response.body.data.replies.length).toBeGreaterThan(0);
    });
  });

  describe('Message Pinning', () => {
    let messageToPin;

    beforeEach(async () => {
      messageToPin = await Message.create({
        auteur: user1._id,
        contenu: 'Message to pin',
        type: 'text',
        idGroupe: group1._id,
        date: new Date()
      });
    });

    test('POST /api/messages/:messageId/pin - should pin message (admin)', async () => {
      const response = await request(app)
        .post(`/api/messages/${messageToPin._id}/pin`)
        .set('Authorization', `Bearer ${token1}`)
        .send({ groupId: group1._id })
        .expect(200);

      expect(response.body.success).toBe(true);
      const updatedMessage = await Message.findById(messageToPin._id);
      expect(updatedMessage.pinned).toBe(true);
      expect(updatedMessage.pinnedBy.toString()).toBe(user1._id.toString());
    });

    test('GET /api/groups/:groupId/messages/pins - should return pinned messages', async () => {
      const response = await request(app)
        .get(`/api/groups/${group1._id}/messages/pins`)
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.messages).toBeInstanceOf(Array);
      const pinnedMessages = response.body.data.messages.filter(m => m.pinned);
      expect(pinnedMessages.length).toBeGreaterThan(0);
    });

    test('POST /api/messages/:messageId/pin - should return 403 for non-moderator', async () => {
      // user2 est membre mais pas modérateur
      await request(app)
        .post(`/api/messages/${messageToPin._id}/pin`)
        .set('Authorization', `Bearer ${token2}`)
        .send({ groupId: group1._id })
        .expect(403);
    });
  });

  describe('Message Search', () => {
    beforeEach(async () => {
      // Créer des messages de test
      await Message.create({
        auteur: user1._id,
        contenu: 'Message with keyword search',
        type: 'text',
        idGroupe: group1._id,
        date: new Date()
      });

      await Message.create({
        auteur: user2._id,
        contenu: 'Another message',
        type: 'text',
        idGroupe: group1._id,
        date: new Date()
      });

      await Message.create({
        auteur: user3._id,
        contenu: 'Poll message',
        type: 'poll',
        pollData: { question: 'Test poll?', options: [] },
        idGroupe: group1._id,
        date: new Date()
      });
    });

    test('GET /api/groups/:groupId/messages/search - should search by text', async () => {
      const response = await request(app)
        .get(`/api/groups/${group1._id}/messages/search`)
        .query({ q: 'keyword' })
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.messages).toBeInstanceOf(Array);
      expect(response.body.data.messages.length).toBeGreaterThan(0);
    });

    test('GET /api/groups/:groupId/messages/search - should filter by poll', async () => {
      const response = await request(app)
        .get(`/api/groups/${group1._id}/messages/search`)
        .query({ poll: 'true' })
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      const pollMessages = response.body.data.messages.filter(m => m.type === 'poll');
      expect(pollMessages.length).toBeGreaterThan(0);
    });
  });

  describe('Message Reporting', () => {
    let messageToReport;

    beforeEach(async () => {
      messageToReport = await Message.create({
        auteur: user2._id,
        contenu: 'Message to report',
        type: 'text',
        idGroupe: group1._id,
        date: new Date()
      });
    });

    test('POST /api/groups/:groupId/messages/:messageId/report - should create report', async () => {
      const response = await request(app)
        .post(`/api/groups/${group1._id}/messages/${messageToReport._id}/report`)
        .set('Authorization', `Bearer ${token1}`)
        .send({
          reasonCode: 'SPAM',
          reasonText: 'This is spam'
        })
        .expect(201);

      expect(response.body.success).toBe(true);
      const report = await MessageReport.findOne({
        messageId: messageToReport._id,
        reporterId: user1._id
      });
      expect(report).toBeDefined();
      expect(report.reasonCode).toBe('SPAM');
      expect(report.status).toBe('open');
    });

    test('POST /api/groups/:groupId/messages/:messageId/report - should not allow duplicate report', async () => {
      await MessageReport.create({
        groupId: group1._id,
        messageId: messageToReport._id,
        reporterId: user1._id,
        reasonCode: 'SPAM',
        status: 'open'
      });

      await request(app)
        .post(`/api/groups/${group1._id}/messages/${messageToReport._id}/report`)
        .set('Authorization', `Bearer ${token1}`)
        .send({
          reasonCode: 'HARASSMENT'
        })
        .expect(400);
    });
  });

  describe('User Muting', () => {
    test('POST /api/groups/:groupId/members/:userId/mute - should mute user (admin)', async () => {
      const response = await request(app)
        .post(`/api/groups/${group1._id}/members/${user2._id}/mute`)
        .set('Authorization', `Bearer ${token1}`)
        .send({
          durationMinutes: 60,
          reason: 'Test mute'
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      const mute = await GroupMute.findOne({
        groupId: group1._id,
        userId: user2._id,
        mutedUntil: { $gt: new Date() }
      });
      expect(mute).toBeDefined();
    });

    test('POST /api/messages - should reject message from muted user', async () => {
      // Muter user2
      await GroupMute.create({
        groupId: group1._id,
        userId: user2._id,
        mutedUntil: new Date(Date.now() + 60 * 60 * 1000), // 1 heure
        createdBy: user1._id
      });

      await request(app)
        .post('/api/messages')
        .set('Authorization', `Bearer ${token2}`)
        .send({
          conversationId: group1._id,
          type: 'group',
          content: 'This should be rejected'
        })
        .expect(403);
    });

    test('POST /api/groups/:groupId/members/:userId/unmute - should unmute user', async () => {
      await request(app)
        .post(`/api/groups/${group1._id}/members/${user2._id}/unmute`)
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      const activeMutes = await GroupMute.find({
        groupId: group1._id,
        userId: user2._id,
        mutedUntil: { $gt: new Date() }
      });
      expect(activeMutes.length).toBe(0);
    });

    test('GET /api/groups/:groupId/mutes - should return muted users (admin only)', async () => {
      await GroupMute.create({
        groupId: group1._id,
        userId: user3._id,
        mutedUntil: new Date(Date.now() + 60 * 60 * 1000),
        createdBy: user1._id
      });

      const response = await request(app)
        .get(`/api/groups/${group1._id}/mutes`)
        .set('Authorization', `Bearer ${token1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.mutes).toBeInstanceOf(Array);

      // Non-admin ne peut pas voir
      await request(app)
        .get(`/api/groups/${group1._id}/mutes`)
        .set('Authorization', `Bearer ${token2}`)
        .expect(403);
    });
  });
});

