const emailService = require('../services/email.service');
const { BadRequestError } = require('../utils/errors');

/**
 * Envoyer un email de contact au support
 * POST /contact
 */
exports.sendContactEmail = async (req, res, next) => {
  try {
    const { email, subject, message } = req.body;

    // Validation
    if (!email || !subject || !message) {
      throw new BadRequestError('Email, sujet et message sont requis');
    }

    // Valider le format de l'email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new BadRequestError('Format d\'email invalide');
    }

    // Valider la longueur du message
    if (message.trim().length < 10) {
      throw new BadRequestError('Le message doit contenir au moins 10 caractères');
    }

    // Envoyer l'email au support
    const success = await emailService.sendContactEmail({
      fromEmail: email,
      subject: subject,
      message: message,
    });

    if (!success) {
      return res.status(500).json({
        success: false,
        message: 'Erreur lors de l\'envoi de l\'email. Veuillez réessayer plus tard.',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Votre message a été envoyé avec succès. Nous vous répondrons dans les plus brefs délais.',
    });
  } catch (error) {
    next(error);
  }
};



