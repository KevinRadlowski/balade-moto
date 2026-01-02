const nodemailer = require('nodemailer');
const { emailConfig, isEmailConfigured, logEmailWarningIfNeeded } = require('../config/email');
require('dotenv').config();

// Configuration du transporteur email
let transporter = null;

// Créer le transporteur seulement si les credentials sont configurés
if (isEmailConfigured()) {
  transporter = nodemailer.createTransport({
    host: emailConfig.host,
    port: emailConfig.port,
    secure: emailConfig.port === 465, // true pour 465, false pour autres ports
    auth: {
      user: emailConfig.user,
      pass: emailConfig.pass
    }
  });

  // Vérifier la configuration du transporteur
  transporter.verify((error, success) => {
    if (error) {
      console.warn('⚠️  Configuration email non valide. Les emails ne pourront pas être envoyés.');
      console.warn('   Erreur:', error.message);
    } else {
      console.log('✅ Serveur email prêt à envoyer des messages');
    }
  });
} else {
  logEmailWarningIfNeeded();
}

// Fonctions d'envoi d'email
const sendVerificationEmail = async (email, token) => {
  if (!transporter) {
    console.warn('⚠️  Tentative d\'envoi d\'email mais le transporteur n\'est pas configuré');
    return false;
  }

  // URL de vérification : pointer vers le backend API directement
  // Le backend retournera une page HTML de confirmation
  const backendUrl = process.env.BACKEND_URL || 'http://localhost:5000';
  const verificationUrl = `${backendUrl}/api/auth/verify-email?token=${token}`;
  
  // URLs des images (servies depuis le backend ou assets)
  const logoUrl = `https://www.ridetogether.fr/logo.png`;
  const backgroundUrl = `https://www.ridetogether.fr/bg-home2.png`;
  
  const mailOptions = {
    from: emailConfig.from ? `"Ride Together" <${emailConfig.from}>` : `"Ride Together" <${emailConfig.user}>`,
    to: email,
    subject: 'Bienvenue sur Ride Together - Vérifiez votre compte',
    html: `
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Vérification de votre compte Ride Together</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa;">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color: #f5f7fa;">
          <tr>
            <td align="center" style="padding: 40px 20px;">
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="600" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);">
                <!-- Header avec background -->
                <tr>
                  <td bgcolor="#3F51B5" style="background-color: #3F51B5; background-image: url('${backgroundUrl}'); background-size: cover; background-position: center; background-repeat: no-repeat; padding: 260px 140px; text-align: center;">
                    <h1 style="color: #ffffff; font-size: 32px; font-weight: bold; margin: 0; text-shadow: 0 2px 8px rgba(0,0,0,0.5);">Bienvenue !</h1>
                  </td>
                </tr>
                <!-- Contenu principal -->
                <tr>
                  <td style="padding: 40px;">
                    <h2 style="color: #212121; font-size: 24px; font-weight: 600; margin: 0 0 20px 0;">Vérification de votre compte</h2>
                    <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
                      Merci de vous être inscrit sur <strong style="color: #3F51B5;">Ride Together</strong> ! 
                      Pour finaliser votre inscription et activer votre compte, veuillez vérifier votre adresse email en cliquant sur le bouton ci-dessous.
                    </p>
                    <!-- Bouton CTA -->
                    <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
                      <tr>
                        <td align="center" style="padding: 20px 0;">
                          <table role="presentation" cellspacing="0" cellpadding="0" border="0">
                            <tr>
                              <td bgcolor="#3F51B5" align="center" style="background-color: #3F51B5; border-radius: 12px; padding: 16px 40px;">
                                <a href="${verificationUrl}" 
                                   style="color: #ffffff; text-decoration: none; font-weight: 600; font-size: 16px; display: inline-block;">
                                  Vérifier mon email
                                </a>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                    <!-- Lien alternatif -->
                    <p style="color: #999999; font-size: 14px; line-height: 1.6; margin: 30px 0 0 0; text-align: center;">
                      Si le bouton ne fonctionne pas, copiez et collez ce lien dans votre navigateur :<br>
                      <a href="${verificationUrl}" style="color: #3F51B5; word-break: break-all; text-decoration: underline;">${verificationUrl}</a>
                    </p>
                  </td>
                </tr>
                <!-- Footer -->
                <tr>
                  <td style="background-color: #10181F; padding: 30px 40px; text-align: center;">
                    <p style="color: #ffffff; font-size: 14px; margin: 0 0 10px 0; opacity: 0.9;">
                      <strong>Ride Together</strong> - Organisez et participez à des balades moto
                    </p>
                    <p style="color: #ffffff; font-size: 12px; margin: 0; opacity: 0.7;">
                      Ce lien expirera dans <strong>24 heures</strong>.
                    </p>
                    <p style="color: #ffffff; font-size: 12px; margin: 15px 0 0 0; opacity: 0.6;">
                      Si vous n'avez pas créé de compte, vous pouvez ignorer cet email.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    return true;
  } catch (error) {
    console.error('Erreur lors de l\'envoi de l\'email:', error);
    throw error;
  }
};

const sendUnlockEmail = async (email, token) => {
  if (!transporter) {
    console.warn('⚠️  Tentative d\'envoi d\'email mais le transporteur n\'est pas configuré');
    return false;
  }

  const unlockUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/unlock-account?token=${token}`;
  
  const mailOptions = {
    from: emailConfig.from ? `"Ride Together" <${emailConfig.from}>` : `"Ride Together" <${emailConfig.user}>`,
    to: email,
    subject: 'Déverrouillage de votre compte Ride Together',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Déverrouillage de compte</h2>
        <p>Votre compte a été verrouillé après plusieurs tentatives de connexion échouées.</p>
        <p>Cliquez sur le lien ci-dessous pour déverrouiller votre compte :</p>
        <p style="text-align: center; margin: 30px 0;">
          <a href="${unlockUrl}" 
             style="background-color: #2196F3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
            Déverrouiller mon compte
          </a>
        </p>
        <p>Ou copiez ce lien dans votre navigateur :</p>
        <p style="color: #666; word-break: break-all;">${unlockUrl}</p>
        <p style="color: #999; font-size: 12px; margin-top: 30px;">
          Ce lien expirera dans 1 heure.
        </p>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    return true;
  } catch (error) {
    console.error('Erreur lors de l\'envoi de l\'email:', error);
    throw error;
  }
};

const sendRideReminderEmail = async (email, ride, userName) => {
  if (!transporter) {
    console.warn('⚠️  Tentative d\'envoi d\'email mais le transporteur n\'est pas configuré');
    return false;
  }

  const rideUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/rides/${ride._id}`;
  
  // Formater la date et l'heure
  const rideDate = new Date(ride.date);
  const [hours, minutes] = ride.heure.split(':');
  rideDate.setHours(parseInt(hours), parseInt(minutes), 0, 0);
  
  const formattedDate = rideDate.toLocaleDateString('fr-FR', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });
  const formattedTime = ride.heure;
  
  const mailOptions = {
    from: emailConfig.from ? `"Ride Together" <${emailConfig.from}>` : `"Ride Together" <${emailConfig.user}>`,
    to: email,
    subject: `Ride Together - Rappel: ${ride.titre} dans 1 heure`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Rappel de balade</h2>
        <p>Bonjour ${userName || 'utilisateur'},</p>
        <p>Vous avez une balade prévue dans <strong>1 heure</strong> :</p>
        <div style="background-color: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px 0;">
          <h3 style="color: #4CAF50; margin-top: 0;">${ride.titre}</h3>
          <p><strong>Date :</strong> ${formattedDate}</p>
          <p><strong>Heure :</strong> ${formattedTime}</p>
          <p><strong>Type de véhicule :</strong> ${ride.typeVehicule === 'moto' ? 'Moto' : 'Voiture'}</p>
          <p><strong>Lieu de départ :</strong> ${typeof ride.lieuDepart === 'string' ? ride.lieuDepart : JSON.stringify(ride.lieuDepart)}</p>
          <p><strong>Lieu d'arrivée :</strong> ${typeof ride.lieuArrivee === 'string' ? ride.lieuArrivee : JSON.stringify(ride.lieuArrivee)}</p>
          ${ride.description ? `<p><strong>Description :</strong> ${ride.description}</p>` : ''}
        </div>
        <p style="text-align: center; margin: 30px 0;">
          <a href="${rideUrl}" 
             style="background-color: #4CAF50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
            Voir les détails
          </a>
        </p>
        <p style="color: #999; font-size: 12px; margin-top: 30px;">
          Bonne balade ! 🏍️
        </p>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    return true;
  } catch (error) {
    console.error('Erreur lors de l\'envoi de l\'email de rappel:', error);
    throw error;
  }
};

// Exporter les fonctions ET le transporter
module.exports = {
  sendVerificationEmail,
  sendUnlockEmail,
  sendRideReminderEmail,
  transporter: transporter || { verify: () => {} }
};

