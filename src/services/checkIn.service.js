const User = require('../models/User');
const emailService = require('./email.service');

/**
 * Envoie un heartbeat (signal de vie) pour un utilisateur
 * @param {String} userId - ID de l'utilisateur
 * @param {Object} location - Position GPS (optionnel)
 * @returns {Promise<Object>} Statut de check-in
 */
const sendHeartbeat = async (userId, location = null) => {
  try {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('Utilisateur non trouvé');
    }

    // Mettre à jour le statut de check-in
    user.checkInStatus.lastHeartbeat = new Date();
    user.checkInStatus.isActive = true;

    if (location && location.latitude && location.longitude) {
      user.checkInStatus.lastLocation = {
        type: 'Point',
        coordinates: [location.longitude, location.latitude]
      };
    }

    await user.save();

    return {
      userId: user._id,
      isActive: true,
      lastHeartbeat: user.checkInStatus.lastHeartbeat,
      lastLocation: user.checkInStatus.lastLocation
    };
  } catch (error) {
    console.error('Erreur lors de l\'envoi du heartbeat:', error);
    throw error;
  }
};

/**
 * Vérifie l'inactivité des utilisateurs et envoie des alertes
 * @returns {Promise<Number>} Nombre d'alertes envoyées
 */
const checkInactivity = async () => {
  try {
    const now = new Date();
    const inactivityThreshold = 30 * 60 * 1000; // 30 minutes

    // Trouver les utilisateurs actifs sans heartbeat récent
    const inactiveUsers = await User.find({
      'checkInStatus.isActive': true,
      $or: [
        { 'checkInStatus.lastHeartbeat': { $lt: new Date(now.getTime() - inactivityThreshold) } },
        { 'checkInStatus.lastHeartbeat': null }
      ]
    });

    let alertsSent = 0;

    for (const user of inactiveUsers) {
      try {
        // Vérifier si l'utilisateur a un contact d'urgence
        if (user.emergencyContact && user.emergencyContact.phone) {
          // Envoyer une alerte au contact d'urgence
          // Note: Pour l'instant, on envoie un email. En production, on pourrait aussi envoyer un SMS
          if (user.emergencyContact.phone.includes('@')) {
            // C'est un email
            await emailService.sendInactivityAlertEmail(
              user.emergencyContact.phone,
              user
            );
          }

          alertsSent++;
        }

        // Marquer l'utilisateur comme inactif
        user.checkInStatus.isActive = false;
        await user.save();
      } catch (error) {
        console.error(`Erreur lors de l'envoi de l'alerte pour ${user._id}:`, error);
      }
    }

    return alertsSent;
  } catch (error) {
    console.error('Erreur lors de la vérification d\'inactivité:', error);
    throw error;
  }
};

/**
 * Récupère le statut de check-in d'un utilisateur
 * @param {String} userId - ID de l'utilisateur
 * @returns {Promise<Object>} Statut de check-in
 */
const getCheckInStatus = async (userId) => {
  try {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('Utilisateur non trouvé');
    }

    return {
      userId: user._id,
      isActive: user.checkInStatus?.isActive || false,
      lastHeartbeat: user.checkInStatus?.lastHeartbeat || null,
      lastLocation: user.checkInStatus?.lastLocation || null
    };
  } catch (error) {
    console.error('Erreur lors de la récupération du statut:', error);
    throw error;
  }
};

module.exports = {
  sendHeartbeat,
  checkInactivity,
  getCheckInStatus
};





