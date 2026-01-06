/**
 * Service d'envoi de SMS pour la vérification OTP
 * 
 * Pour l'instant, on simule l'envoi (en développement)
 * En production, intégrer un service comme Twilio, AWS SNS, etc.
 */

/**
 * Envoyer un code OTP par SMS
 * @param {string} phone - Numéro de téléphone au format E.164
 * @param {string} code - Code OTP à envoyer
 * @returns {Promise<boolean>} - true si l'envoi a réussi
 */
async function sendOtpSms(phone, code) {
  try {
    // En développement, on simule l'envoi
    if (process.env.NODE_ENV === 'development' || process.env.SKIP_SMS_VERIFICATION === 'true') {
      console.log(`📱 [DEV] SMS OTP pour ${phone}: ${code}`);
      return true;
    }

    // TODO: Intégrer un service SMS réel (Twilio, AWS SNS, etc.)
    // Exemple avec Twilio:
    // const accountSid = process.env.TWILIO_ACCOUNT_SID;
    // const authToken = process.env.TWILIO_AUTH_TOKEN;
    // const client = require('twilio')(accountSid, authToken);
    // await client.messages.create({
    //   body: `Votre code de vérification RideTogether est: ${code}`,
    //   from: process.env.TWILIO_PHONE_NUMBER,
    //   to: phone
    // });

    console.log(`📱 SMS OTP envoyé à ${phone}: ${code}`);
    return true;
  } catch (error) {
    console.error('Erreur lors de l\'envoi du SMS:', error);
    throw error;
  }
}

module.exports = {
  sendOtpSms
};
