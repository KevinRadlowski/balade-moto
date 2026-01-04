const Ride = require('../models/Ride');
const User = require('../models/User');

/**
 * Démarre une balade en mode live
 * @param {String} rideId - ID de la balade
 * @param {String} userId - ID de l'utilisateur (organisateur)
 * @returns {Promise<Object>} Balade mise à jour
 */
const startLiveRide = async (rideId, userId) => {
  try {
    const ride = await Ride.findById(rideId);
    if (!ride) {
      throw new Error('Balade non trouvée');
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== userId.toString()) {
      throw new Error('Seul l\'organisateur peut démarrer la balade');
    }

    // Vérifier que la balade est programmée ou en pause (pour reprendre)
    if (ride.status !== 'scheduled' && ride.status !== 'in_progress') {
      // Si la balade est déjà en cours, on ne fait rien (elle est déjà démarrée)
      if (ride.status === 'in_progress') {
        return ride;
      }
      throw new Error('La balade doit être programmée pour être démarrée');
    }

    // Mettre à jour le statut
    ride.status = 'in_progress';

    // Ajouter un événement
    ride.rideEvents.push({
      type: 'started',
      timestamp: new Date(),
      userId: userId,
      details: {}
    });

    await ride.save();

    return ride;
  } catch (error) {
    console.error('Erreur lors du démarrage de la balade:', error);
    throw error;
  }
};

/**
 * Met en pause une balade live
 * @param {String} rideId - ID de la balade
 * @param {String} userId - ID de l'utilisateur
 * @returns {Promise<Object>} Balade mise à jour
 */
const pauseLiveRide = async (rideId, userId) => {
  try {
    const ride = await Ride.findById(rideId);
    if (!ride) {
      throw new Error('Balade non trouvée');
    }

    if (ride.status !== 'in_progress') {
      throw new Error('La balade doit être en cours pour être mise en pause');
    }

    ride.rideEvents.push({
      type: 'paused',
      timestamp: new Date(),
      userId: userId,
      details: {}
    });

    await ride.save();

    return ride;
  } catch (error) {
    console.error('Erreur lors de la mise en pause:', error);
    throw error;
  }
};

/**
 * Reprend une balade en pause
 * @param {String} rideId - ID de la balade
 * @param {String} userId - ID de l'utilisateur
 * @returns {Promise<Object>} Balade mise à jour
 */
const resumeLiveRide = async (rideId, userId) => {
  try {
    const ride = await Ride.findById(rideId);
    if (!ride) {
      throw new Error('Balade non trouvée');
    }

    ride.rideEvents.push({
      type: 'resumed',
      timestamp: new Date(),
      userId: userId,
      details: {}
    });

    await ride.save();

    return ride;
  } catch (error) {
    console.error('Erreur lors de la reprise:', error);
    throw error;
  }
};

/**
 * Termine une balade live
 * @param {String} rideId - ID de la balade
 * @param {String} userId - ID de l'utilisateur
 * @returns {Promise<Object>} Balade mise à jour
 */
const endLiveRide = async (rideId, userId) => {
  try {
    const ride = await Ride.findById(rideId);
    if (!ride) {
      throw new Error('Balade non trouvée');
    }

    if (ride.status !== 'in_progress') {
      throw new Error('La balade doit être en cours pour être terminée');
    }

    ride.status = 'completed';

    ride.rideEvents.push({
      type: 'completed',
      timestamp: new Date(),
      userId: userId,
      details: {}
    });

    await ride.save();

    return ride;
  } catch (error) {
    console.error('Erreur lors de la fin de la balade:', error);
    throw error;
  }
};

/**
 * Signale un incident pendant une balade live
 * @param {String} rideId - ID de la balade
 * @param {String} userId - ID de l'utilisateur
 * @param {Object} details - Détails de l'incident
 * @returns {Promise<Object>} Balade mise à jour
 */
const reportIncident = async (rideId, userId, details) => {
  try {
    const ride = await Ride.findById(rideId);
    if (!ride) {
      throw new Error('Balade non trouvée');
    }

    ride.rideEvents.push({
      type: 'incident',
      timestamp: new Date(),
      userId: userId,
      details: {
        description: details.description,
        location: details.location || null
      }
    });

    await ride.save();

    return ride;
  } catch (error) {
    console.error('Erreur lors du signalement d\'incident:', error);
    throw error;
  }
};

/**
 * Envoie un heartbeat (signal de vie) pour une balade live
 * @param {String} rideId - ID de la balade
 * @param {String} userId - ID de l'utilisateur
 * @param {Object} location - Position GPS
 * @returns {Promise<Object>} Statut de la balade
 */
const sendHeartbeat = async (rideId, userId, location) => {
  try {
    const ride = await Ride.findById(rideId);
    if (!ride) {
      throw new Error('Balade non trouvée');
    }

    // Vérifier que l'utilisateur est participant
    const isParticipant = ride.participants.some(p => p.toString() === userId.toString());
    if (!isParticipant && ride.organisateur.toString() !== userId.toString()) {
      throw new Error('Vous n\'êtes pas participant à cette balade');
    }

    // Le heartbeat n'est pas stocké comme événement, mais peut être utilisé pour tracking
    // En production, on pourrait avoir une collection séparée pour les positions en temps réel

    return {
      rideId: ride._id,
      status: ride.status,
      isActive: ride.status === 'in_progress'
    };
  } catch (error) {
    console.error('Erreur lors de l\'envoi du heartbeat:', error);
    throw error;
  }
};

/**
 * Récupère le statut d'une balade live
 * @param {String} rideId - ID de la balade
 * @returns {Promise<Object>} Statut de la balade
 */
const getLiveRideStatus = async (rideId) => {
  try {
    const ride = await Ride.findById(rideId)
      .populate('organisateur', 'firstName lastName pseudo avatarUrl')
      .populate('participants', 'firstName lastName pseudo avatarUrl');

    if (!ride) {
      throw new Error('Balade non trouvée');
    }

    return {
      rideId: ride._id,
      titre: ride.titre,
      status: ride.status,
      isActive: ride.status === 'in_progress',
      organisateur: ride.organisateur,
      participants: ride.participants,
      lastEvent: ride.rideEvents.length > 0 
        ? ride.rideEvents[ride.rideEvents.length - 1]
        : null
    };
  } catch (error) {
    console.error('Erreur lors de la récupération du statut:', error);
    throw error;
  }
};

module.exports = {
  startLiveRide,
  pauseLiveRide,
  resumeLiveRide,
  endLiveRide,
  reportIncident,
  sendHeartbeat,
  getLiveRideStatus
};

