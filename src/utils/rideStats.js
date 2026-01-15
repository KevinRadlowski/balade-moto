/**
 * Utilitaires pour enrichir les rides avec des statistiques (likes, participants, ratings)
 * Utilise des requêtes batch pour éviter les N+1
 */

const Like = require('../models/Like');
const Rating = require('../models/Rating');

/**
 * Enrichit une liste de rides avec les statistiques (likes, hasUserLiked)
 * @param {Array} rides - Liste de rides (doivent avoir _id)
 * @param {string} userId - ID de l'utilisateur pour vérifier s'il a liké
 * @returns {Promise<Array>} Rides enrichis avec totalLikes et hasUserLiked
 */
async function enrichRidesWithLikes(rides, userId) {
  if (!rides || rides.length === 0) {
    return rides;
  }
  
  const rideIds = rides.map(ride => ride._id || ride.id);
  
  // Récupérer tous les counts et likes en batch
  const [likesCounts, userLikes] = await Promise.all([
    Like.countLikesByRides(rideIds),
    Like.hasUserLikedRides(rideIds, userId)
  ]);
  
  // Enrichir chaque ride
  return rides.map(ride => {
    const rideId = (ride._id || ride.id).toString();
    return {
      ...ride,
      totalLikes: likesCounts[rideId] || 0,
      hasUserLiked: userLikes[rideId] || false
    };
  });
}

/**
 * Enrichit une liste de rides avec les statistiques de ratings
 * @param {Array} rides - Liste de rides
 * @returns {Promise<Array>} Rides enrichis avec averageRating et ratingsCount
 */
async function enrichRidesWithRatings(rides) {
  if (!rides || rides.length === 0) {
    return rides;
  }
  
  const rideIds = rides.map(ride => ride._id || ride.id);
  
  // Récupérer les moyennes et counts en batch
  const ratingsStats = await Rating.aggregate([
    {
      $match: {
        balade: { $in: rideIds }
      }
    },
    {
      $group: {
        _id: '$balade',
        average: { $avg: '$note' },
        count: { $sum: 1 }
      }
    }
  ]);
  
  // Convertir en Map
  const statsMap = {};
  ratingsStats.forEach(stat => {
    statsMap[stat._id.toString()] = {
      averageRating: Math.round(stat.average * 10) / 10, // Arrondir à 1 décimale
      ratingsCount: stat.count
    };
  });
  
  // Enrichir chaque ride
  return rides.map(ride => {
    const rideId = (ride._id || ride.id).toString();
    const stats = statsMap[rideId] || { averageRating: 0, ratingsCount: 0 };
    return {
      ...ride,
      averageRating: stats.averageRating,
      ratingsCount: stats.ratingsCount
    };
  });
}

/**
 * Enrichit une liste de rides avec toutes les statistiques disponibles
 * @param {Array} rides - Liste de rides
 * @param {string} userId - ID de l'utilisateur
 * @param {object} options - Options { includeRatings: boolean }
 * @returns {Promise<Array>} Rides enrichis
 */
async function enrichRidesWithStats(rides, userId, options = { includeRatings: false }) {
  if (!rides || rides.length === 0) {
    return rides;
  }
  
  let enrichedRides = await enrichRidesWithLikes(rides, userId);
  
  if (options.includeRatings) {
    enrichedRides = await enrichRidesWithRatings(enrichedRides);
  }
  
  return enrichedRides;
}

module.exports = {
  enrichRidesWithLikes,
  enrichRidesWithRatings,
  enrichRidesWithStats
};

