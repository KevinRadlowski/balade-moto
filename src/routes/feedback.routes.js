const express = require('express');
const router = express.Router();
const feedbackController = require('../controllers/feedback.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const subscriptionMiddleware = require('../middlewares/subscription.middleware');
const {
  validateCreateFeedback,
  validateUpdateFeedback,
  validateFeedbackId
} = require('../validators/feedback.validator');

// Toutes les routes nécessitent une authentification
router.post('/', authMiddleware, subscriptionMiddleware, validateCreateFeedback, feedbackController.createFeedback);
router.get('/:id', authMiddleware, subscriptionMiddleware, validateFeedbackId, feedbackController.getFeedback);
router.patch('/:id', authMiddleware, subscriptionMiddleware, validateFeedbackId, validateUpdateFeedback, feedbackController.updateFeedback);
router.delete('/:id', authMiddleware, subscriptionMiddleware, validateFeedbackId, feedbackController.deleteFeedback);

module.exports = router;












