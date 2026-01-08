const Feedback = require('../models/Feedback');
const { BadRequestError, NotFoundError, ForbiddenError } = require('../utils/errors');
const reputationService = require('../services/reputation.service');

/**
 * Créer un feedback
 */
exports.createFeedback = async (req, res, next) => {
  try {
    const { entityType, entityId, type, rating, comment } = req.body;
    const userId = req.user._id;

    // Vérifier qu'un feedback n'existe pas déjà pour cette entité
    const existingFeedback = await Feedback.findOne({
      userId,
      entityType,
      entityId
    });

    if (existingFeedback) {
      throw new BadRequestError('Vous avez déjà donné un feedback pour cette entité');
    }

    // Créer le feedback
    const feedback = new Feedback({
      userId,
      entityType,
      entityId,
      type,
      rating: type === 'rating' || type === 'review' ? rating : null,
      comment: comment || null,
      status: 'approved' // Auto-approuvé pour les feedbacks utilisateurs
    });

    await feedback.save();

    // Mettre à jour la réputation si c'est un feedback sur un utilisateur
    if (entityType === 'user') {
      await reputationService.updateReputationOnFeedback(entityId, feedback);
    }

    res.status(201).json({
      success: true,
      message: 'Feedback créé avec succès',
      data: { feedback }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Récupérer un feedback
 */
exports.getFeedback = async (req, res, next) => {
  try {
    const { id } = req.params;
    const feedback = await Feedback.findById(id)
      .populate('userId', 'firstName lastName pseudo avatarUrl');

    if (!feedback) {
      throw new NotFoundError('Feedback non trouvé');
    }

    res.json({
      success: true,
      data: { feedback }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Mettre à jour un feedback
 */
exports.updateFeedback = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { rating, comment } = req.body;
    const userId = req.user._id;

    const feedback = await Feedback.findById(id);

    if (!feedback) {
      throw new NotFoundError('Feedback non trouvé');
    }

    if (feedback.userId.toString() !== userId.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas autorisé à modifier ce feedback');
    }

    if (rating !== undefined) feedback.rating = rating;
    if (comment !== undefined) feedback.comment = comment;

    await feedback.save();

    // Mettre à jour la réputation si nécessaire
    if (feedback.entityType === 'user') {
      await reputationService.updateReputationOnFeedback(feedback.entityId, feedback);
    }

    res.json({
      success: true,
      message: 'Feedback mis à jour avec succès',
      data: { feedback }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Supprimer un feedback
 */
exports.deleteFeedback = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const feedback = await Feedback.findById(id);

    if (!feedback) {
      throw new NotFoundError('Feedback non trouvé');
    }

    if (feedback.userId.toString() !== userId.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas autorisé à supprimer ce feedback');
    }

    await feedback.deleteOne();

    res.json({
      success: true,
      message: 'Feedback supprimé avec succès'
    });
  } catch (error) {
    next(error);
  }
};







