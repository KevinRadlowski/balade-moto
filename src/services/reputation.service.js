const Reputation = require('../models/Reputation');
const Feedback = require('../models/Feedback');
const Ride = require('../models/Ride');
const Rating = require('../models/Rating');

/**
 * Calcule le score de réputation d'un utilisateur
 * @param {String} userId - ID de l'utilisateur
 * @returns {Promise<Number>} Score de réputation (0-100)
 */
const calculateReputationScore = async (userId) => {
  try {
    // Récupérer ou créer la réputation
    let reputation = await Reputation.findOne({ userId });
    if (!reputation) {
      reputation = new Reputation({ userId });
    }

    // Compter les balades
    const rideCount = await Ride.countDocuments({
      $or: [
        { organisateur: userId },
        { participants: userId }
      ],
      date: { $lt: new Date() }
    });

    // Calculer la note moyenne
    const ratings = await Rating.find({ utilisateur: userId });
    const avgRating = ratings.length > 0
      ? ratings.reduce((sum, r) => sum + r.note, 0) / ratings.length
      : 0;

    // Compter les feedbacks positifs
    const feedbacks = await Feedback.find({
      entityType: 'user',
      entityId: userId,
      status: 'approved'
    });
    const positiveFeedbacks = feedbacks.filter(f => f.rating >= 4).length;
    const totalFeedbacks = feedbacks.length;

    // Calculer le score (formule simple)
    let score = 50; // Score de base

    // Bonus pour nombre de balades (max +30)
    if (rideCount > 0) {
      score += Math.min(rideCount * 2, 30);
    }

    // Bonus pour notes moyennes (max +20)
    if (avgRating >= 4.5) {
      score += 20;
    } else if (avgRating >= 4.0) {
      score += 15;
    } else if (avgRating >= 3.5) {
      score += 10;
    } else if (avgRating >= 3.0) {
      score += 5;
    }

    // Bonus pour feedbacks positifs (max +10)
    if (totalFeedbacks > 0) {
      const positiveRatio = positiveFeedbacks / totalFeedbacks;
      score += Math.round(positiveRatio * 10);
    }

    // Clamp entre 0 et 100
    score = Math.min(Math.max(score, 0), 100);

    // Mettre à jour la réputation
    reputation.score = score;
    reputation.rideCount = rideCount;
    reputation.feedbackCount = totalFeedbacks;
    reputation.punctualityScore = 50; // TODO: Calculer basé sur historique
    reputation.cancellationRate = 0; // TODO: Calculer basé sur historique

    await reputation.save();

    return score;
  } catch (error) {
    console.error('Erreur lors du calcul du score de réputation:', error);
    throw error;
  }
};

/**
 * Met à jour la réputation après un feedback
 * @param {String} userId - ID de l'utilisateur
 * @param {Object} feedback - Objet feedback
 */
const updateReputationOnFeedback = async (userId, feedback) => {
  try {
    // Recalculer le score
    await calculateReputationScore(userId);
  } catch (error) {
    console.error('Erreur lors de la mise à jour de la réputation:', error);
    throw error;
  }
};

/**
 * Retourne le niveau de réputation basé sur le score
 * @param {Number} score - Score de réputation (0-100)
 * @returns {String} Niveau (bronze, silver, gold, platinum)
 */
const getReputationLevel = (score) => {
  if (score >= 90) return 'platinum';
  if (score >= 75) return 'gold';
  if (score >= 60) return 'silver';
  return 'bronze';
};

/**
 * Récupère la réputation d'un utilisateur
 * @param {String} userId - ID de l'utilisateur
 * @returns {Promise<Object>} Objet réputation
 */
const getReputation = async (userId) => {
  try {
    let reputation = await Reputation.findOne({ userId });
    
    if (!reputation) {
      // Créer une réputation initiale
      const score = await calculateReputationScore(userId);
      reputation = await Reputation.findOne({ userId });
    }

    return reputation;
  } catch (error) {
    console.error('Erreur lors de la récupération de la réputation:', error);
    throw error;
  }
};

module.exports = {
  calculateReputationScore,
  updateReputationOnFeedback,
  getReputationLevel,
  getReputation
};

