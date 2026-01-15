/**
 * Classes d'erreur personnalisées pour une gestion d'erreurs cohérente
 * Production Ready - Codes d'erreur standardisés
 */

class AppError extends Error {
  /**
   * @param {string} message - Message d'erreur
   * @param {number} statusCode - Code HTTP (défaut: 500)
   * @param {string} code - Code d'erreur personnalisé (ex: 'VALIDATION_ERROR', 'NOT_FOUND')
   * @param {object} details - Détails supplémentaires (optionnel)
   * @param {boolean} isOperational - Si true, erreur opérationnelle (pas un bug)
   */
  constructor(message, statusCode = 500, code = null, details = null, isOperational = true) {
    super(message);
    this.statusCode = statusCode;
    this.code = code || this._generateDefaultCode(statusCode);
    this.details = details;
    this.isOperational = isOperational;
    this.status = `${statusCode}`.startsWith('4') ? 'fail' : 'error';
    
    Error.captureStackTrace(this, this.constructor);
  }

  /**
   * Génère un code d'erreur par défaut basé sur le statusCode
   * @private
   */
  _generateDefaultCode(statusCode) {
    const codeMap = {
      400: 'BAD_REQUEST',
      401: 'UNAUTHORIZED',
      403: 'FORBIDDEN',
      404: 'NOT_FOUND',
      409: 'CONFLICT',
      422: 'VALIDATION_ERROR',
      429: 'RATE_LIMIT_EXCEEDED',
      500: 'INTERNAL_SERVER_ERROR',
      503: 'SERVICE_UNAVAILABLE'
    };
    return codeMap[statusCode] || 'INTERNAL_SERVER_ERROR';
  }
}

class ValidationError extends AppError {
  constructor(message = 'Erreur de validation', errors = []) {
    super(message, 400, 'VALIDATION_ERROR', null, true);
    this.errors = errors;
    this.name = 'ValidationError';
  }
}

class UnauthorizedError extends AppError {
  constructor(message = 'Non autorisé', details = null) {
    super(message, 401, 'UNAUTHORIZED', details, true);
    this.name = 'UnauthorizedError';
  }
}

class ForbiddenError extends AppError {
  constructor(message = 'Accès interdit', details = null) {
    super(message, 403, 'FORBIDDEN', details, true);
    this.name = 'ForbiddenError';
  }
}

class NotFoundError extends AppError {
  constructor(resource = 'Ressource', details = null) {
    super(`${resource} non trouvé(e)`, 404, 'NOT_FOUND', details, true);
    this.name = 'NotFoundError';
  }
}

class ConflictError extends AppError {
  constructor(message = 'Conflit', details = null) {
    super(message, 409, 'CONFLICT', details, true);
    this.name = 'ConflictError';
  }
}

class InternalServerError extends AppError {
  constructor(message = 'Erreur interne du serveur', details = null) {
    super(message, 500, 'INTERNAL_SERVER_ERROR', details, false);
    this.name = 'InternalServerError';
  }
}

class BadRequestError extends AppError {
  constructor(message = 'Requête invalide', details = null) {
    super(message, 400, 'BAD_REQUEST', details, true);
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
  
  const details = {
    limit,
    current,
    remaining,
    plan,
    limitKey
  };
  
  const error = new ForbiddenError(message, details);
  error.code = 'PLAN_LIMIT'; // Override le code par défaut
  
  return error;
}

/**
 * Mappe une erreur Mongoose vers une AppError
 * @param {Error} mongooseError - Erreur Mongoose
 * @returns {AppError} Erreur normalisée
 */
function mapMongooseError(mongooseError) {
  // Erreur de validation Mongoose
  if (mongooseError.name === 'ValidationError') {
    const errors = Object.values(mongooseError.errors).map(err => ({
      field: err.path,
      message: err.message,
      value: err.value
    }));
    return new ValidationError('Erreur de validation', errors);
  }

  // Erreur de cast (ObjectId invalide, etc.)
  if (mongooseError.name === 'CastError') {
    return new BadRequestError(
      `Valeur invalide pour le champ "${mongooseError.path}": ${mongooseError.value}`,
      { field: mongooseError.path, value: mongooseError.value }
    );
  }

  // Erreur de duplication (unique constraint)
  if (mongooseError.name === 'MongoServerError' && mongooseError.code === 11000) {
    const field = Object.keys(mongooseError.keyPattern || {})[0] || 'champ';
    const value = mongooseError.keyValue?.[field];
    return new ConflictError(
      `${field} déjà utilisé(e)${value ? `: ${value}` : ''}`,
      { field, value, duplicate: true }
    );
  }

  // Erreur MongoDB générique
  if (mongooseError.name === 'MongoServerError') {
    return new InternalServerError(
      'Erreur de base de données',
      { mongoCode: mongooseError.code, mongoMessage: mongooseError.message }
    );
  }

  // Erreur Mongoose générique
  return new InternalServerError(
    mongooseError.message || 'Erreur de base de données',
    { mongooseError: mongooseError.name }
  );
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
  createPlanLimitError,
  mapMongooseError
};

