const express = require('express');
const router = express.Router();
const groupController = require('../controllers/group.controller');
const authMiddleware = require('../middlewares/auth.middleware');

// Toutes les routes nécessitent une authentification JWT
router.post('/', authMiddleware, groupController.createGroup);
router.get('/', authMiddleware, groupController.getGroups);
router.get('/:id', authMiddleware, groupController.getGroupById);
router.put('/:id', authMiddleware, groupController.updateGroup);
router.delete('/:id', authMiddleware, groupController.deleteGroup);
router.post('/:id/join', authMiddleware, groupController.joinGroup);
router.post('/:id/members', authMiddleware, groupController.addMember);
router.delete('/:id/members/:userId', authMiddleware, groupController.removeMember);
router.put('/:id/members/:userId/role', authMiddleware, groupController.updateMemberRole);
router.post('/:id/ban/:userId', authMiddleware, groupController.banUser);
router.delete('/:id/ban/:userId', authMiddleware, groupController.unbanUser);
router.get('/:id/messages', authMiddleware, groupController.getGroupMessages);

module.exports = router;

