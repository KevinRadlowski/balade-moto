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

    // Compter les balades (organisateur ou participant)
    const ridesAsOrganizer = await Ride.countDocuments({
      organisateur: userId,
      date: { $lt: new Date() }
    });
    
    const ridesAsParticipant = await Ride.countDocuments({
      'participants.userId': userId,
      date: { $lt: new Date() }
    });
    
    const rideCount = ridesAsOrganizer + ridesAsParticipant;

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
    let score = 0; // Score de base (démarre à 0 pour les nouveaux utilisateurs)

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

    // Calculer le score de ponctualité
    const punctualityScore = await calculatePunctualityScore(userId);

    // Mettre à jour la réputation
    reputation.score = score;
    reputation.rideCount = rideCount;
    reputation.feedbackCount = totalFeedbacks;
    reputation.punctualityScore = punctualityScore;
    reputation.cancellationRate = 0; // TODO: Calculer basé sur historique

    await reputation.save();

    return score;
  } catch (error) {
    console.error('Erreur lors du calcul du score de réputation:', error);
    throw error;
  }
};

/**
 * Calcule le score de ponctualité d'un utilisateur
 * @param {String} userId - ID de l'utilisateur
 * @returns {Promise<Number>} Score de ponctualité (0-100)
 */
const calculatePunctualityScore = async (userId) => {
  try {
    // Récupérer toutes les balades où l'utilisateur était participant
    // Inclure les balades passées ET les balades en cours (même si la date est dans le futur)
    // car la ponctualité peut être validée pendant que la balade est en cours
    const pastRides = await Ride.find({
      'participants.userId': userId,
      $or: [
        { date: { $lt: new Date() } }, // Balades passées
        { status: { $in: ['in_progress', 'completed'] } } // Balades en cours ou terminées
      ]
    }).select('date heure participants status');

    if (pastRides.length === 0) {
      // Pas de balades passées, retourner 50 (neutre)
      return 50;
    }

    let onTimeCount = 0;
    let lateCount = 0;
    let totalValidated = 0;

    for (const ride of pastRides) {
      // Trouver le participant correspondant
      const participant = ride.participants.find(
        p => p.userId && p.userId.toString() === userId.toString()
      );

      if (!participant) continue;

      // Si l'arrivée n'a pas été enregistrée, ignorer cette balade
      if (!participant.arrivalTime) continue;

      // Ne compter que les balades où la ponctualité a été explicitement validée par l'organisateur
      // (isOnTime doit être true ou false, pas null/undefined)
      if (participant.isOnTime === true) {
        onTimeCount++;
        totalValidated++;
      } else if (participant.isOnTime === false) {
        lateCount++;
        totalValidated++;
      }
      // Si isOnTime est null/undefined, ignorer cette balade (pas encore validée)
    }

    // Si aucune balade n'a été validée, retourner 50 (neutre)
    if (totalValidated === 0) {
      return 50;
    }

    // Calculer le pourcentage de ponctualité
    const punctualityPercentage = (onTimeCount / totalValidated) * 100;
    
    // Clamp entre 0 et 100
    return Math.min(Math.max(Math.round(punctualityPercentage), 0), 100);
  } catch (error) {
    console.error('Erreur lors du calcul du score de ponctualité:', error);
    // En cas d'erreur, retourner 50 (neutre)
    return 50;
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
  calculatePunctualityScore,
  updateReputationOnFeedback,
  getReputationLevel,
  getReputation
};







