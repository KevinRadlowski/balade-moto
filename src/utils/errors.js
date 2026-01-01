/**
 * Classes d'erreur personnalisées pour une gestion d'erreurs cohérente
 */

class AppError extends Error {
  constructor(message, statusCode = 500, isOperational = true) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.status = `${statusCode}`.startsWith('4') ? 'fail' : 'error';
    
    Error.captureStackTrace(this, this.constructor);
  }
}

class ValidationError extends AppError {
  constructor(message, errors = []) {
    super(message, 400);
    this.errors = errors;
    this.name = 'ValidationError';
  }
}

class UnauthorizedError extends AppError {
  constructor(message = 'Non autorisé') {
    super(message, 401);
    this.name = 'UnauthorizedError';
  }
}

class ForbiddenError extends AppError {
  constructor(message = 'Accès interdit') {
    super(message, 403);
    this.name = 'ForbiddenError';
  }
}

class NotFoundError extends AppError {
  constructor(resource = 'Ressource') {
    super(`${resource} non trouvé(e)`, 404);
    this.name = 'NotFoundError';
  }
}

class ConflictError extends AppError {
  constructor(message = 'Conflit') {
    super(message, 409);
    this.name = 'ConflictError';
  }
}

class InternalServerError extends AppError {
  constructor(message = 'Erreur interne du serveur') {
    super(message, 500);
    this.name = 'InternalServerError';
  }
}

class BadRequestError extends AppError {
  constructor(message = 'Requête invalide') {
    super(message, 400);
    this.name = 'BadRequestError';
  }
}

module.exports = {
  AppError,
  ValidationError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError,
  InternalServerError,
  BadRequestError
};

