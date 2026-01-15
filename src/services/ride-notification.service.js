/**
 * Service unifié pour les notifications de balades (annulation, report, reprogrammation)
 * Envoie des notifications in-app, push (stub) et email (fallback)
 */

const Notification = require('../models/Notification');
const User = require('../models/User');
const emailService = require('./email.service');

/**
 * Récupère tous les participants d'une balade (participants + intéressés + late + weather_ok)
 * @param {object} ride - La balade
 * @returns {Promise<Array>} Liste des IDs d'utilisateurs à notifier
 */
async function getRideParticipants(ride) {
  const participantIds = new Set();

  // Participants confirmés
  if (ride.participants && Array.isArray(ride.participants)) {
    ride.participants.forEach(p => {
      if (p.userId) {
        participantIds.add(p.userId.toString());
      }
    });
  }

  // Invitations acceptées
  if (ride.invitations && Array.isArray(ride.invitations)) {
    ride.invitations
      .filter(inv => inv.status === 'accepted')
      .forEach(inv => {
        if (inv.userId) {
          participantIds.add(inv.userId.toString());
        }
      });
  }

  // TODO: Ajouter les RSVP "interested", "late", "weather_ok" quand la PHASE 4 sera implémentée
  // Pour l'instant, on notifie seulement les participants confirmés

  return Array.from(participantIds);
}

/**
 * Envoie une notification in-app
 * @param {string} userId - ID de l'utilisateur
 * @param {string} type - Type de notification
 * @param {string} title - Titre
 * @param {string} message - Message
 * @param {object} metadata - Métadonnées (rideId, etc.)
 * @returns {Promise<object>} La notification créée
 */
async function sendInAppNotification(userId, type, title, message, metadata = {}) {
  try {
    const notification = new Notification({
      user: userId,
      type,
      title,
      message,
      metadata,
      read: false
    });
    await notification.save();
    return notification;
  } catch (error) {
    console.error(`Erreur lors de la création de la notification in-app pour ${userId}:`, error);
    return null;
  }
}

/**
 * Envoie une notification push (stub pour l'instant)
 * @param {string} userId - ID de l'utilisateur
 * @param {string} title - Titre
 * @param {string} message - Message
 * @param {object} data - Données supplémentaires
 * @returns {Promise<boolean>} Succès ou échec
 */
async function sendPushNotification(userId, title, message, data = {}) {
  // TODO: Implémenter FCM ou autre service push
  // Pour l'instant, c'est un stub
  console.log(`[PUSH STUB] Notification push pour ${userId}: ${title} - ${message}`);
  return true;
}

/**
 * Envoie un email de notification (fallback)
 * @param {string} userId - ID de l'utilisateur
 * @param {Function} emailFunction - Fonction d'envoi d'email (ex: emailService.sendRideCancellationEmail)
 * @param {Array} emailArgs - Arguments pour la fonction d'email
 * @returns {Promise<boolean>} Succès ou échec
 */
async function sendEmailNotification(userId, emailFunction, emailArgs) {
  try {
    const user = await User.findById(userId);
    if (!user || !user.email) {
      return false;
    }

    const userName = user.firstName 
      ? `${user.firstName} ${user.lastName || ''}`.trim()
      : user.email;

    // Appeler la fonction d'email avec les arguments
    await emailFunction(user.email, ...emailArgs, userName);
    return true;
  } catch (error) {
    console.error(`Erreur lors de l'envoi de l'email pour ${userId}:`, error);
    return false;
  }
}

/**
 * Notifie tous les participants d'une balade
 * @param {object} ride - La balade
 * @param {string} type - Type de notification ('cancellation', 'postponement', 'reschedule')
 * @param {string} title - Titre de la notification
 * @param {string} message - Message de la notification
 * @param {Function} emailFunction - Fonction d'envoi d'email
 * @param {Array} emailArgs - Arguments pour la fonction d'email
 * @param {object} metadata - Métadonnées pour la notification in-app
 * @returns {Promise<object>} Résultat des notifications
 */
async function notifyRideParticipants(ride, type, title, message, emailFunction, emailArgs = [], metadata = {}) {
  const participantIds = await getRideParticipants(ride);
  const results = {
    inApp: 0,
    push: 0,
    email: 0,
    errors: []
  };

  for (const userId of participantIds) {
    try {
      // Notification in-app
      const inAppNotif = await sendInAppNotification(userId, type, title, message, {
        ...metadata,
        rideId: ride._id.toString()
      });
      if (inAppNotif) {
        results.inApp++;
      }

      // Notification push
      const pushSent = await sendPushNotification(userId, title, message, {
        ...metadata,
        rideId: ride._id.toString()
      });
      if (pushSent) {
        results.push++;
      }

      // Email (fallback si push non disponible ou selon préférences)
      const emailSent = await sendEmailNotification(userId, emailFunction, emailArgs);
      if (emailSent) {
        results.email++;
      }
    } catch (error) {
      results.errors.push({ userId, error: error.message });
      console.error(`Erreur lors de la notification pour ${userId}:`, error);
    }
  }

  return results;
}

/**
 * Notifie les participants d'une annulation de balade
 * @param {object} ride - La balade annulée
 * @param {object} cancellationData - Données d'annulation
 * @returns {Promise<object>} Résultat des notifications
 */
async function notifyRideCancellation(ride, cancellationData) {
  const title = 'Balade annulée';
  const message = `La balade "${ride.titre}" a été annulée.`;
  
  return await notifyRideParticipants(
    ride,
    'ride_cancelled',
    title,
    message,
    emailService.sendRideCancellationEmail,
    [ride, cancellationData],
    {
      reasonCode: cancellationData.reasonCode,
      reasonText: cancellationData.reasonText
    }
  );
}

/**
 * Notifie les participants d'un report de balade
 * @param {object} ride - La balade reportée
 * @param {object} postponementData - Données de report
 * @returns {Promise<object>} Résultat des notifications
 */
async function notifyRidePostponement(ride, postponementData) {
  const title = 'Balade reportée';
  const message = `La balade "${ride.titre}" a été reportée.`;
  
  return await notifyRideParticipants(
    ride,
    'ride_postponed',
    title,
    message,
    emailService.sendRidePostponementEmail,
    [ride, postponementData],
    {
      reasonCode: postponementData.reasonCode,
      reasonText: postponementData.reasonText,
      newDateTime: postponementData.newDateTime
    }
  );
}

/**
 * Notifie les participants d'une reprogrammation de balade
 * @param {object} originalRide - La balade originale
 * @param {object} newRide - La nouvelle balade
 * @param {object} rescheduleData - Données de reprogrammation
 * @returns {Promise<object>} Résultat des notifications
 */
async function notifyRideReschedule(originalRide, newRide, rescheduleData) {
  const title = 'Balade reprogrammée';
  const message = `La balade "${originalRide.titre}" a été reprogrammée.`;
  
  return await notifyRideParticipants(
    originalRide,
    'ride_rescheduled',
    title,
    message,
    emailService.sendRideRescheduleEmail,
    [originalRide, newRide, rescheduleData],
    {
      originalRideId: originalRide._id.toString(),
      newRideId: newRide._id.toString()
    }
  );
}

module.exports = {
  notifyRideParticipants,
  notifyRideCancellation,
  notifyRidePostponement,
  notifyRideReschedule,
  sendInAppNotification,
  sendPushNotification,
  sendEmailNotification
};

