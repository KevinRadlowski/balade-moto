const jwt = require('jsonwebtoken');
const User = require('../models/User');

const authMiddleware = async (req, res, next) => {
  try {
    // Récupérer le token depuis le header Authorization
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ 
        success: false, 
        message: 'Token manquant ou invalide. Format attendu : Bearer <token>' 
      });
    }

    const token = authHeader.split(' ')[1];

    // Vérifier et décoder le token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Récupérer l'utilisateur depuis la base de données
    const user = await User.findById(decoded.userId).select('-password -refreshToken');
    
    if (!user) {
      return res.status(401).json({ 
        success: false, 
        message: 'Utilisateur non trouvé' 
      });
    }

    // Vérifier si l'utilisateur est supprimé (soft delete)
    if (user.isDeleted) {
      return res.status(403).json({ 
        success: false, 
        message: 'Ce compte a été supprimé',
        deleted: true
      });
    }

    // Vérifier si l'utilisateur est banni
    if (user.banned) {
      return res.status(403).json({ 
        success: false, 
        message: 'Votre compte a été banni. Veuillez contacter le support pour plus d\'informations.',
        banned: true
      });
    }

    // Vérifier que le rôle dans le token correspond au rôle en base (sécurité)
    if (decoded.role && decoded.role !== user.role) {
      // Le rôle a changé, mettre à jour le token serait mieux mais pour l'instant on accepte
      console.warn(`Rôle mismatch pour user ${user._id}: token=${decoded.role}, db=${user.role}`);
    }

    // Ajouter l'utilisateur à la requête
    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ 
        success: false, 
        message: 'Token invalide' 
      });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ 
        success: false, 
        message: 'Token expiré' 
      });
    }
    return res.status(500).json({ 
      success: false, 
      message: 'Erreur d\'authentification', 
      error: error.message 
    });
  }
};

module.exports = authMiddleware;



