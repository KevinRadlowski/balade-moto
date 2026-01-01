const nodemailer = require('nodemailer');
require('dotenv').config();

// Configuration du transporteur email
let transporter = null;

// Créer le transporteur seulement si les credentials sont configurés
if (process.env.SMTP_USER && process.env.SMTP_PASS) {
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: process.env.SMTP_PORT || 587,
    secure: false, // true pour 465, false pour autres ports
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS
    }
  });

  // Vérifier la configuration du transporteur
  transporter.verify((error, success) => {
    if (error) {
      console.warn('⚠️  Configuration email non valide. Les emails ne pourront pas être envoyés.');
      console.warn('   Vérifiez vos variables SMTP_USER et SMTP_PASS dans le fichier .env');
    } else {
      console.log('✅ Serveur email prêt à envoyer des messages');
    }
  });
} else {
  console.warn('⚠️  Variables SMTP_USER et SMTP_PASS non configurées.');
  console.warn('   Les fonctionnalités d\'envoi d\'email seront désactivées.');
  console.warn('   Ajoutez ces variables dans votre fichier .env pour activer les emails.');
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
  
  const mailOptions = {
    from: `"Balades Moto" <${process.env.SMTP_USER}>`,
    to: email,
    subject: 'Vérification de votre compte',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Bienvenue sur Balades Moto !</h2>
        <p>Merci de vous être inscrit. Veuillez cliquer sur le lien ci-dessous pour vérifier votre adresse email :</p>
        <p style="text-align: center; margin: 30px 0;">
          <a href="${verificationUrl}" 
             style="background-color: #4CAF50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
            Vérifier mon email
          </a>
        </p>
        <p>Ou copiez ce lien dans votre navigateur :</p>
        <p style="color: #666; word-break: break-all;">${verificationUrl}</p>
        <p style="color: #999; font-size: 12px; margin-top: 30px;">
          Ce lien expirera dans 24 heures.
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

const sendUnlockEmail = async (email, token) => {
  if (!transporter) {
    console.warn('⚠️  Tentative d\'envoi d\'email mais le transporteur n\'est pas configuré');
    return false;
  }

  const unlockUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/unlock-account?token=${token}`;
  
  const mailOptions = {
    from: `"Balades Moto" <${process.env.SMTP_USER}>`,
    to: email,
    subject: 'Déverrouillage de votre compte',
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
    from: `"Balades Moto" <${process.env.SMTP_USER}>`,
    to: email,
    subject: `Rappel: ${ride.titre} dans 1 heure`,
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

