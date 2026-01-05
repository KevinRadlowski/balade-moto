const { AppError } = require('../utils/errors');

/**
 * Middleware de gestion d'erreurs global
 * Doit être le dernier middleware dans app.js
 */
const errorHandler = (err, req, res, next) => {
  // Si l'erreur est déjà une AppError, utiliser ses propriétés
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
      ...(err.errors && { errors: err.errors }),
      ...(process.env.NODE_ENV === 'development' && {
        stack: err.stack,
        name: err.name
      })
    });
  }

  // Erreurs de validation express-validator
  if (err.name === 'ValidationError' || err.name === 'CastError') {
    return res.status(400).json({
      success: false,
      message: 'Erreur de validation',
      error: err.message,
      ...(process.env.NODE_ENV === 'development' && {
        stack: err.stack
      })
    });
  }

  // Erreurs JWT
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      success: false,
      message: 'Token invalide'
    });
  }

  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      success: false,
      message: 'Token expiré'
    });
  }

  // Erreurs Mongoose
  if (err.name === 'MongoServerError' && err.code === 11000) {
    const field = Object.keys(err.keyPattern)[0];
    return res.status(409).json({
      success: false,
      message: `${field} déjà utilisé(e)`
    });
  }

  // Erreurs Multer (upload)
  if (err.name === 'MulterError') {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        message: 'Fichier trop volumineux'
      });
    }
    return res.status(400).json({
      success: false,
      message: err.message || 'Erreur lors de l\'upload'
    });
  }

  // Erreurs CORS
  if (err.message && err.message.startsWith('CORS:')) {
    return res.status(403).json({
      success: false,
      message: err.message,
      ...(process.env.NODE_ENV === 'development' && {
        error: 'Origine non autorisée par la politique CORS',
        origin: req.headers.origin
      })
    });
  }

  // Erreur par défaut
  const statusCode = err.statusCode || 500;
  const message = process.env.NODE_ENV === 'development' 
    ? err.message 
    : 'Erreur interne du serveur';

  // Logger l'erreur en production
  if (process.env.NODE_ENV === 'production') {
    console.error('Erreur serveur:', {
      message: err.message,
      stack: err.stack,
      url: req.originalUrl,
      method: req.method,
      ip: req.ip,
      user: req.user?._id
    });
  } else {
    console.error('Erreur:', err);
  }

  res.status(statusCode).json({
    success: false,
    message,
    ...(process.env.NODE_ENV === 'development' && {
      error: err.message,
      stack: err.stack,
      name: err.name
    })
  });
};

module.exports = errorHandler;

