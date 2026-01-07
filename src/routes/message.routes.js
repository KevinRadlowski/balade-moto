const express = require('express');
const router = express.Router();
const messageController = require('../controllers/message.controller');
const groupController = require('../controllers/group.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const uploadMessageFile = require('../middlewares/message-upload.middleware');

// Routes pour les messages (nouveau système)
router.get('/:type/:conversationId', authMiddleware, subscriptionMiddleware, messageController.getMessages);
router.post('/', authMiddleware, subscriptionMiddleware, uploadMessageFile, messageController.sendMessage);
router.patch('/:id', authMiddleware, subscriptionMiddleware, messageController.editMessage);
router.delete('/:id', authMiddleware, subscriptionMiddleware, messageController.deleteMessage);
router.post('/:id/restore', authMiddleware, subscriptionMiddleware, messageController.restoreMessage);
router.post('/:id/reactions', authMiddleware, subscriptionMiddleware, messageController.toggleReaction);
router.post('/:id/pin', authMiddleware, subscriptionMiddleware, messageController.togglePin);
router.post('/:id/poll/vote', authMiddleware, subscriptionMiddleware, messageController.votePoll);
router.post('/:type/:conversationId/read', authMiddleware, subscriptionMiddleware, messageController.markAsRead);

// Routes legacy (pour compatibilité)
router.get('/rides/:id', authMiddleware, subscriptionMiddleware, groupController.getRideMessages);

module.exports = router;

