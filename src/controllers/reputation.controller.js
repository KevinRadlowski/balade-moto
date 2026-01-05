const reputationService = require('../services/reputation.service');
const achievementService = require('../services/achievement.service');
const { NotFoundError } = require('../utils/errors');

/**
 * Récupérer la réputation d'un utilisateur
 */
exports.getReputation = async (req, res, next) => {
  try {
    const { userId } = req.params;

    const reputation = await reputationService.getReputation(userId);

    if (!reputation) {
      throw new NotFoundError('Réputation non trouvée');
    }

    res.json({
      success: true,
      data: { reputation }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Récupérer les badges d'un utilisateur
 */
exports.getAchievements = async (req, res, next) => {
  try {
    const { userId } = req.params;

    const achievements = await achievementService.getUserAchievements(userId);

    res.json({
      success: true,
      data: { achievements }
    });
  } catch (error) {
    next(error);
  }
};




