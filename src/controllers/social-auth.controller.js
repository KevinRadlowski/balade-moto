const User = require('../models/User');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { OAuth2Client } = require('google-auth-library');
const axios = require('axios');

// Générer un token JWT
const generateToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: '15m'
  });
};

// Générer un refresh token
const generateRefreshToken = () => {
  return crypto.randomBytes(40).toString('hex');
};

// Générer un pseudo unique à partir d'un email ou nom
const generateUniquePseudo = async (baseName) => {
  let pseudo = baseName.toLowerCase()
    .replace(/[^a-z0-9]/g, '')
    .substring(0, 20);
  
  if (pseudo.length < 3) {
    pseudo = 'user' + Math.random().toString(36).substring(2, 8);
  }
  
  let finalPseudo = pseudo;
  let counter = 1;
  
  while (await User.findOne({ pseudo: finalPseudo })) {
    finalPseudo = `${pseudo}${counter}`;
    counter++;
  }
  
  return finalPseudo;
};

// Vérifier le token Google (ID Token JWT)
// ⚠️ IMPORTANT : Utilise uniquement l'ID Token (JWT), pas l'accessToken
const verifyGoogleToken = async (idToken) => {
  try {
    // ⚠️ CRITIQUE : Le Web Client ID doit être configuré dans GOOGLE_CLIENT_ID
    // Web Client ID: 481162301788-2j9lpcm9s7pkskh9uftkjikg0enavo23.apps.googleusercontent.com
    const clientId = process.env.GOOGLE_CLIENT_ID;
    
    if (!clientId) {
      throw new Error('GOOGLE_CLIENT_ID non configuré dans les variables d\'environnement');
    }
    
    const client = new OAuth2Client(clientId);
    
    // Vérifier le token JWT (signature, expiration, audience, issuer)
    // L'audience doit correspondre au Web Client ID
    const ticket = await client.verifyIdToken({
      idToken: idToken,
      audience: clientId, // Vérifier que l'audience correspond au Web Client ID
    });
    
    // Extraire le payload du token JWT
    const payload = ticket.getPayload();
    
    // Vérifier que le token contient les informations requises
    if (!payload.email) {
      throw new Error('Token Google invalide : email manquant dans le payload');
    }
    
    if (!payload.sub) {
      throw new Error('Token Google invalide : sub (Google User ID) manquant dans le payload');
    }
    
    return payload;
  } catch (error) {
    // Log l'erreur pour le débogage
    console.error('Erreur vérification token Google:', error.message);
    
    // Retourner une erreur plus descriptive
    if (error.message.includes('Token used too early') || 
        error.message.includes('Token used too late')) {
      throw new Error('Token Google expiré ou utilisé trop tôt');
    }
    if (error.message.includes('audience')) {
      throw new Error('Token Google invalide : audience ne correspond pas au Client ID configuré');
    }
    if (error.message.includes('signature')) {
      throw new Error('Token Google invalide : signature invalide');
    }
    
    throw new Error(`Token Google invalide : ${error.message}`);
  }
};

// Vérifier le token Apple
const verifyAppleToken = async (idToken) => {
  // Pour Apple, on utilise la bibliothèque jsonwebtoken avec les clés publiques Apple
  // Note: Cette implémentation est simplifiée. En production, il faudrait vérifier
  // le token avec les clés publiques Apple JWKS
  try {
    // Décoder le token (sans vérification complète pour l'instant)
    const jwt = require('jsonwebtoken');
    const decoded = jwt.decode(idToken, { complete: true });
    
    if (!decoded || decoded.payload.iss !== 'https://appleid.apple.com') {
      throw new Error('Token Apple invalide');
    }
    
    return decoded.payload;
  } catch (error) {
    throw new Error('Token Apple invalide');
  }
};

// Obtenir les informations utilisateur depuis l'accessToken via userinfo API
// ⚠️ IMPORTANT : userinfo API est différente de People API et ne nécessite pas d'activation
const getUserInfoFromAccessToken = async (accessToken) => {
  try {
    const response = await axios.get(
      'https://www.googleapis.com/oauth2/v2/userinfo',
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      }
    );
    
    return {
      email: response.data.email,
      sub: response.data.id, // Google User ID
      given_name: response.data.given_name,
      family_name: response.data.family_name,
      picture: response.data.picture,
      verified_email: response.data.verified_email
    };
  } catch (error) {
    // 🔍 DEBUG : Logs détaillés de l'erreur axios
    console.error('🔍 [DEBUG getUserInfoFromAccessToken] Erreur lors de la récupération des infos utilisateur:');
    console.error(`   - error.message: ${error.message}`);
    if (error.response) {
      console.error(`   - error.response.status: ${error.response.status}`);
      console.error(`   - error.response.data:`, error.response.data);
    } else {
      console.error('   - Pas de response dans l\'erreur (erreur réseau probable)');
    }
    throw new Error('Impossible de récupérer les informations utilisateur depuis Google');
  }
};

// Vérifier le token Facebook
const verifyFacebookToken = async (accessToken) => {
  try {
    const response = await axios.get(
      `https://graph.facebook.com/me?fields=id,email,first_name,last_name,picture&access_token=${accessToken}`
    );
    
    if (response.data.error) {
      throw new Error('Token Facebook invalide');
    }
    
    return response.data;
  } catch (error) {
    throw new Error('Token Facebook invalide');
  }
};

// Connexion/Inscription Google
exports.googleAuth = async (req, res, next) => {
  try {
    const { idToken, accessToken } = req.body;
    
    // 🔍 DEBUG : Logs des tokens reçus (tronqués pour la sécurité)
    console.log('🔍 [DEBUG googleAuth] Tokens reçus:');
    console.log(`   - idToken présent?: ${idToken ? 'OUI' : 'NON'}`);
    if (idToken) {
      console.log(`   - idToken (10 premiers chars): ${idToken.substring(0, Math.min(10, idToken.length))}...`);
    }
    console.log(`   - accessToken présent?: ${accessToken ? 'OUI' : 'NON'}`);
    if (accessToken) {
      console.log(`   - accessToken (10 premiers chars): ${accessToken.substring(0, Math.min(10, accessToken.length))}...`);
    }
    
    // ⚠️ PROBLÈME CONNU : Sur Flutter Web, google_sign_in ne retourne pas toujours l'idToken
    // Solution : Accepter soit idToken (JWT préféré), soit accessToken (fallback pour web)
    if (!idToken && !accessToken) {
      return res.status(400).json({
        success: false,
        message: 'ID Token ou Access Token Google requis'
      });
    }
    
    let googleUser;
    
    // Préférer l'idToken (JWT) si disponible
    if (idToken) {
      // Vérifier le token JWT et extraire les informations depuis le payload
      // ⚠️ IMPORTANT : Ne pas faire d'appel à l'API People (people.googleapis.com)
      // Toutes les informations sont disponibles dans le payload du token JWT
      googleUser = await verifyGoogleToken(idToken);
    } else {
      // Fallback : utiliser l'accessToken pour obtenir les infos via userinfo API
      // ⚠️ IMPORTANT : userinfo API est différente de People API et ne nécessite pas d'activation
      console.log('⚠️ ID Token manquant, utilisation de l\'accessToken via userinfo API');
      googleUser = await getUserInfoFromAccessToken(accessToken);
    }
    
    // Extraire les informations depuis le payload du token JWT
    // Ces champs sont disponibles directement dans le token, pas besoin de l'API People
    const email = googleUser.email;
    const providerId = googleUser.sub; // Google User ID
    const firstName = googleUser.given_name; // Prénom depuis le token
    const lastName = googleUser.family_name; // Nom depuis le token
    const picture = googleUser.picture; // Photo depuis le token
    
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email non disponible depuis Google'
      });
    }
    
    // Chercher ou créer l'utilisateur
    let user = await User.findOne({
      $or: [
        { email: email.toLowerCase() },
        { providerId: providerId, authProvider: 'google' }
      ]
    });
    
    if (user) {
      // Vérifier si l'utilisateur est banni
      if (user.banned) {
        return res.status(403).json({
          success: false,
          message: 'Votre compte a été banni. Veuillez contacter le support pour plus d\'informations.',
          banned: true
        });
      }
      
      // Mettre à jour les informations si nécessaire
      if (!user.authProvider) {
        user.authProvider = 'google';
        user.providerId = providerId;
        user.emailVerified = true;
      }
      if (picture && !user.avatarUrl) {
        user.avatarUrl = picture;
      }
      if (firstName && !user.firstName) {
        user.firstName = firstName;
      }
      if (lastName && !user.lastName) {
        user.lastName = lastName;
      }
      await user.save();
    } else {
      // Créer un nouvel utilisateur
      const pseudo = await generateUniquePseudo(firstName || email.split('@')[0]);
      
      user = new User({
        email: email.toLowerCase(),
        authProvider: 'google',
        providerId: providerId,
        firstName: firstName || null,
        lastName: lastName || null,
        pseudo: pseudo,
        avatarUrl: picture || null,
        emailVerified: true, // Google vérifie déjà l'email
        role: 'MEMBER', // Rôle valide selon le schéma
        phoneE164: null, // Pas de téléphone pour OAuth - sera demandé plus tard
        status: 'pending_phone_verification' // Statut en attente de téléphone
      });
      
      await user.save();
    }
    
    // Générer les tokens
    const token = generateToken(user._id);
    const refreshToken = generateRefreshToken();
    
    user.refreshToken = refreshToken;
    await user.save();
    
    res.status(200).json({
      success: true,
      message: 'Connexion réussie',
      data: {
        token,
        refreshToken,
        user: {
          id: user._id,
          email: user.email,
          pseudo: user.pseudo,
          firstName: user.firstName,
          lastName: user.lastName,
          avatarUrl: user.avatarUrl,
          role: user.role,
          emailVerified: user.emailVerified,
          banned: user.banned || false
        }
      }
    });
  } catch (error) {
    console.error('Erreur Google Auth:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Erreur lors de l\'authentification Google'
    });
  }
};

// Connexion/Inscription Apple
exports.appleAuth = async (req, res, next) => {
  try {
    const { idToken, firstName, lastName, email } = req.body;
    
    if (!idToken) {
      return res.status(400).json({
        success: false,
        message: 'Token Apple requis'
      });
    }
    
    // Vérifier le token
    const appleUser = await verifyAppleToken(idToken);
    
    const providerId = appleUser.sub;
    const userEmail = email || appleUser.email;
    
    if (!userEmail) {
      return res.status(400).json({
        success: false,
        message: 'Email non disponible depuis Apple'
      });
    }
    
    // Chercher ou créer l'utilisateur
    let user = await User.findOne({
      $or: [
        { email: userEmail.toLowerCase() },
        { providerId: providerId, authProvider: 'apple' }
      ]
    });
    
    if (user) {
      // Vérifier si l'utilisateur est banni
      if (user.banned) {
        return res.status(403).json({
          success: false,
          message: 'Votre compte a été banni. Veuillez contacter le support pour plus d\'informations.',
          banned: true
        });
      }
      
      // Mettre à jour les informations si nécessaire
      if (!user.authProvider) {
        user.authProvider = 'apple';
        user.providerId = providerId;
        user.emailVerified = true;
      }
      if (firstName && !user.firstName) {
        user.firstName = firstName;
      }
      if (lastName && !user.lastName) {
        user.lastName = lastName;
      }
      await user.save();
    } else {
      // Créer un nouvel utilisateur
      const pseudo = await generateUniquePseudo(firstName || userEmail.split('@')[0]);
      
      user = new User({
        email: userEmail.toLowerCase(),
        authProvider: 'apple',
        providerId: providerId,
        firstName: firstName || null,
        lastName: lastName || null,
        pseudo: pseudo,
        emailVerified: true, // Apple vérifie déjà l'email
        role: 'MEMBER', // Rôle valide selon le schéma
        phoneE164: null, // Pas de téléphone pour OAuth - sera demandé plus tard
        status: 'pending_phone_verification' // Statut en attente de téléphone
      });
      
      await user.save();
    }
    
    // Générer les tokens
    const token = generateToken(user._id);
    const refreshToken = generateRefreshToken();
    
    user.refreshToken = refreshToken;
    await user.save();
    
    res.status(200).json({
      success: true,
      message: 'Connexion réussie',
      data: {
        token,
        refreshToken,
        user: {
          id: user._id,
          email: user.email,
          pseudo: user.pseudo,
          firstName: user.firstName,
          lastName: user.lastName,
          avatarUrl: user.avatarUrl,
          role: user.role,
          emailVerified: user.emailVerified,
          banned: user.banned || false
        }
      }
    });
  } catch (error) {
    console.error('Erreur Apple Auth:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Erreur lors de l\'authentification Apple'
    });
  }
};

// Connexion/Inscription Facebook
exports.facebookAuth = async (req, res, next) => {
  try {
    const { accessToken, email, firstName, lastName } = req.body;
    
    if (!accessToken) {
      return res.status(400).json({
        success: false,
        message: 'Token Facebook requis'
      });
    }
    
    // Vérifier le token
    const facebookUser = await verifyFacebookToken(accessToken);
    
    const providerId = facebookUser.id;
    const userEmail = email || facebookUser.email;
    
    if (!userEmail) {
      return res.status(400).json({
        success: false,
        message: 'Email non disponible depuis Facebook'
      });
    }
    
    // Chercher ou créer l'utilisateur
    let user = await User.findOne({
      $or: [
        { email: userEmail.toLowerCase() },
        { providerId: providerId, authProvider: 'facebook' }
      ]
    });
    
    if (user) {
      // Vérifier si l'utilisateur est banni
      if (user.banned) {
        return res.status(403).json({
          success: false,
          message: 'Votre compte a été banni. Veuillez contacter le support pour plus d\'informations.',
          banned: true
        });
      }
      
      // Mettre à jour les informations si nécessaire
      if (!user.authProvider) {
        user.authProvider = 'facebook';
        user.providerId = providerId;
        user.emailVerified = true;
      }
      if (facebookUser.picture?.data?.url && !user.avatarUrl) {
        user.avatarUrl = facebookUser.picture.data.url;
      }
      if (firstName && !user.firstName) {
        user.firstName = firstName;
      }
      if (lastName && !user.lastName) {
        user.lastName = lastName;
      }
      await user.save();
    } else {
      // Créer un nouvel utilisateur
      const pseudo = await generateUniquePseudo(firstName || userEmail.split('@')[0]);
      
      user = new User({
        email: userEmail.toLowerCase(),
        authProvider: 'facebook',
        providerId: providerId,
        firstName: firstName || facebookUser.first_name || null,
        lastName: lastName || facebookUser.last_name || null,
        pseudo: pseudo,
        avatarUrl: facebookUser.picture?.data?.url || null,
        emailVerified: true, // Facebook vérifie déjà l'email
        role: 'MEMBER', // Rôle valide selon le schéma
        phoneE164: null, // Pas de téléphone pour OAuth - sera demandé plus tard
        status: 'pending_phone_verification' // Statut en attente de téléphone
      });
      
      await user.save();
    }
    
    // Générer les tokens
    const token = generateToken(user._id);
    const refreshToken = generateRefreshToken();
    
    user.refreshToken = refreshToken;
    await user.save();
    
    res.status(200).json({
      success: true,
      message: 'Connexion réussie',
      data: {
        token,
        refreshToken,
        user: {
          id: user._id,
          email: user.email,
          pseudo: user.pseudo,
          firstName: user.firstName,
          lastName: user.lastName,
          avatarUrl: user.avatarUrl,
          role: user.role,
          emailVerified: user.emailVerified,
          banned: user.banned || false
        }
      }
    });
  } catch (error) {
    console.error('Erreur Facebook Auth:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Erreur lors de l\'authentification Facebook'
    });
  }
};

