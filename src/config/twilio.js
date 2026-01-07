/**
 * Configuration Twilio
 * 
 * Variables d'environnement requises:
 * - TWILIO_ACCOUNT_SID
 * - TWILIO_AUTH_TOKEN
 * - TWILIO_VERIFY_SERVICE_SID
 */

const twilio = require('twilio');

let client = null;

/**
 * Initialise et retourne le client Twilio
 * @returns {twilio.Twilio|null} - Client Twilio ou null si config manquante
 */
function getTwilioClient() {
  if (client) {
    return client;
  }

  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;

  if (!accountSid || !authToken) {
    console.warn('⚠️  Twilio non configuré: TWILIO_ACCOUNT_SID et/ou TWILIO_AUTH_TOKEN manquants');
    return null;
  }

  try {
    client = twilio(accountSid, authToken);
    return client;
  } catch (error) {
    console.error('❌ Erreur lors de l\'initialisation du client Twilio:', error.message);
    return null;
  }
}

/**
 * Vérifie si Twilio est configuré
 * @returns {boolean}
 */
function isTwilioConfigured() {
  return !!(
    process.env.TWILIO_ACCOUNT_SID &&
    process.env.TWILIO_AUTH_TOKEN &&
    process.env.TWILIO_VERIFY_SERVICE_SID
  );
}

/**
 * Retourne le Service SID de Twilio Verify
 * @returns {string|null}
 */
function getVerifyServiceSid() {
  return process.env.TWILIO_VERIFY_SERVICE_SID || null;
}

module.exports = {
  getTwilioClient,
  isTwilioConfigured,
  getVerifyServiceSid
};
