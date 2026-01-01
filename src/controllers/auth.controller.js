const User = require('../models/User');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const speakeasy = require('speakeasy');
const QRCode = require('qrcode');
const emailService = require('../services/email.service');
const { ConflictError, UnauthorizedError, NotFoundError, BadRequestError } = require('../utils/errors');
const { buildUserAvatarUrl } = require('../utils/urlHelper');

// Générer un token JWT
const generateToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: '15m' // 15 minutes
  });
};

// Générer un refresh token
const generateRefreshToken = () => {
  return crypto.randomBytes(40).toString('hex');
};

// Générer un token de vérification email
const generateEmailVerificationToken = () => {
  return crypto.randomBytes(32).toString('hex');
};

// Inscription
exports.register = async (req, res, next) => {
  try {
    const { email, password, pseudo } = req.body;

    // Normaliser l'email (comme Mongoose le fait avec lowercase: true)
    const normalizedEmail = email.toLowerCase().trim();

    // Vérifier si l'email ou le pseudo existe déjà
    const existingUserByEmail = await User.findOne({ email: normalizedEmail });
    if (existingUserByEmail) {
      throw new ConflictError('Cet email est déjà utilisé');
    }

    const existingUserByPseudo = await User.findOne({ pseudo: pseudo.trim() });
    if (existingUserByPseudo) {
      throw new ConflictError('Ce pseudo est déjà utilisé');
    }

    // Générer un token de vérification email
    const emailVerificationToken = generateEmailVerificationToken();
    const emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000; // 24 heures

    // Créer un nouvel utilisateur (le mot de passe sera hashé automatiquement par le pre-save hook)
    const user = new User({
      email: normalizedEmail, // Utiliser l'email normalisé
      password,
      pseudo: pseudo.trim(),
      role: 'user',
      emailVerified: false,
      emailVerificationToken,
      emailVerificationExpires,
      emailVerificationLastSent: new Date()
    });

    await user.save();

    // Envoyer l'email de vérification
    try {
      await emailService.sendVerificationEmail(email, emailVerificationToken);
    } catch (emailError) {
      console.error('Erreur envoi email:', emailError);
      // On continue même si l'email échoue, l'utilisateur peut demander un renvoi
    }

    res.status(201).json({
      success: true,
      message: 'Utilisateur créé avec succès. Un email de vérification a été envoyé.',
      data: {
        user: {
          id: user._id,
          email: user.email,
          role: user.role,
          emailVerified: user.emailVerified
        }
      }
    });
  } catch (error) {
    if (error.name === 'ValidationError') {
      return res.status(400).json({
        success: false,
        message: 'Erreur de validation',
        errors: Object.values(error.errors).map(err => err.message)
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'inscription',
      error: error.message
    });
  }
};

// Renvoyer l'email de vérification
exports.resendVerificationEmail = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'L\'email est requis'
      });
    }

    // Normaliser l'email pour la recherche
    const normalizedEmail = email.toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      // Ne pas révéler si l'email existe ou non pour la sécurité
      return res.status(200).json({
        success: true,
        message: 'Si cet email existe et n\'est pas vérifié, un email de vérification a été envoyé'
      });
    }

    // Vérifier si l'email est déjà vérifié
    if (user.emailVerified) {
      return res.status(400).json({
        success: false,
        message: 'Cet email est déjà vérifié'
      });
    }

    // Vérifier le cooldown de 60 secondes
    if (user.emailVerificationLastSent) {
      const timeSinceLastSent = Date.now() - user.emailVerificationLastSent.getTime();
      const cooldownTime = 60 * 1000; // 60 secondes en millisecondes
      
      if (timeSinceLastSent < cooldownTime) {
        const remainingSeconds = Math.ceil((cooldownTime - timeSinceLastSent) / 1000);
        return res.status(429).json({
          success: false,
          message: `Veuillez attendre ${remainingSeconds} seconde(s) avant de renvoyer l'email`,
          retryAfter: remainingSeconds
        });
      }
    }

    // Générer un nouveau token de vérification
    const emailVerificationToken = generateEmailVerificationToken();
    const emailVerificationExpires = Date.now() + 24 * 60 * 60 * 1000; // 24 heures

    // Mettre à jour l'utilisateur
    user.emailVerificationToken = emailVerificationToken;
    user.emailVerificationExpires = emailVerificationExpires;
    user.emailVerificationLastSent = new Date();
    await user.save();

    // Envoyer l'email de vérification
    try {
      await emailService.sendVerificationEmail(email, emailVerificationToken);
    } catch (emailError) {
      console.error('Erreur envoi email:', emailError);
      return res.status(500).json({
        success: false,
        message: 'Erreur lors de l\'envoi de l\'email. Veuillez réessayer plus tard.'
      });
    }

    res.status(200).json({
      success: true,
      message: 'Email de vérification renvoyé avec succès'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors du renvoi de l\'email de vérification',
      error: error.message
    });
  }
};

// Vérification de l'email
exports.verifyEmail = async (req, res) => {
  try {
    // Accepter le token depuis query (GET) ou body (POST)
    const token = (req.query.token || req.body.token || '').trim();

    console.log('Tentative de vérification email avec token:', token ? token.substring(0, 20) + '...' : 'manquant');

    if (!token) {
      return res.status(400).json({
        success: false,
        message: 'Token de vérification manquant'
      });
    }

    // Chercher l'utilisateur avec ce token
    const user = await User.findOne({
      emailVerificationToken: token
    });

    console.log('Utilisateur trouvé:', user ? `Oui (${user.email}, vérifié: ${user.emailVerified})` : 'Non');

    if (!user) {
      console.log('Token non trouvé dans la base de données');
      return res.status(400).json({
        success: false,
        message: 'Token invalide'
      });
    }

    // Vérifier si le token a expiré
    if (user.emailVerificationExpires && user.emailVerificationExpires < Date.now()) {
      console.log('Token expiré');
      return res.status(400).json({
        success: false,
        message: 'Token expiré. Veuillez demander un nouvel email de vérification.'
      });
    }

    // Vérifier si l'email est déjà vérifié
    if (user.emailVerified) {
      console.log('Email déjà vérifié');
      // Si c'est GET, retourner une page HTML
      if (req.method === 'GET') {
        return res.status(200).send(`
          <!DOCTYPE html>
          <html>
          <head>
            <title>Email déjà vérifié</title>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
              body {
                font-family: Arial, sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
                margin: 0;
                background-color: #f5f5f5;
              }
              .container {
                background: white;
                padding: 40px;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                text-align: center;
                max-width: 500px;
              }
              .info {
                color: #2196F3;
                font-size: 48px;
                margin-bottom: 20px;
              }
              h1 {
                color: #333;
                margin-bottom: 20px;
              }
              p {
                color: #666;
                line-height: 1.6;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="info">ℹ</div>
              <h1>Email déjà vérifié</h1>
              <p>Votre compte a déjà été activé. Vous pouvez vous connecter à l'application.</p>
            </div>
          </body>
          </html>
        `);
      }
      return res.status(200).json({
        success: true,
        message: 'Email déjà vérifié'
      });
    }

    // Vérifier l'email
    user.emailVerified = true;
    user.emailVerificationToken = null;
    user.emailVerificationExpires = null;
    user.emailVerificationLastSent = null;
    await user.save();
    
    console.log('Email vérifié avec succès pour:', user.email);

    // Si c'est une requête GET (depuis le lien email), retourner une page HTML
    if (req.method === 'GET') {
      return res.status(200).send(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>Email vérifié</title>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body {
              font-family: Arial, sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              min-height: 100vh;
              margin: 0;
              background-color: #f5f5f5;
            }
            .container {
              background: white;
              padding: 40px;
              border-radius: 10px;
              box-shadow: 0 2px 10px rgba(0,0,0,0.1);
              text-align: center;
              max-width: 500px;
            }
            .success {
              color: #4CAF50;
              font-size: 48px;
              margin-bottom: 20px;
            }
            h1 {
              color: #333;
              margin-bottom: 20px;
            }
            p {
              color: #666;
              line-height: 1.6;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="success">✓</div>
            <h1>Email vérifié avec succès !</h1>
            <p>Votre compte a été activé. Vous pouvez maintenant vous connecter à l'application.</p>
          </div>
        </body>
        </html>
      `);
    }

    // Si c'est une requête POST (depuis l'app), retourner du JSON
    res.status(200).json({
      success: true,
      message: 'Email vérifié avec succès'
    });
  } catch (error) {
    console.error('Erreur lors de la vérification de l\'email:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la vérification',
      error: error.message
    });
  }
};

// Connexion
exports.login = async (req, res) => {
  try {
    const { email, password, totpCode } = req.body;

    // Vérifier que l'email et le mot de passe sont fournis
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez fournir un email et un mot de passe'
      });
    }

    // Trouver l'utilisateur par email (normaliser en minuscules pour correspondre au schéma)
    const normalizedEmail = email.toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Email ou mot de passe incorrect'
      });
    }

    // Vérifier si le compte est verrouillé
    if (user.isLocked()) {
      const remainingTime = Math.ceil((user.lockUntil - Date.now()) / 1000 / 60);
      return res.status(423).json({
        success: false,
        message: `Compte verrouillé. Réessayez dans ${remainingTime} minute(s)`,
        locked: true
      });
    }

    // Vérifier le mot de passe
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      // Sauvegarder le nombre de tentatives avant incrémentation
      const attemptsBefore = user.loginAttempts;
      
      // Incrémenter les tentatives de connexion
      await user.incLoginAttempts();
      
      // Recharger l'utilisateur pour obtenir les valeurs mises à jour
      const updatedUser = await User.findById(user._id);
      
      // Si le compte vient d'être verrouillé (5ème tentative), envoyer un email
      if (attemptsBefore === 4 && updatedUser.isLocked()) {
        const unlockToken = generateEmailVerificationToken();
        updatedUser.emailVerificationToken = unlockToken;
        updatedUser.emailVerificationExpires = Date.now() + 60 * 60 * 1000; // 1 heure
        await updatedUser.save();
        
        try {
          await emailService.sendUnlockEmail(email, unlockToken);
        } catch (emailError) {
          console.error('Erreur envoi email déverrouillage:', emailError);
        }
      }
      
      return res.status(401).json({
        success: false,
        message: 'Email ou mot de passe incorrect'
      });
    }

    // Vérifier si l'email est vérifié
    if (!user.emailVerified) {
      return res.status(403).json({
        success: false,
        message: 'Veuillez vérifier votre email avant de vous connecter. Si vous n\'avez pas reçu l\'email, vous pouvez le renvoyer.',
        emailVerified: false
      });
    }

    // Vérifier le code 2FA si activé
    if (user.twoFactorEnabled || user.isTwoFactorEnabled) {
      if (!totpCode) {
        return res.status(200).json({
          success: false,
          message: 'Code 2FA requis',
          requires2FA: true
        });
      }

      const verified = speakeasy.totp.verify({
        secret: user.twoFactorSecret,
        encoding: 'base32',
        token: totpCode,
        window: 2 // Tolérance de 2 périodes (60 secondes)
      });

      if (!verified) {
        return res.status(401).json({
          success: false,
          message: 'Code 2FA invalide'
        });
      }
    }

    // Réinitialiser les tentatives de connexion
    await user.resetLoginAttempts();

    // Générer les tokens
    const token = generateToken(user._id);
    const refreshToken = generateRefreshToken();

    // Rotation du refresh token : invalider l'ancien et sauvegarder le nouveau
    user.refreshToken = refreshToken;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Connexion réussie',
      data: {
        user: {
          id: user._id,
          email: user.email,
          role: user.role,
          roles: user.roles,
          twoFactorEnabled: user.twoFactorEnabled || user.isTwoFactorEnabled,
          isTwoFactorEnabled: user.isTwoFactorEnabled || user.twoFactorEnabled,
          twoFactorMethod: user.twoFactorMethod
        },
        token,
        refreshToken
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la connexion',
      error: error.message
    });
  }
};

// Déverrouiller le compte
exports.unlockAccount = async (req, res) => {
  try {
    const { token } = req.query;

    if (!token) {
      return res.status(400).json({
        success: false,
        message: 'Token de déverrouillage manquant'
      });
    }

    const user = await User.findOne({
      emailVerificationToken: token,
      emailVerificationExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'Token invalide ou expiré'
      });
    }

    // Déverrouiller le compte
    await user.resetLoginAttempts();
    user.emailVerificationToken = null;
    user.emailVerificationExpires = null;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Compte déverrouillé avec succès'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors du déverrouillage',
      error: error.message
    });
  }
};

// Activer la 2FA
exports.enable2FA = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

    if (user.twoFactorEnabled || user.isTwoFactorEnabled) {
      return res.status(400).json({
        success: false,
        message: 'La 2FA est déjà activée'
      });
    }

    // Générer un secret pour l'utilisateur
    const secret = speakeasy.generateSecret({
      name: `Balades Moto (${user.email})`,
      issuer: 'Balades Moto'
    });

    // Sauvegarder le secret temporairement (pas encore activé)
    user.twoFactorSecret = secret.base32;
    await user.save();

    // Générer le QR code
    const qrCodeUrl = await QRCode.toDataURL(secret.otpauth_url);

    res.status(200).json({
      success: true,
      message: 'Scannez le QR code avec votre application d\'authentification',
      data: {
        qrCode: qrCodeUrl,
        secret: secret.base32, // Pour test manuel si nécessaire
        manualEntryKey: secret.base32
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'activation de la 2FA',
      error: error.message
    });
  }
};

// Vérifier et activer définitivement la 2FA
exports.verify2FA = async (req, res) => {
  try {
    const { totpCode } = req.body;

    if (!totpCode) {
      return res.status(400).json({
        success: false,
        message: 'Code TOTP requis'
      });
    }

    const user = await User.findById(req.user._id);

    if (!user.twoFactorSecret) {
      return res.status(400).json({
        success: false,
        message: 'Veuillez d\'abord activer la 2FA'
      });
    }

    if (user.twoFactorEnabled || user.isTwoFactorEnabled) {
      return res.status(400).json({
        success: false,
        message: 'La 2FA est déjà activée'
      });
    }

    // Vérifier le code
    const verified = speakeasy.totp.verify({
      secret: user.twoFactorSecret,
      encoding: 'base32',
      token: totpCode,
      window: 2
    });

    if (!verified) {
      return res.status(401).json({
        success: false,
        message: 'Code TOTP invalide'
      });
    }

    // Activer définitivement la 2FA
    user.twoFactorEnabled = true;
    user.isTwoFactorEnabled = true;
    user.twoFactorMethod = 'totp';
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Authentification à deux facteurs activée avec succès'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la vérification de la 2FA',
      error: error.message
    });
  }
};

// Désactiver la 2FA
exports.disable2FA = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

    if (!user.twoFactorEnabled && !user.isTwoFactorEnabled) {
      return res.status(400).json({
        success: false,
        message: 'La 2FA n\'est pas activée'
      });
    }

    user.twoFactorEnabled = false;
    user.isTwoFactorEnabled = false;
    user.twoFactorMethod = null;
    user.twoFactorSecret = null;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Authentification à deux facteurs désactivée'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la désactivation de la 2FA',
      error: error.message
    });
  }
};

// Déconnexion
exports.logout = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    
    // Supprimer le refresh token
    user.refreshToken = null;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Déconnexion réussie'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la déconnexion',
      error: error.message
    });
  }
};

// Rafraîchir le token (avec rotation)
exports.refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        message: 'Refresh token manquant'
      });
    }

    // Trouver l'utilisateur avec ce refresh token
    const user = await User.findOne({ refreshToken });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Refresh token invalide'
      });
    }

    // Générer un nouveau access token
    const newToken = generateToken(user._id);
    
    // Rotation : générer un nouveau refresh token et invalider l'ancien
    const newRefreshToken = generateRefreshToken();
    user.refreshToken = newRefreshToken;
    await user.save();

    res.status(200).json({
      success: true,
      data: {
        token: newToken,
        refreshToken: newRefreshToken
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors du rafraîchissement du token',
      error: error.message
    });
  }
};

// Obtenir les informations de l'utilisateur connecté

exports.getMe = async (req, res) => {
  try {
    // L'utilisateur est déjà attaché à la requête par le middleware auth
    // Construire l'URL complète de l'avatar en passant la requête pour détecter l'IP
    buildUserAvatarUrl(req.user, req);

    res.status(200).json({
      success: true,
      data: {
        user: {
          id: req.user._id,
          email: req.user.email,
          firstName: req.user.firstName,
          lastName: req.user.lastName,
          pseudo: req.user.pseudo,
          vehiclePreference: req.user.vehiclePreference,
          avatarUrl: req.user.avatarUrl,
          role: req.user.role,
          roles: req.user.roles,
          emailVerified: req.user.emailVerified,
          twoFactorEnabled: req.user.twoFactorEnabled || req.user.isTwoFactorEnabled,
          isTwoFactorEnabled: req.user.isTwoFactorEnabled || req.user.twoFactorEnabled,
          twoFactorMethod: req.user.twoFactorMethod,
          createdAt: req.user.createdAt,
          updatedAt: req.user.updatedAt
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des informations',
      error: error.message
    });
  }
};
