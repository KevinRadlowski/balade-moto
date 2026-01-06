const User = require('../models/User');
const emailService = require('./email.service');

/**
 * Récupère le contact d'urgence d'un utilisateur
 * @param {String} userId - ID de l'utilisateur
 * @returns {Promise<Object>} Contact d'urgence
 */
const getEmergencyContact = async (userId) => {
  try {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('Utilisateur non trouvé');
    }

    return user.emergencyContact || null;
  } catch (error) {
    console.error('Erreur lors de la récupération du contact:', error);
    throw error;
  }
};

/**
 * Met à jour le contact d'urgence d'un utilisateur
 * @param {String} userId - ID de l'utilisateur
 * @param {Object} contactData - Données du contact
 * @returns {Promise<Object>} Contact mis à jour
 */
const updateEmergencyContact = async (userId, contactData) => {
  try {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('Utilisateur non trouvé');
    }

    user.emergencyContact = {
      name: contactData.name,
      phone: contactData.phone,
      relation: contactData.relation || 'family',
      notes: contactData.notes || null
    };

    await user.save();

    return user.emergencyContact;
  } catch (error) {
    console.error('Erreur lors de la mise à jour du contact:', error);
    throw error;
  }
};

/**
 * Supprime le contact d'urgence d'un utilisateur
 * @param {String} userId - ID de l'utilisateur
 * @returns {Promise<Boolean>} Succès
 */
const deleteEmergencyContact = async (userId) => {
  try {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('Utilisateur non trouvé');
    }

    user.emergencyContact = null;
    await user.save();

    return true;
  } catch (error) {
    console.error('Erreur lors de la suppression du contact:', error);
    throw error;
  }
};

/**
 * Déclenche une alerte d'urgence
 * @param {String} userId - ID de l'utilisateur
 * @param {String} reason - Raison de l'alerte
 * @returns {Promise<Boolean>} Succès
 */
const triggerEmergencyAlert = async (userId, reason) => {
  try {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('Utilisateur non trouvé');
    }

    if (!user.emergencyContact || !user.emergencyContact.phone) {
      throw new Error('Aucun contact d\'urgence configuré');
    }

    const contact = user.emergencyContact;

    // Envoyer une alerte (email ou SMS selon le format)
    if (contact.phone.includes('@')) {
      // C'est un email
      await emailService.sendEmergencyAlertEmail(
        contact.phone,
        user,
        reason
      );
    } else {
      // C'est un numéro de téléphone
      // TODO: Implémenter l'envoi SMS (Twilio, etc.)
      console.warn('Envoi SMS non implémenté. Contact:', contact.phone);
    }

    return true;
  } catch (error) {
    console.error('Erreur lors du déclenchement de l\'alerte:', error);
    throw error;
  }
};

module.exports = {
  getEmergencyContact,
  updateEmergencyContact,
  deleteEmergencyContact,
  triggerEmergencyAlert
};






