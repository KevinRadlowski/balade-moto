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

/**
 * Crée une erreur standardisée pour les limites de plan (quota)
 * @param {string} limitKey - La clé de la limite (ex: 'maxVehiclesTotal')
 * @param {number} limit - La valeur de la limite
 * @param {number} current - La valeur actuelle
 * @param {string} plan - Le plan de l'utilisateur ('FREE' ou 'PREMIUM')
 * @param {string} resourceName - Le nom de la ressource (ex: 'véhicules', 'photos', 'balades privées')
 * @returns {ForbiddenError} Une erreur avec la structure PLAN_LIMIT standardisée
 */
function createPlanLimitError(limitKey, limit, current, plan, resourceName) {
  const remaining = Math.max(0, limit - current);
  
  // Messages plus explicites selon le type de limite
  let message;
  if (limitKey.startsWith('maxVehiclesByType.')) {
    // Limite par type de véhicule (moto/voiture)
    const vehicleType = limitKey.split('.')[1]; // 'moto' ou 'voiture'
    const vehicleTypeLabel = vehicleType === 'moto' ? 'moto' : 'voiture';
    
    if (current >= limit) {
      message = `Vous avez atteint votre limite de ${limit} ${vehicleTypeLabel} avec le plan Standard. ${limit === 1 ? 'Supprimez votre ' + vehicleTypeLabel + ' existante' : 'Supprimez une ' + vehicleTypeLabel + ' existante'} ou passez en Premium pour ajouter un nombre illimité de véhicules.`;
    } else {
      message = `Limite de ${limit} ${vehicleTypeLabel} atteinte avec le plan Standard. Passez en Premium pour ajouter un nombre illimité de véhicules.`;
    }
  } else {
    // Autres limites (total véhicules, photos, etc.)
    if (current >= limit) {
      message = `Vous avez atteint votre limite de ${limit} ${resourceName} avec le plan Standard. Supprimez des ${resourceName} existants ou passez en Premium pour créer un nombre illimité de ${resourceName}.`;
    } else {
      message = `Limite de ${limit} ${resourceName} atteinte avec le plan Standard. Passez en Premium pour créer un nombre illimité de ${resourceName}.`;
    }
  }
  
  const error = new ForbiddenError(message);
  error.code = 'PLAN_LIMIT';
  error.details = {
    limit,
    current,
    remaining,
    plan,
    limitKey
  };
  
  return error;
}

module.exports = {
  AppError,
  ValidationError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError,
  InternalServerError,
  BadRequestError,
  createPlanLimitError
};

