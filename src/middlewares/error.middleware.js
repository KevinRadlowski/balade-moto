const { AppError, mapMongooseError } = require('../utils/errors');

/**
 * Middleware de gestion d'erreurs global - Production Ready
 * Doit être le dernier middleware dans app.js
 * Standardise toutes les erreurs avec format: { error: { code, message }, ... }
 */
const errorHandler = (err, req, res, next) => {
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  // Si l'erreur est déjà une AppError, utiliser ses propriétés
  if (err instanceof AppError) {
    const response = {
      success: false,
      error: {
        code: err.code,
        message: err.message
      }
    };
    
    // Ajouter les détails si présents
    if (err.details) {
      response.error.details = err.details;
    }
    
    // Ajouter les erreurs de validation si présentes
    if (err.errors && Array.isArray(err.errors)) {
      response.errors = err.errors;
    }
    
    // Ajouter les détails de debug en développement uniquement
    if (isDevelopment) {
      response.debug = {
        stack: err.stack,
        name: err.name,
        statusCode: err.statusCode,
        isOperational: err.isOperational
      };
    }
    
    return res.status(err.statusCode).json(response);
  }

  // Erreurs Mongoose - Mapper vers AppError
  if (err.name === 'ValidationError' || 
      err.name === 'CastError' || 
      err.name === 'MongoServerError' ||
      err.name === 'MongoError') {
    const mappedError = mapMongooseError(err);
    return errorHandler(mappedError, req, res, next);
  }

  // Erreurs JWT
  if (err.name === 'JsonWebTokenError') {
    const jwtError = new AppError('Token invalide', 401, 'INVALID_TOKEN');
    return errorHandler(jwtError, req, res, next);
  }

  if (err.name === 'TokenExpiredError') {
    const jwtError = new AppError('Token expiré', 401, 'TOKEN_EXPIRED');
    return errorHandler(jwtError, req, res, next);
  }

  // Erreurs Multer (upload)
  if (err.name === 'MulterError') {
    let message = 'Erreur lors de l\'upload';
    let code = 'UPLOAD_ERROR';
    
    if (err.code === 'LIMIT_FILE_SIZE') {
      message = 'Fichier trop volumineux';
      code = 'FILE_TOO_LARGE';
    } else if (err.code === 'LIMIT_FILE_COUNT') {
      message = 'Trop de fichiers';
      code = 'TOO_MANY_FILES';
    } else if (err.code === 'LIMIT_UNEXPECTED_FILE') {
      message = 'Champ de fichier inattendu';
      code = 'UNEXPECTED_FIELD';
    }
    
    const multerError = new AppError(
      message,
      400,
      code,
      { multerCode: err.code, field: err.field }
    );
    return errorHandler(multerError, req, res, next);
  }

  // Erreurs CORS
  if (err.message && err.message.startsWith('CORS:')) {
    const corsError = new AppError(
      err.message.replace('CORS: ', ''),
      403,
      'CORS_ERROR',
      isDevelopment ? { origin: req.headers.origin } : null
    );
    return errorHandler(corsError, req, res, next);
  }

  // Erreurs express-rate-limit
  if (err.statusCode === 429) {
    const rateLimitError = new AppError(
      err.message || 'Trop de requêtes',
      429,
      'RATE_LIMIT_EXCEEDED',
      { retryAfter: err.retryAfter }
    );
    return errorHandler(rateLimitError, req, res, next);
  }

  // Erreur par défaut (erreur non gérée)
  const statusCode = err.statusCode || 500;
  const message = isDevelopment 
    ? err.message || 'Erreur interne du serveur'
    : 'Erreur interne du serveur';

  // Logger l'erreur (toujours en production, optionnel en dev)
  const logData = {
    message: err.message,
    stack: err.stack,
    name: err.name,
    url: req.originalUrl,
    method: req.method,
    ip: req.ip,
    user: req.user?._id
  };

  if (process.env.NODE_ENV === 'production') {
    console.error('❌ Erreur serveur:', logData);
  } else {
    console.error('❌ Erreur:', logData);
  }

  // Créer une erreur interne standardisée
  const internalError = new AppError(
    message,
    statusCode,
    'INTERNAL_SERVER_ERROR',
    isDevelopment ? { originalError: err.name } : null,
    false // Erreur non opérationnelle (bug)
  );

  return errorHandler(internalError, req, res, next);
};

module.exports = errorHandler;

