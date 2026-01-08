const User = require('../models/User');
const bcrypt = require('bcryptjs');
const path = require('path');
const fs = require('fs');
const { getBaseUrl, buildFileUrl } = require('../utils/urlHelper');
const subscriptionService = require('../services/subscription.service');
const premiumConfig = require('../config/premium.config');
const planQuotaService = require('../services/planQuota.service');
const promoCodeService = require('../services/promoCode.service');

// Mettre à jour le profil utilisateur
exports.updateProfile = async (req, res) => {
  try {
    const { firstName, lastName, pseudo, vehiclePreference, email, avatarUrl, customBackgrounds } = req.body;
    const userId = req.user._id;

    // Vérifier que l'utilisateur existe
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Vérifier si le pseudo est déjà utilisé par un autre utilisateur
    if (pseudo && pseudo !== user.pseudo) {
      const existingUser = await User.findOne({ pseudo, _id: { $ne: userId } });
      if (existingUser) {
        return res.status(400).json({
          success: false,
          message: 'Ce pseudo est déjà utilisé'
        });
      }
    }

    // Vérifier si l'email est déjà utilisé par un autre utilisateur
    if (email && email !== user.email) {
      const existingUser = await User.findOne({ email: email.toLowerCase(), _id: { $ne: userId } });
      if (existingUser) {
        return res.status(400).json({
          success: false,
          message: 'Cet email est déjà utilisé'
        });
      }
      // Valider le format de l'email
      const emailRegex = /^\S+@\S+\.\S+$/;
      if (!emailRegex.test(email)) {
        return res.status(400).json({
          success: false,
          message: 'Format d\'email invalide'
        });
      }
    }

    // Valider la préférence de véhicule
    if (vehiclePreference && !['moto', 'voiture', 'les deux'].includes(vehiclePreference)) {
      return res.status(400).json({
        success: false,
        message: 'Préférence de véhicule invalide. Valeurs acceptées : moto, voiture, les deux'
      });
    }

    // Mettre à jour les champs fournis
    if (firstName !== undefined) user.firstName = firstName;
    if (lastName !== undefined) user.lastName = lastName;
    if (pseudo !== undefined) user.pseudo = pseudo;
    if (vehiclePreference !== undefined) user.vehiclePreference = vehiclePreference;
    if (email !== undefined) {
      user.email = email.toLowerCase().trim();
      // Si l'email change, réinitialiser la vérification
      if (email !== user.email) {
        user.emailVerified = false;
      }
    }
    if (avatarUrl !== undefined) user.avatarUrl = avatarUrl;
    
    // Mettre à jour les backgrounds personnalisés si fournis
    if (customBackgrounds !== undefined) {
      if (customBackgrounds.balade !== undefined) {
        user.customBackgrounds.balade = customBackgrounds.balade;
      }
      if (customBackgrounds.groupe !== undefined) {
        user.customBackgrounds.groupe = customBackgrounds.groupe;
      }
      if (customBackgrounds.profil !== undefined) {
        user.customBackgrounds.profil = customBackgrounds.profil;
      }
      if (customBackgrounds.global !== undefined) {
        user.customBackgrounds.global = customBackgrounds.global;
      }
    }

    await user.save();

    // Construire l'URL complète de l'avatar si nécessaire
    const baseUrl = getBaseUrl(req);
    if (user.avatarUrl && !user.avatarUrl.startsWith('http')) {
      user.avatarUrl = buildFileUrl(user.avatarUrl, req);
    }

    // Construire les URLs complètes des backgrounds personnalisés
    const formattedCustomBackgrounds = user.customBackgrounds ? {
      balade: buildFileUrl(user.customBackgrounds.balade, req),
      groupe: buildFileUrl(user.customBackgrounds.groupe, req),
      profil: buildFileUrl(user.customBackgrounds.profil, req),
      global: buildFileUrl(user.customBackgrounds.global, req)
    } : null;

    res.status(200).json({
      success: true,
      message: 'Profil mis à jour avec succès',
      data: {
        user: {
          id: user._id,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          pseudo: user.pseudo,
          vehiclePreference: user.vehiclePreference,
          avatarUrl: user.avatarUrl,
          customBackgrounds: formattedCustomBackgrounds,
          role: user.role,
          roles: user.roles,
          emailVerified: user.emailVerified,
          isTwoFactorEnabled: user.isTwoFactorEnabled,
          twoFactorMethod: user.twoFactorMethod
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
    if (error.code === 11000) {
      // Erreur de duplication (pseudo unique)
      return res.status(400).json({
        success: false,
        message: 'Ce pseudo est déjà utilisé'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise à jour du profil',
      error: error.message
    });
  }
};

// Changer le mot de passe
exports.changePassword = async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    const userId = req.user._id;

    // Vérifier que tous les champs sont fournis
    if (!oldPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'L\'ancien mot de passe et le nouveau mot de passe sont requis'
      });
    }

    // Vérifier la longueur du nouveau mot de passe
    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Le nouveau mot de passe doit contenir au moins 6 caractères'
      });
    }

    // Récupérer l'utilisateur avec le mot de passe (nécessaire pour la comparaison)
    const user = await User.findById(userId).select('+password');
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Vérifier l'ancien mot de passe
    const isOldPasswordValid = await user.comparePassword(oldPassword);
    if (!isOldPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Ancien mot de passe incorrect'
      });
    }

    // Vérifier que le nouveau mot de passe est différent de l'ancien
    const isSamePassword = await user.comparePassword(newPassword);
    if (isSamePassword) {
      return res.status(400).json({
        success: false,
        message: 'Le nouveau mot de passe doit être différent de l\'ancien'
      });
    }

    // Mettre à jour le mot de passe (sera hashé automatiquement par le pre-save hook)
    user.password = newPassword;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Mot de passe modifié avec succès'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors du changement de mot de passe',
      error: error.message
    });
  }
};

// Supprimer le compte utilisateur (soft delete)
exports.deleteAccount = async (req, res) => {
  try {
    const userId = req.user._id;

    // Récupérer l'utilisateur
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Vérifier si déjà supprimé
    if (user.isDeleted) {
      return res.status(400).json({
        success: false,
        message: 'Ce compte est déjà supprimé'
      });
    }

    // Soft delete : anonymiser et marquer comme supprimé
    const now = new Date();
    const deletedEmail = `deleted+${userId.toString()}@invalid.local`;
    const deletedPseudo = `deleted_user_${userId.toString().substring(0, 8)}`;
    
    // Anonymiser les données sensibles
    user.isDeleted = true;
    user.deletedAt = now;
    user.anonymizedAt = now;
    
    // Anonymiser les informations personnelles
    user.email = deletedEmail;
    // Utiliser un pseudo valide (lettres, chiffres, tirets, underscores uniquement)
    user.pseudo = deletedPseudo;
    user.firstName = null;
    user.lastName = null;
    
    // Pour phoneE164 : si requis (pas d'authProvider), mettre un placeholder valide
    // Sinon, mettre null si OAuth
    if (!user.authProvider) {
      // Si pas d'OAuth, phoneE164 est requis, donc on met un placeholder
      user.phoneE164 = '+33000000000'; // Placeholder valide
    } else {
      // Si OAuth, phoneE164 n'est pas requis, on peut mettre null
      user.phoneE164 = null;
    }
    
    user.avatarUrl = null;
    
    // Invalider les tokens et sessions
    user.refreshToken = null;
    user.emailVerificationToken = null;
    user.resetPasswordToken = null;
    
    // Désactiver l'authentification à deux facteurs
    user.twoFactorEnabled = false;
    user.isTwoFactorEnabled = false;
    user.twoFactorSecret = null;
    
    // Réinitialiser le statut de check-in
    if (user.checkInStatus) {
      user.checkInStatus.isActive = false;
      user.checkInStatus.lastHeartbeat = null;
      user.checkInStatus.lastLocation = null;
    }

    // Sauvegarder les modifications principales
    await user.save({ validateBeforeSave: false });
    
    // Supprimer complètement emergencyContact avec $unset pour éviter les erreurs de validation
    if (user.emergencyContact) {
      await User.updateOne(
        { _id: userId },
        { $unset: { emergencyContact: '' } }
      );
    }

    res.status(200).json({
      success: true,
      message: 'Compte supprimé avec succès'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la suppression du compte',
      error: error.message
    });
  }
};

// Uploader un background personnalisé
exports.uploadBackground = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Aucun fichier fourni'
      });
    }

    const { type } = req.body; // balade, groupe, profil, global
    if (!type || !['balade', 'groupe', 'profil', 'global'].includes(type)) {
      return res.status(400).json({
        success: false,
        message: 'Type de background invalide. Valeurs acceptées : balade, groupe, profil, global'
      });
    }

    const userId = req.user._id;
    const user = await User.findById(userId);
    if (!user) {
      // Supprimer le fichier uploadé si l'utilisateur n'existe pas
      fs.unlinkSync(req.file.path);
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Supprimer l'ancien background s'il existe
    if (user.customBackgrounds && user.customBackgrounds[type]) {
      const oldPath = path.join(__dirname, '..', user.customBackgrounds[type]);
      if (fs.existsSync(oldPath)) {
        try {
          fs.unlinkSync(oldPath);
        } catch (err) {
          console.warn('Erreur lors de la suppression de l\'ancien background:', err);
        }
      }
    }

    // Construire le chemin relatif
    const relativePath = `/uploads/backgrounds/${req.file.filename}`;

    // Mettre à jour le background
    if (!user.customBackgrounds) {
      user.customBackgrounds = {};
    }
    user.customBackgrounds[type] = relativePath;
    await user.save();

    // URL complète pour le frontend
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    const fullUrl = `${baseUrl}${relativePath}`;

    res.status(200).json({
      success: true,
      message: 'Background uploadé avec succès',
      data: {
        url: fullUrl,
        path: relativePath,
        type: type
      }
    });
  } catch (error) {
    // Supprimer le fichier en cas d'erreur
    if (req.file && req.file.path) {
      try {
        fs.unlinkSync(req.file.path);
      } catch (unlinkError) {
        console.error('Erreur lors de la suppression du fichier:', unlinkError);
      }
    }

    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'upload du background',
      error: error.message
    });
  }
};

// Supprimer un background personnalisé
exports.deleteBackground = async (req, res) => {
  try {
    const { type } = req.params; // balade, groupe, profil, global
    if (!type || !['balade', 'groupe', 'profil', 'global'].includes(type)) {
      return res.status(400).json({
        success: false,
        message: 'Type de background invalide. Valeurs acceptées : balade, groupe, profil, global'
      });
    }

    const userId = req.user._id;
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Supprimer le fichier s'il existe
    if (user.customBackgrounds && user.customBackgrounds[type]) {
      const filePath = path.join(__dirname, '..', user.customBackgrounds[type]);
      if (fs.existsSync(filePath)) {
        try {
          fs.unlinkSync(filePath);
        } catch (err) {
          console.warn('Erreur lors de la suppression du background:', err);
        }
      }
    }

    // Réinitialiser le background
    if (!user.customBackgrounds) {
      user.customBackgrounds = {};
    }
    user.customBackgrounds[type] = null;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Background supprimé avec succès'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la suppression du background',
      error: error.message
    });
  }
};

// Upload d'avatar
exports.uploadAvatar = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Aucun fichier fourni'
      });
    }

    const userId = req.user._id;
    const user = await User.findById(userId);

    if (!user) {
      // Supprimer le fichier uploadé si l'utilisateur n'existe pas
      fs.unlinkSync(req.file.path);
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Supprimer l'ancien avatar s'il existe
    if (user.avatarUrl && user.avatarUrl.startsWith('/uploads/')) {
      const oldAvatarPath = path.join(__dirname, '..', user.avatarUrl);
      if (fs.existsSync(oldAvatarPath)) {
        fs.unlinkSync(oldAvatarPath);
      }
    }

    // Construire l'URL de l'avatar
    const avatarUrl = `/uploads/avatars/${req.file.filename}`;

    // Mettre à jour l'utilisateur
    user.avatarUrl = avatarUrl;
    await user.save();

    // URL complète pour le frontend
    const fullAvatarUrl = buildFileUrl(avatarUrl, req);

    res.status(200).json({
      success: true,
      message: 'Avatar uploadé avec succès',
      data: {
        avatarUrl: fullAvatarUrl
      }
    });
  } catch (error) {
    // Supprimer le fichier en cas d'erreur
    if (req.file && req.file.path) {
      try {
        fs.unlinkSync(req.file.path);
      } catch (unlinkError) {
        console.error('Erreur lors de la suppression du fichier:', unlinkError);
      }
    }

    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'upload de l\'avatar',
      error: error.message
    });
  }
};

// Rechercher des utilisateurs par pseudo ou email (pour autocomplétion)
exports.searchUsers = async (req, res) => {
  try {
    const q = (req.query.q || '').trim();
    const limit = Math.min(parseInt(req.query.limit) || 10, 10); // Max 10 résultats

    // Si q < 2 caractères, retourner un tableau vide
    if (q.length < 2) {
      return res.status(200).json({
        success: true,
        data: {
          users: []
        }
      });
    }

    // Rechercher par pseudo ou email (insensible à la casse)
    const searchRegex = new RegExp(q, 'i');
    const users = await User.find({
      $or: [
        { pseudo: searchRegex },
        { email: searchRegex }
      ],
      isDeleted: { $ne: true } // Exclure les utilisateurs supprimés
    })
    .select('_id pseudo email avatarUrl firstName lastName')
    .limit(limit)
    .lean();

    // Construire les URLs complètes des avatars et formater la réponse
    const usersWithAvatars = users.map(user => ({
      _id: user._id.toString(),
      id: user._id.toString(), // Alias pour compatibilité
      pseudo: user.pseudo,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      avatar: user.avatarUrl ? buildFileUrl(user.avatarUrl, req) : null,
      avatarUrl: user.avatarUrl ? buildFileUrl(user.avatarUrl, req) : null // Alias pour compatibilité
    }));

    res.status(200).json({
      success: true,
      data: {
        users: usersWithAvatars
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la recherche d\'utilisateurs',
      error: error.message
    });
  }
};

// Obtenir les informations du plan de l'utilisateur
exports.getMyPlan = async (req, res) => {
  try {
    const userId = req.user._id;

    // Obtenir le plan de l'utilisateur (déjà normalisé par subscriptionMiddleware)
    const userPlan = req.userPlan || premiumConfig.getUserPlan(req.user);
    const isPremium = subscriptionService.isPremiumActive(req.user);
    const limits = premiumConfig.getPlanLimits(userPlan);

    // Obtenir les quotas d'utilisation
    const vehicleQuotas = await planQuotaService.countVehiclesByUser(userId);
    const privateGroupsCount = await planQuotaService.countPrivateGroupsCreated(userId);
    const privateRidesCount = await planQuotaService.countPrivateRidesCreatedThisMonth(userId);

    // Renvoyer les limites au format backend (le frontend Flutter utilise maintenant les mêmes noms)
    let formattedLimits;
    if (limits.unlimited) {
      formattedLimits = { unlimited: true };
    } else {
      formattedLimits = {
        unlimited: false,
        maxVehiclesTotal: limits.maxVehiclesTotal ?? null,
        maxVehiclesByType: limits.maxVehiclesByType ?? null,
        maxPhotosTotal: limits.maxPhotosTotal ?? null,
        maxPrivateGroupsCreated: limits.maxPrivateGroupsCreated ?? null,
        maxPrivateRidesCreatedPerMonth: limits.maxPrivateRidesCreatedPerMonth ?? null,
      };
    }

    res.status(200).json({
      success: true,
      data: {
        plan: userPlan,
        isPremium: isPremium,
        premiumExpiresAt: req.user.subscription?.premiumExpiresAt || null,
        limits: formattedLimits,
        usage: {
          vehiclesTotal: vehicleQuotas.total,
          vehiclesByType: vehicleQuotas.byType,
          photosTotal: vehicleQuotas.photosTotal,
          privateGroupsCreated: privateGroupsCount,
          privateRidesCreatedThisMonth: privateRidesCount
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des informations du plan',
      error: error.message
    });
  }
};

/**
 * @swagger
 * /api/users/me/promo-codes/redeem:
 *   post:
 *     summary: Utiliser un code promotionnel
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - code
 *             properties:
 *               code:
 *                 type: string
 *                 example: "RT-A3B2-C4D1-E5F6"
 *                 description: Code promotionnel à utiliser
 *     responses:
 *       200:
 *         description: Code utilisé avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 data:
 *                   type: object
 *                   properties:
 *                     effect:
 *                       type: object
 *                       properties:
 *                         type:
 *                           type: string
 *                           enum: [DISCOUNT_PERCENT, GRANT_PREMIUM_MONTHS, GRANT_PREMIUM_PERMANENT]
 *                         discountPercent:
 *                           type: number
 *                         premiumMonths:
 *                           type: number
 *                         premiumPermanent:
 *                           type: boolean
 *                     planAfter:
 *                       type: object
 *                       properties:
 *                         plan:
 *                           type: string
 *                           enum: [FREE, PREMIUM]
 *                         isPremium:
 *                           type: boolean
 *                         premiumExpiresAt:
 *                           type: string
 *                           format: date-time
 *                           nullable: true
 *                         premiumSource:
 *                           type: string
 *       400:
 *         description: Code invalide, expiré, déjà utilisé ou désactivé
 *       404:
 *         description: Code non trouvé
 */
exports.redeemPromoCode = async (req, res) => {
  try {
    const { code } = req.body;
    const userId = req.user._id;

    if (!code || typeof code !== 'string' || code.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Le code promotionnel est requis'
      });
    }

    // Utiliser le service pour utiliser le code
    const result = await promoCodeService.redeemPromoCode({
      userId,
      codePlain: code.trim()
    });

    // Recharger l'utilisateur pour avoir les données à jour
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Construire la réponse avec les informations du plan
    const userPlan = premiumConfig.getUserPlan(user);
    const isPremium = subscriptionService.isPremiumActive(user);

    // Construire l'effet appliqué
    const effect = {
      type: result.type
    };

    if (result.type === 'DISCOUNT_PERCENT') {
      effect.discountPercent = result.details.discountPercent;
    } else if (result.type === 'GRANT_PREMIUM_MONTHS') {
      effect.premiumMonths = result.details.premiumMonths;
    } else if (result.type === 'GRANT_PREMIUM_PERMANENT') {
      effect.premiumPermanent = true;
    }

    res.status(200).json({
      success: true,
      message: result.appliedEffect,
      data: {
        effect,
        planAfter: {
          plan: userPlan,
          isPremium,
          premiumExpiresAt: user.subscription?.premiumExpiresAt || null,
          premiumSource: user.subscription?.premiumSource || null
        }
      }
    });
  } catch (error) {
    // Messages d'erreur clairs selon le type d'erreur
    let statusCode = 400;
    let message = error.message;

    if (error.message.includes('non trouvé') || error.message.includes('non trouvée')) {
      statusCode = 404;
      message = 'Code promotionnel non trouvé';
    } else if (error.message.includes('expiré')) {
      statusCode = 400;
      message = 'Ce code promotionnel a expiré';
    } else if (error.message.includes('déjà utilisé')) {
      statusCode = 400;
      message = 'Vous avez déjà utilisé ce code promotionnel';
    } else if (error.message.includes('désactivé')) {
      statusCode = 400;
      message = 'Ce code promotionnel est désactivé';
    } else if (error.message.includes('invalide')) {
      statusCode = 400;
      message = 'Code promotionnel invalide';
    } else if (error.message.includes('pas encore valide')) {
      statusCode = 400;
      message = 'Ce code promotionnel n\'est pas encore valide';
    } else if (error.message.includes('limite')) {
      statusCode = 400;
      message = 'Ce code promotionnel a atteint sa limite d\'utilisation';
    }

    // Ne jamais logger le code en clair
    console.log(`Erreur lors de l'utilisation d'un code promotionnel par l'utilisateur ${req.user._id}: ${message}`);

    res.status(statusCode).json({
      success: false,
      message
    });
  }
};
