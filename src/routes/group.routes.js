const express = require('express');
const router = express.Router();
const groupController = require('../controllers/group.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');

// Toutes les routes nécessitent une authentification JWT
router.post('/', authMiddleware, subscriptionMiddleware, groupController.createGroup);
router.get('/', authMiddleware, subscriptionMiddleware, groupController.getGroups);
router.get('/:id', authMiddleware, subscriptionMiddleware, groupController.getGroupById);
router.put('/:id', authMiddleware, subscriptionMiddleware, groupController.updateGroup);
router.delete('/:id', authMiddleware, subscriptionMiddleware, groupController.deleteGroup);
router.post('/:id/join', authMiddleware, subscriptionMiddleware, groupController.joinGroup);
router.post('/:id/members', authMiddleware, subscriptionMiddleware, groupController.addMember);
router.delete('/:id/members/:userId', authMiddleware, subscriptionMiddleware, groupController.removeMember);
router.put('/:id/members/:userId/role', authMiddleware, subscriptionMiddleware, groupController.updateMemberRole);
router.post('/:id/ban/:userId', authMiddleware, subscriptionMiddleware, groupController.banUser);
router.delete('/:id/ban/:userId', authMiddleware, subscriptionMiddleware, groupController.unbanUser);
router.get('/:id/messages', authMiddleware, subscriptionMiddleware, groupController.getGroupMessages);
router.post('/:id/claim-admin', authMiddleware, subscriptionMiddleware, groupController.claimAdmin);
router.post('/:id/favorite', authMiddleware, subscriptionMiddleware, groupController.toggleFavorite);

// ========== GROUP CALENDAR ROUTES ==========
// Liste des balades d'un groupe (calendrier)
router.get('/:id/rides', authMiddleware, subscriptionMiddleware, groupController.getGroupRides);
// Export ICS du calendrier
router.get('/:id/calendar.ics', authMiddleware, subscriptionMiddleware, groupController.exportGroupCalendar);

// ========== MENTIONS ROUTES ==========
// Suggestions d'utilisateurs pour les mentions @pseudo
router.get('/:id/members/suggest', authMiddleware, subscriptionMiddleware, groupController.suggestMembers);

// ========== PINNED MESSAGES ROUTES ==========
// Liste des messages épinglés d'un groupe
const messageController = require('../controllers/message.controller');
router.get('/:groupId/messages/pins', authMiddleware, subscriptionMiddleware, messageController.getPinnedMessages);

// ========== SEARCH MESSAGES ROUTES ==========
// Recherche avancée de messages dans un groupe
router.get('/:groupId/messages/search', authMiddleware, subscriptionMiddleware, messageController.searchMessages);

// ========== MODERATION ROUTES ==========
// Signaler un message
router.post('/:groupId/messages/:messageId/report', authMiddleware, subscriptionMiddleware, messageController.reportMessage);
// Muter un utilisateur
router.post('/:groupId/members/:userId/mute', authMiddleware, subscriptionMiddleware, groupController.muteUser);
// Démuter un utilisateur
router.post('/:groupId/members/:userId/unmute', authMiddleware, subscriptionMiddleware, groupController.unmuteUser);
// Liste des utilisateurs mutés (mods only)
router.get('/:groupId/mutes', authMiddleware, subscriptionMiddleware, groupController.getMutedUsers);

module.exports = router;

