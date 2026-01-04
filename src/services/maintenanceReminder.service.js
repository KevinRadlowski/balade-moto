const MaintenanceReminder = require('../models/MaintenanceReminder');
const Vehicle = require('../models/Vehicle');
const emailService = require('./email.service');
const User = require('../models/User');

/**
 * Crée un rappel d'entretien
 * @param {String} userId - ID de l'utilisateur
 * @param {String} vehicleId - ID du véhicule
 * @param {Object} data - Données du rappel
 * @returns {Promise<Object>} Rappel créé
 */
const createReminder = async (userId, vehicleId, data) => {
  try {
    const vehicle = await Vehicle.findById(vehicleId);
    if (!vehicle) {
      throw new Error('Véhicule non trouvé');
    }

    // Calculer les dates d'échéance
    let nextDueKm = null;
    let nextDueDate = null;

    if (data.intervalKm && vehicle.odometerCurrentKm) {
      const lastKm = data.lastDoneKm || vehicle.odometerCurrentKm;
      nextDueKm = lastKm + data.intervalKm;
    }

    if (data.intervalMonths) {
      const lastDate = data.lastDoneDate || new Date();
      nextDueDate = new Date(lastDate);
      nextDueDate.setMonth(nextDueDate.getMonth() + data.intervalMonths);
    }

    const reminder = new MaintenanceReminder({
      userId,
      vehicleId,
      type: data.type,
      description: data.description,
      intervalKm: data.intervalKm,
      intervalMonths: data.intervalMonths,
      lastDoneKm: data.lastDoneKm,
      lastDoneDate: data.lastDoneDate,
      nextDueKm,
      nextDueDate,
      status: 'active'
    });

    await reminder.save();

    return reminder;
  } catch (error) {
    console.error('Erreur lors de la création du rappel:', error);
    throw error;
  }
};

/**
 * Vérifie les rappels échus et envoie des notifications
 * @returns {Promise<Number>} Nombre de rappels traités
 */
const checkDueReminders = async () => {
  try {
    const now = new Date();
    
    // Trouver les rappels échus
    // Note: Pour nextDueKm, on vérifie uniquement ceux qui ont une échéance km définie
    const dueReminders = await MaintenanceReminder.find({
      status: 'active',
      $or: [
        { nextDueDate: { $lte: now } },
        { 
          nextDueKm: { $exists: true, $ne: null },
          // Pour nextDueKm, on devra vérifier dynamiquement avec le véhicule
        }
      ]
    }).populate('userId', 'email firstName lastName')
      .populate('vehicleId', 'nickname make model odometerCurrentKm');

    // Filtrer ceux qui sont échus en km
    const Vehicle = require('../models/Vehicle');
    const reallyDueReminders = [];
    for (const reminder of dueReminders) {
      if (reminder.nextDueDate && reminder.nextDueDate <= now) {
        reallyDueReminders.push(reminder);
      } else if (reminder.nextDueKm && reminder.vehicleId) {
        const currentKm = reminder.vehicleId.odometerCurrentKm || 0;
        if (currentKm >= reminder.nextDueKm) {
          reallyDueReminders.push(reminder);
        }
      }
    }

    let processed = 0;

    for (const reminder of reallyDueReminders) {
      try {
        const user = reminder.userId;
        const vehicle = reminder.vehicleId;

        if (user && user.email) {
          // Envoyer un email de rappel
          await emailService.sendMaintenanceReminderEmail(
            user.email,
            reminder,
            vehicle,
            user
          );

          // Enregistrer la notification
          reminder.notifications.push({
            sentAt: new Date(),
            type: 'email',
            status: 'sent'
          });

          await reminder.save();
          processed++;
        }
      } catch (error) {
        console.error(`Erreur lors de l'envoi du rappel ${reminder._id}:`, error);
        
        // Enregistrer l'échec
        reminder.notifications.push({
          sentAt: new Date(),
          type: 'email',
          status: 'failed'
        });
        await reminder.save();
      }
    }

    return processed;
  } catch (error) {
    console.error('Erreur lors de la vérification des rappels:', error);
    throw error;
  }
};

/**
 * Reporte un rappel (snooze)
 * @param {String} reminderId - ID du rappel
 * @param {Number} days - Nombre de jours à reporter
 * @returns {Promise<Object>} Rappel mis à jour
 */
const snoozeReminder = async (reminderId, days) => {
  try {
    const reminder = await MaintenanceReminder.findById(reminderId);
    if (!reminder) {
      throw new Error('Rappel non trouvé');
    }

    const snoozeDate = new Date();
    snoozeDate.setDate(snoozeDate.getDate() + days);

    reminder.snoozedUntil = snoozeDate;
    reminder.status = 'snoozed';

    await reminder.save();

    return reminder;
  } catch (error) {
    console.error('Erreur lors du report du rappel:', error);
    throw error;
  }
};

/**
 * Helper pour obtenir le kilométrage actuel d'un véhicule
 * @param {String} vehicleId - ID du véhicule
 * @returns {Promise<Number>} Kilométrage actuel
 */
const getCurrentOdometer = async (vehicleId) => {
  const Vehicle = require('../models/Vehicle');
  const vehicle = await Vehicle.findById(vehicleId);
  return vehicle ? (vehicle.odometerCurrentKm || 0) : 0;
};

module.exports = {
  createReminder,
  checkDueReminders,
  snoozeReminder
};

