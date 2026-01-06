const emergencyContactService = require('../services/emergencyContact.service');
const { BadRequestError, NotFoundError } = require('../utils/errors');

/**
 * Récupérer le contact d'urgence
 */
exports.getEmergencyContact = async (req, res, next) => {
  try {
    const userId = req.user._id;

    const contact = await emergencyContactService.getEmergencyContact(userId);

    res.json({
      success: true,
      data: { contact }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Créer ou mettre à jour le contact d'urgence
 */
exports.updateEmergencyContact = async (req, res, next) => {
  try {
    const { name, phone, relation, notes } = req.body;
    const userId = req.user._id;

    if (!name || !phone) {
      throw new BadRequestError('Le nom et le téléphone sont requis');
    }

    const contact = await emergencyContactService.updateEmergencyContact(userId, {
      name,
      phone,
      relation,
      notes
    });

    res.json({
      success: true,
      message: 'Contact d\'urgence mis à jour avec succès',
      data: { contact }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Supprimer le contact d'urgence
 */
exports.deleteEmergencyContact = async (req, res, next) => {
  try {
    const userId = req.user._id;

    await emergencyContactService.deleteEmergencyContact(userId);

    res.json({
      success: true,
      message: 'Contact d\'urgence supprimé avec succès'
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Déclencher une alerte d'urgence
 */
exports.triggerEmergencyAlert = async (req, res, next) => {
  try {
    const { reason } = req.body;
    const userId = req.user._id;

    if (!reason) {
      throw new BadRequestError('La raison de l\'alerte est requise');
    }

    await emergencyContactService.triggerEmergencyAlert(userId, reason);

    res.json({
      success: true,
      message: 'Alerte d\'urgence envoyée'
    });
  } catch (error) {
    next(error);
  }
};





