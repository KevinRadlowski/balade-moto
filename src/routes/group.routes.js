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

module.exports = router;

