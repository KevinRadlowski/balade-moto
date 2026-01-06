const express = require('express');
const router = express.Router();
const feedbackController = require('../controllers/feedback.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const {
  validateCreateFeedback,
  validateUpdateFeedback,
  validateFeedbackId
} = require('../validators/feedback.validator');

// Toutes les routes nécessitent une authentification
router.post('/', authMiddleware, validateCreateFeedback, feedbackController.createFeedback);
router.get('/:id', authMiddleware, validateFeedbackId, feedbackController.getFeedback);
router.patch('/:id', authMiddleware, validateFeedbackId, validateUpdateFeedback, feedbackController.updateFeedback);
router.delete('/:id', authMiddleware, validateFeedbackId, feedbackController.deleteFeedback);

module.exports = router;






