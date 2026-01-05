const User = require('../models/User');
const Vehicle = require('../models/Vehicle');
const Ride = require('../models/Ride');
const Group = require('../models/Group');
const Reputation = require('../models/Reputation');

/**
 * Calcule la compatibilité entre deux utilisateurs pour une balade
 * @param {String} userId1 - ID du premier utilisateur
 * @param {String} userId2 - ID du second utilisateur
 * @param {String} rideId - ID de la balade (optionnel)
 * @returns {Promise<Object>} Objet de compatibilité
 */
const checkCompatibility = async (userId1, userId2, rideId = null) => {
  try {
    // Récupérer les utilisateurs
    const user1 = await User.findById(userId1);
    const user2 = await User.findById(userId2);

    if (!user1 || !user2) {
      throw new Error('Utilisateur non trouvé');
    }

    // Récupérer les véhicules actifs
    const vehicles1 = await Vehicle.find({ ownerUserId: userId1, active: true });
    const vehicles2 = await Vehicle.find({ ownerUserId: userId2, active: true });

    // Récupérer les réputations
    const reputation1 = await Reputation.findOne({ userId: userId1 });
    const reputation2 = await Reputation.findOne({ userId: userId2 });

    // Récupérer les informations de la balade si fournie
    let ride = null;
    if (rideId) {
      ride = await Ride.findById(rideId);
    }

    // Facteurs de compatibilité
    const factors = {
      sameVehicleType: false,
      sameRidingStyle: false,
      reputationMatch: false,
      hasRiddenTogether: false,
      commonGroups: 0
    };

    // 1. Même type de véhicule
    if (ride && vehicles1.length > 0 && vehicles2.length > 0) {
      const vehicle1Type = vehicles1[0].type;
      const vehicle2Type = vehicles2[0].type;
      factors.sameVehicleType = vehicle1Type === vehicle2Type && vehicle1Type === ride.typeVehicule;
    }

    // 2. Même style de conduite (si la balade a un style défini)
    if (ride && ride.ridingStyle) {
      // Pour l'instant, on suppose que tous les utilisateurs ont le même style
      // TODO: Ajouter un champ ridingStyle dans User
      factors.sameRidingStyle = true; // Par défaut
    }

    // 3. Compatibilité de réputation (score similaire)
    if (reputation1 && reputation2) {
      const scoreDiff = Math.abs(reputation1.score - reputation2.score);
      factors.reputationMatch = scoreDiff <= 20; // Différence de moins de 20 points
    }

    // 4. Ont déjà fait des balades ensemble
    const ridesTogether = await Ride.countDocuments({
      $or: [
        { organisateur: userId1, participants: userId2 },
        { organisateur: userId2, participants: userId1 },
        { organisateur: { $in: [userId1, userId2] }, participants: { $in: [userId1, userId2] } }
      ],
      date: { $lt: new Date() }
    });
    factors.hasRiddenTogether = ridesTogether > 0;

    // 5. Groupes en commun
    const groups1 = await Group.find({
      'membres.userId': userId1
    });
    const groups2 = await Group.find({
      'membres.userId': userId2
    });
    
    const groups1Ids = groups1.map(g => g._id.toString());
    const groups2Ids = groups2.map(g => g._id.toString());
    factors.commonGroups = groups1Ids.filter(id => groups2Ids.includes(id)).length;

    // Calculer le score de compatibilité (0-100)
    let score = 0;
    let maxScore = 0;

    // Type de véhicule (30 points)
    maxScore += 30;
    if (factors.sameVehicleType) score += 30;

    // Style de conduite (20 points)
    maxScore += 20;
    if (factors.sameRidingStyle) score += 20;

    // Réputation (20 points)
    maxScore += 20;
    if (factors.reputationMatch) score += 20;

    // Historique commun (20 points)
    maxScore += 20;
    if (factors.hasRiddenTogether) score += 20;

    // Groupes en commun (10 points)
    maxScore += 10;
    score += Math.min(factors.commonGroups * 5, 10);

    // Normaliser le score (0-100)
    const finalScore = maxScore > 0 ? Math.round((score / maxScore) * 100) : 50;

    // Générer une suggestion
    let suggestion = 'compatible';
    if (finalScore < 50) {
      suggestion = 'incompatible';
    } else if (finalScore < 70) {
      suggestion = 'moderate';
    }

    return {
      score: finalScore,
      factors,
      suggestion,
      message: generateCompatibilityMessage(finalScore, factors)
    };
  } catch (error) {
    console.error('Erreur lors du calcul de compatibilité:', error);
    throw error;
  }
};

/**
 * Génère un message de compatibilité
 * @param {Number} score - Score de compatibilité
 * @param {Object} factors - Facteurs de compatibilité
 * @returns {String} Message
 */
const generateCompatibilityMessage = (score, factors) => {
  if (score >= 80) {
    return 'Excellente compatibilité ! Vous devriez bien vous entendre.';
  } else if (score >= 60) {
    return 'Bonne compatibilité. Cette balade devrait bien se passer.';
  } else if (score >= 40) {
    return 'Compatibilité modérée. Quelques différences à noter.';
  } else {
    return 'Compatibilité faible. Certains points d\'attention.';
  }
};

module.exports = {
  checkCompatibility
};



