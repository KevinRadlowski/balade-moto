const maintenanceReminderService = require('../services/maintenanceReminder.service');
const MaintenanceReminder = require('../models/MaintenanceReminder');
const Vehicle = require('../models/Vehicle');
const { NotFoundError, ForbiddenError, BadRequestError } = require('../utils/errors');

/**
 * Créer un rappel d'entretien
 */
exports.createReminder = async (req, res, next) => {
  try {
    const { vehicleId, type, description, intervalKm, intervalMonths, lastDoneKm, lastDoneDate } = req.body;
    const userId = req.user._id;

    // Vérifier que le véhicule appartient à l'utilisateur
    const vehicle = await Vehicle.findById(vehicleId);
    if (!vehicle) {
      throw new NotFoundError('Véhicule non trouvé');
    }

    if (vehicle.ownerUserId.toString() !== userId.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas autorisé à créer un rappel pour ce véhicule');
    }

    const reminder = await maintenanceReminderService.createReminder(userId, vehicleId, {
      type,
      description,
      intervalKm,
      intervalMonths,
      lastDoneKm,
      lastDoneDate
    });

    res.status(201).json({
      success: true,
      message: 'Rappel créé avec succès',
      data: { reminder }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Récupérer tous les rappels d'un utilisateur
 */
exports.getReminders = async (req, res, next) => {
  try {
    const userId = req.user._id;
    const { vehicleId, status } = req.query;

    const filter = { userId };
    if (vehicleId) filter.vehicleId = vehicleId;
    if (status) filter.status = status;

    const reminders = await MaintenanceReminder.find(filter)
      .populate('vehicleId', 'nickname make model')
      .sort({ nextDueDate: 1, nextDueKm: 1 });

    res.json({
      success: true,
      data: { reminders }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Récupérer un rappel par ID
 */
exports.getReminderById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const reminder = await MaintenanceReminder.findById(id)
      .populate('vehicleId', 'nickname make model');

    if (!reminder) {
      throw new NotFoundError('Rappel non trouvé');
    }

    if (reminder.userId.toString() !== userId.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas autorisé à voir ce rappel');
    }

    res.json({
      success: true,
      data: { reminder }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Mettre à jour un rappel
 */
exports.updateReminder = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { type, description, intervalKm, intervalMonths, lastDoneKm, lastDoneDate, status } = req.body;
    const userId = req.user._id;

    const reminder = await MaintenanceReminder.findById(id);

    if (!reminder) {
      throw new NotFoundError('Rappel non trouvé');
    }

    if (reminder.userId.toString() !== userId.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas autorisé à modifier ce rappel');
    }

    if (type) reminder.type = type;
    if (description !== undefined) reminder.description = description;
    if (intervalKm !== undefined) reminder.intervalKm = intervalKm;
    if (intervalMonths !== undefined) reminder.intervalMonths = intervalMonths;
    if (lastDoneKm !== undefined) reminder.lastDoneKm = lastDoneKm;
    if (lastDoneDate !== undefined) reminder.lastDoneDate = lastDoneDate;
    if (status) reminder.status = status;

    // Recalculer les dates d'échéance si nécessaire
    if (lastDoneKm !== undefined || lastDoneDate !== undefined || intervalKm !== undefined || intervalMonths !== undefined) {
      const vehicle = await Vehicle.findById(reminder.vehicleId);
      if (vehicle) {
        if (reminder.intervalKm && vehicle.odometerCurrentKm) {
          const lastKm = reminder.lastDoneKm || vehicle.odometerCurrentKm;
          reminder.nextDueKm = lastKm + reminder.intervalKm;
        }
        if (reminder.intervalMonths) {
          const lastDate = reminder.lastDoneDate || new Date();
          const nextDate = new Date(lastDate);
          nextDate.setMonth(nextDate.getMonth() + reminder.intervalMonths);
          reminder.nextDueDate = nextDate;
        }
      }
    }

    await reminder.save();

    res.json({
      success: true,
      message: 'Rappel mis à jour avec succès',
      data: { reminder }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Supprimer un rappel
 */
exports.deleteReminder = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const reminder = await MaintenanceReminder.findById(id);

    if (!reminder) {
      throw new NotFoundError('Rappel non trouvé');
    }

    if (reminder.userId.toString() !== userId.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas autorisé à supprimer ce rappel');
    }

    await reminder.deleteOne();

    res.json({
      success: true,
      message: 'Rappel supprimé avec succès'
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Marquer un rappel comme terminé
 */
exports.markAsDone = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { odometerKm } = req.body;
    const userId = req.user._id;

    const reminder = await MaintenanceReminder.findById(id);

    if (!reminder) {
      throw new NotFoundError('Rappel non trouvé');
    }

    if (reminder.userId.toString() !== userId.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas autorisé à modifier ce rappel');
    }

    const vehicle = await Vehicle.findById(reminder.vehicleId);
    if (!vehicle) {
      throw new NotFoundError('Véhicule non trouvé');
    }

    // Mettre à jour les dates
    reminder.lastDoneKm = odometerKm || vehicle.odometerCurrentKm;
    reminder.lastDoneDate = new Date();
    reminder.status = 'completed';

    // Recalculer la prochaine échéance
    if (reminder.intervalKm) {
      reminder.nextDueKm = reminder.lastDoneKm + reminder.intervalKm;
    }
    if (reminder.intervalMonths) {
      const nextDate = new Date(reminder.lastDoneDate);
      nextDate.setMonth(nextDate.getMonth() + reminder.intervalMonths);
      reminder.nextDueDate = nextDate;
    }

    // Créer un nouveau rappel actif si nécessaire
    if (reminder.intervalKm || reminder.intervalMonths) {
      const newReminder = new MaintenanceReminder({
        userId: reminder.userId,
        vehicleId: reminder.vehicleId,
        type: reminder.type,
        description: reminder.description,
        intervalKm: reminder.intervalKm,
        intervalMonths: reminder.intervalMonths,
        lastDoneKm: reminder.lastDoneKm,
        lastDoneDate: reminder.lastDoneDate,
        nextDueKm: reminder.nextDueKm,
        nextDueDate: reminder.nextDueDate,
        status: 'active'
      });
      await newReminder.save();
    }

    await reminder.save();

    res.json({
      success: true,
      message: 'Rappel marqué comme terminé',
      data: { reminder }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Reporter un rappel (snooze)
 */
exports.snoozeReminder = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { days } = req.body;
    const userId = req.user._id;

    if (!days || days < 1 || days > 30) {
      throw new BadRequestError('Le nombre de jours doit être entre 1 et 30');
    }

    const reminder = await MaintenanceReminder.findById(id);

    if (!reminder) {
      throw new NotFoundError('Rappel non trouvé');
    }

    if (reminder.userId.toString() !== userId.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas autorisé à modifier ce rappel');
    }

    const updatedReminder = await maintenanceReminderService.snoozeReminder(id, days);

    res.json({
      success: true,
      message: 'Rappel reporté avec succès',
      data: { reminder: updatedReminder }
    });
  } catch (error) {
    next(error);
  }
};






