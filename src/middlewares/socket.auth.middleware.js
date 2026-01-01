const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Middleware d'authentification pour Socket.io
const socketAuth = async (socket, next) => {
  try {
    const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return next(new Error('Token manquant'));
    }

    // Vérifier et décoder le token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Récupérer l'utilisateur
    const user = await User.findById(decoded.userId).select('-password -refreshToken');
    
    if (!user) {
      return next(new Error('Utilisateur non trouvé'));
    }

    // Ajouter l'utilisateur au socket
    socket.user = user;
    socket.userId = user._id.toString();
    
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return next(new Error('Token invalide'));
    }
    if (error.name === 'TokenExpiredError') {
      return next(new Error('Token expiré'));
    }
    return next(new Error('Erreur d\'authentification'));
  }
};

module.exports = socketAuth;



