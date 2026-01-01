const express = require('express');
const router = express.Router();
const messageController = require('../controllers/message.controller');
const groupController = require('../controllers/group.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const uploadMessageFile = require('../middlewares/message-upload.middleware');

// Routes pour les messages (nouveau système)
router.get('/:type/:conversationId', authMiddleware, messageController.getMessages);
router.post('/', authMiddleware, uploadMessageFile, messageController.sendMessage);
router.patch('/:id', authMiddleware, messageController.editMessage);
router.delete('/:id', authMiddleware, messageController.deleteMessage);
router.post('/:id/restore', authMiddleware, messageController.restoreMessage);
router.post('/:id/reactions', authMiddleware, messageController.toggleReaction);
router.post('/:id/pin', authMiddleware, messageController.togglePin);
router.post('/:id/poll/vote', authMiddleware, messageController.votePoll);
router.post('/:type/:conversationId/read', authMiddleware, messageController.markAsRead);

// Routes legacy (pour compatibilité)
router.get('/rides/:id', authMiddleware, groupController.getRideMessages);

module.exports = router;

