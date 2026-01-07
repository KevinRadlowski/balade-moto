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
    },
    // Options de connexion pour éviter les timeouts
    connectionTimeout: 10000, // 10 secondes pour établir la connexion
    greetingTimeout: 10000, // 10 secondes pour la réponse du serveur
    socketTimeout: 10000, // 10 secondes pour les opérations socket
    // Options TLS pour le port 587
    requireTLS: emailConfig.port === 587,
    tls: {
      // Ne pas rejeter les certificats non autorisés (utile en dev)
      rejectUnauthorized: process.env.NODE_ENV === 'production',
      // Minimum TLS version
      minVersion: 'TLSv1.2'
    },
    // Pool de connexions pour améliorer les performances
    pool: true,
    maxConnections: 1,
    maxMessages: 3
  });

  // Vérifier la configuration du transporteur (sauf si explicitement désactivé)
  // Par défaut, les emails sont envoyés normalement (même en développement)
  // Pour désactiver : SKIP_EMAIL_VERIFICATION=true dans .env
  const skipVerification = process.env.SKIP_EMAIL_VERIFICATION === 'true';
  
  if (skipVerification) {
    console.log('⚠️  Vérification email désactivée (mode développement)');
    console.log('   Les emails seront tentés mais les erreurs seront ignorées silencieusement');
  } else {
    transporter.verify((error, success) => {
      if (error) {
      console.warn('⚠️  Configuration email non valide. Les emails ne pourront pas être envoyés.');
      console.warn('   Erreur:', error.message);
      console.warn('   Code:', error.code);
      console.warn('   Configuration actuelle:');
      console.warn(`      Host: ${emailConfig.host}`);
      console.warn(`      Port: ${emailConfig.port}`);
      console.warn(`      User: ${emailConfig.user ? emailConfig.user.substring(0, 5) + '...' : 'NON DÉFINI'}`);
      console.warn(`      Pass: ${emailConfig.pass ? '***' : 'NON DÉFINI'}`);
      console.warn(`      From: ${emailConfig.from || 'NON DÉFINI'}`);
      console.warn('');
      console.warn('   Solutions possibles:');
      
      // Suggestions spécifiques selon le type d'erreur
      if (error.code === 'ESOCKET' || error.code === 'ETIMEDOUT' || error.message.includes('timeout')) {
        console.warn('   ⚠️  Erreur de connexion/timeout détectée:');
        console.warn('   1. Vérifiez que votre firewall/autorouteur autorise les connexions sortantes sur le port SMTP');
        console.warn('   2. Essayez le port 465 (SSL) au lieu de 587 (TLS) :');
        console.warn('      SMTP_PORT=465');
        console.warn('   3. Vérifiez votre connexion internet');
        console.warn('   4. Si vous êtes derrière un VPN/proxy, désactivez-le temporairement pour tester');
        console.warn('   5. Testez la connexion manuellement :');
        console.warn(`      telnet ${emailConfig.host} ${emailConfig.port}`);
        console.warn('      (ou utilisez: Test-NetConnection -ComputerName smtp.gmail.com -Port 587 sur PowerShell)');
      } else if (error.code === 'EAUTH' || error.message.includes('Invalid login') || error.message.includes('authentication')) {
        console.warn('   ⚠️  Erreur d\'authentification détectée:');
        console.warn('   1. Pour Gmail, utilisez un "App Password" (pas votre mot de passe normal)');
        console.warn('      → https://myaccount.google.com/apppasswords');
        console.warn('   2. Vérifiez que SMTP_USER et SMTP_PASS sont corrects dans .env');
        console.warn('   3. Assurez-vous que la validation en 2 étapes est activée sur votre compte Gmail');
      } else {
        console.warn('   1. Vérifiez que SMTP_USER (ou EMAIL_USER) et SMTP_PASS (ou EMAIL_PASS) sont définis dans .env');
        console.warn('   2. Pour Gmail, utilisez un "App Password" (pas votre mot de passe normal)');
        console.warn('      → https://myaccount.google.com/apppasswords');
        console.warn('   3. Vérifiez que le port est correct (587 pour TLS, 465 pour SSL)');
        console.warn('   4. Vérifiez que votre firewall autorise les connexions sortantes sur le port SMTP');
      }
      
      console.warn('');
      console.warn('   💡 Astuce: Si le port 587 ne fonctionne pas, essayez 465 (SSL)');
      console.warn('   💡 Pour le développement, vous pouvez désactiver la vérification:');
      console.warn('      SKIP_EMAIL_VERIFICATION=true dans .env');
    } else {
      console.log('✅ Serveur email prêt à envoyer des messages');
      console.log(`   Host: ${emailConfig.host}:${emailConfig.port}`);
      console.log(`   From: ${emailConfig.from || emailConfig.user}`);
    }
  });
  }
} else {
  logEmailWarningIfNeeded();
}

// Fonctions d'envoi d'email
// Fonction helper pour construire l'en-tête "from"
const buildFromHeader = (displayName = 'Ride Together') => {
  // Si emailConfig.from contient déjà le format complet (avec chevrons), remplacer juste le nom
  if (emailConfig.from && (emailConfig.from.includes('<') && emailConfig.from.includes('>'))) {
    // Extraire l'email entre les chevrons
    const emailMatch = emailConfig.from.match(/<([^>]+)>/);
    if (emailMatch) {
      return `"${displayName}" <${emailMatch[1]}>`;
    }
    // Si pas de match, utiliser tel quel (format déjà correct)
    return emailConfig.from;
  }
  // Sinon, construire le format
  if (emailConfig.from) {
    return `"${displayName}" <${emailConfig.from}>`;
  }
  return `"${displayName}" <${emailConfig.user}>`;
};

const sendVerificationEmail = async (email, token) => {
  if (!transporter) {
    console.warn('⚠️  Tentative d\'envoi d\'email mais le transporteur n\'est pas configuré');
    return false;
  }

  // URL de vérification : pointer vers le backend API directement
  // Le backend retournera une page HTML de confirmation
  const backendUrl = process.env.BACKEND_URL;
  const verificationUrl = `${backendUrl}/api/auth/verify-email?token=${token}`;
  
  // URLs des images (servies depuis le backend ou assets)
  const logoUrl = `https://www.ridetogether.fr/logo.png`;
  const backgroundUrl = `https://www.ridetogether.fr/bg-home2.png`;
  
  const mailOptions = {
    from: buildFromHeader(),
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
    // Par défaut, les emails sont envoyés normalement
    // Pour désactiver : SKIP_EMAIL_VERIFICATION=true dans .env
    const skipVerification = process.env.SKIP_EMAIL_VERIFICATION === 'true';
    
    if (skipVerification) {
      // En mode développement avec vérification désactivée, ignorer silencieusement
      console.warn('⚠️  Email non envoyé (mode développement, vérification désactivée)');
      return false;
    }
    
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
    from: buildFromHeader(),
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
    // Par défaut, les emails sont envoyés normalement
    // Pour désactiver : SKIP_EMAIL_VERIFICATION=true dans .env
    const skipVerification = process.env.SKIP_EMAIL_VERIFICATION === 'true';
    
    if (skipVerification) {
      // En mode développement avec vérification désactivée, ignorer silencieusement
      console.warn('⚠️  Email non envoyé (mode développement, vérification désactivée)');
      return false;
    }
    
    console.error('Erreur lors de l\'envoi de l\'email:', error);
    throw error;
  }
};

const sendResetPasswordEmail = async (email, token) => {
  if (!transporter) {
    console.warn('⚠️  Tentative d\'envoi d\'email mais le transporteur n\'est pas configuré');
    return false;
  }

  // Utiliser l'URL du frontend Flutter pour le lien de réinitialisation
  // Le frontend Flutter gérera l'affichage et la validation
  const frontendUrlRaw = process.env.FRONTEND_URL || 'http://localhost:3000';
  const frontendUrl = frontendUrlRaw.split(',')[0].trim();
  const resetUrl = `${frontendUrl}/reset-password?token=${token}`;

  const mailOptions = {
    from: buildFromHeader(),
    to: email,
    subject: 'Ride Together - Réinitialisation de votre mot de passe',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
      </head>
      <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f5f5f5;">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color: #f5f5f5;">
          <tr>
            <td align="center" style="padding: 40px 20px;">
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="600" style="max-width: 600px; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 40px 30px 40px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: 600;">
                      Réinitialisation de mot de passe
                    </h1>
                  </td>
                </tr>
                <!-- Content -->
                <tr>
                  <td style="padding: 40px;">
                    <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
                      Bonjour,
                    </p>
                    <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
                      Vous avez demandé à réinitialiser votre mot de passe pour votre compte Ride Together.
                    </p>
                    <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
                      Cliquez sur le bouton ci-dessous pour créer un nouveau mot de passe :
                    </p>
                    <!-- Bouton CTA -->
                    <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
                      <tr>
                        <td align="center" style="padding: 0 0 30px 0;">
                          <table role="presentation" cellspacing="0" cellpadding="0" border="0">
                            <tr>
                              <td bgcolor="#3F51B5" align="center" style="background-color: #3F51B5; border-radius: 12px; padding: 16px 40px;">
                                <a href="${resetUrl}" 
                                   style="color: #ffffff; text-decoration: none; font-weight: 600; font-size: 16px; display: inline-block;">
                                  Réinitialiser mon mot de passe
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
                      <a href="${resetUrl}" style="color: #3F51B5; word-break: break-all; text-decoration: underline;">${resetUrl}</a>
                    </p>
                    <p style="color: #666666; font-size: 14px; line-height: 1.6; margin: 30px 0 0 0; padding-top: 20px; border-top: 1px solid #eeeeee;">
                      <strong>⚠️ Important :</strong> Si vous n'avez pas demandé cette réinitialisation, ignorez cet email. Votre mot de passe ne sera pas modifié.
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
                      Ce lien expirera dans <strong>1 heure</strong>.
                    </p>
                    <p style="color: #ffffff; font-size: 12px; margin: 15px 0 0 0; opacity: 0.6;">
                      Si vous n'avez pas demandé cette réinitialisation, vous pouvez ignorer cet email en toute sécurité.
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
    // Par défaut, les emails sont envoyés normalement
    // Pour désactiver : SKIP_EMAIL_VERIFICATION=true dans .env
    const skipVerification = process.env.SKIP_EMAIL_VERIFICATION === 'true';
    
    if (skipVerification) {
      // En mode développement avec vérification désactivée, ignorer silencieusement
      console.warn('⚠️  Email non envoyé (mode développement, vérification désactivée)');
      return false;
    }
    
    console.error('Erreur lors de l\'envoi de l\'email de réinitialisation:', error);
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
    from: buildFromHeader(),
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

// Envoyer un email de rappel d'entretien
const sendMaintenanceReminderEmail = async (email, reminder, vehicle, user) => {
  if (!transporter) {
    console.warn('⚠️  Tentative d\'envoi d\'email mais le transporteur n\'est pas configuré');
    return false;
  }

  const userName = user.firstName 
    ? `${user.firstName} ${user.lastName || ''}`.trim()
    : user.email;

  const vehicleName = vehicle.nickname || `${vehicle.make || ''} ${vehicle.model || ''}`.trim() || 'Véhicule';

  const mailOptions = {
    from: buildFromHeader(),
    to: email,
    subject: `Ride Together - Rappel d'entretien: ${reminder.description || reminder.type}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Rappel d'entretien</h2>
        <p>Bonjour ${userName},</p>
        <p>Il est temps d'effectuer un entretien sur votre <strong>${vehicleName}</strong> :</p>
        <div style="background-color: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px 0;">
          <h3 style="color: #FF6F00; margin-top: 0;">${reminder.description || reminder.type}</h3>
          ${reminder.nextDueKm ? `<p><strong>Échéance kilométrage :</strong> ${reminder.nextDueKm} km</p>` : ''}
          ${reminder.nextDueDate ? `<p><strong>Échéance date :</strong> ${new Date(reminder.nextDueDate).toLocaleDateString('fr-FR')}</p>` : ''}
        </div>
        <p style="color: #999; font-size: 12px; margin-top: 30px;">
          N'oubliez pas de mettre à jour votre garage après l'entretien ! 🔧
        </p>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    return true;
  } catch (error) {
    console.error('Erreur lors de l\'envoi de l\'email de rappel d\'entretien:', error);
    throw error;
  }
};

// Envoyer une alerte d'urgence
const sendEmergencyAlertEmail = async (email, user, reason) => {
  if (!transporter) {
    console.warn('⚠️  Tentative d\'envoi d\'email mais le transporteur n\'est pas configuré');
    return false;
  }

  const userName = user.firstName 
    ? `${user.firstName} ${user.lastName || ''}`.trim()
    : user.email;

  const mailOptions = {
    from: buildFromHeader(),
    to: email,
    subject: `Ride Together - ALERTE URGENCE: ${userName}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #D32F2F;">🚨 ALERTE URGENCE</h2>
        <p><strong>${userName}</strong> a déclenché une alerte d'urgence.</p>
        <div style="background-color: #ffebee; padding: 20px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #D32F2F;">
          <p><strong>Raison :</strong> ${reason || 'Non spécifiée'}</p>
          <p><strong>Date :</strong> ${new Date().toLocaleString('fr-FR')}</p>
        </div>
        <p style="color: #D32F2F; font-weight: bold;">
          Veuillez contacter ${userName} immédiatement.
        </p>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    return true;
  } catch (error) {
    console.error('Erreur lors de l\'envoi de l\'alerte d\'urgence:', error);
    throw error;
  }
};

// Envoyer une alerte d'inactivité
const sendInactivityAlertEmail = async (email, user) => {
  if (!transporter) {
    console.warn('⚠️  Tentative d\'envoi d\'email mais le transporteur n\'est pas configuré');
    return false;
  }

  const userName = user.firstName 
    ? `${user.firstName} ${user.lastName || ''}`.trim()
    : user.email;

  const mailOptions = {
    from: buildFromHeader(),
    to: email,
    subject: `Ride Together - Alerte d'inactivité: ${userName}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #F57C00;">⚠️ Alerte d'inactivité</h2>
        <p>Nous n'avons pas reçu de signal de vie de <strong>${userName}</strong> depuis plus de 30 minutes.</p>
        <div style="background-color: #fff3e0; padding: 20px; border-radius: 5px; margin: 20px 0;">
          <p><strong>Dernier signal :</strong> ${user.checkInStatus?.lastHeartbeat ? new Date(user.checkInStatus.lastHeartbeat).toLocaleString('fr-FR') : 'Inconnu'}</p>
          <p><strong>Date de l'alerte :</strong> ${new Date().toLocaleString('fr-FR')}</p>
        </div>
        <p>Veuillez vérifier que tout va bien.</p>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    return true;
  } catch (error) {
    console.error('Erreur lors de l\'envoi de l\'alerte d\'inactivité:', error);
    throw error;
  }
};

// Envoyer un email de contact au support
const sendContactEmail = async ({ fromEmail, subject, message }) => {
  if (!transporter) {
    console.warn('⚠️  Tentative d\'envoi d\'email mais le transporteur n\'est pas configuré');
    return false;
  }

  const supportEmail = 'kevin.radlowski@gmail.com';
  
  const mailOptions = {
    from: buildFromHeader('Ride Together Contact'),
    to: supportEmail,
    replyTo: fromEmail,
    subject: `[Contact Support] ${subject}`,
    html: `
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Contact Support - ${subject}</title>
      </head>
      <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa;">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color: #f5f7fa;">
          <tr>
            <td align="center" style="padding: 40px 20px;">
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="600" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);">
                <!-- Header -->
                <tr>
                  <td bgcolor="#3F51B5" style="background-color: #3F51B5; padding: 40px; text-align: center;">
                    <h1 style="color: #ffffff; font-size: 28px; font-weight: bold; margin: 0;">Nouveau message de contact</h1>
                  </td>
                </tr>
                <!-- Contenu principal -->
                <tr>
                  <td style="padding: 40px;">
                    <h2 style="color: #212121; font-size: 20px; font-weight: 600; margin: 0 0 20px 0;">Informations du contact</h2>
                    <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 10px 0;">
                      <strong>Email:</strong> ${fromEmail}
                    </p>
                    <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
                      <strong>Sujet:</strong> ${subject}
                    </p>
                    
                    <h2 style="color: #212121; font-size: 20px; font-weight: 600; margin: 30px 0 20px 0;">Message</h2>
                    <div style="background-color: #f5f7fa; padding: 20px; border-radius: 8px; border-left: 4px solid #3F51B5;">
                      <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 0; white-space: pre-wrap;">${message.replace(/\n/g, '<br>')}</p>
                    </div>
                  </td>
                </tr>
                <!-- Footer -->
                <tr>
                  <td style="background-color: #10181F; padding: 30px 40px; text-align: center;">
                    <p style="color: #ffffff; font-size: 14px; margin: 0; opacity: 0.9;">
                      <strong>Ride Together</strong> - Support
                    </p>
                    <p style="color: #ffffff; font-size: 12px; margin: 10px 0 0 0; opacity: 0.7;">
                      Vous pouvez répondre directement à cet email pour contacter l'utilisateur.
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
    console.error('Erreur lors de l\'envoi de l\'email de contact:', error);
    throw error;
  }
};

// Exporter les fonctions ET le transporter
module.exports = {
  sendVerificationEmail,
  sendUnlockEmail,
  sendResetPasswordEmail,
  sendRideReminderEmail,
  sendMaintenanceReminderEmail,
  sendEmergencyAlertEmail,
  sendInactivityAlertEmail,
  sendContactEmail,
  transporter: transporter || { verify: () => {} }
};

