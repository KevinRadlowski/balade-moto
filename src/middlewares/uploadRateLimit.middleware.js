/**
 * Rate limiting pour les routes d'upload
 * Protection contre le spam d'uploads
 */

const rateLimit = require('express-rate-limit');
const { ipKeyGenerator } = require('express-rate-limit');
const { createRedisStore } = require('./redis-rate-limit.store');

/**
 * Rate limiter pour les uploads d'avatar
 * 10 uploads par 15 minutes par utilisateur
 */
const uploadAvatarLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 uploads max
  store: createRedisStore({ prefix: 'upload:avatar:', windowMs: 15 * 60 * 1000 }),
  keyGenerator: (req) => {
    // Utiliser l'ID utilisateur si authentifié, sinon l'IP (avec gestion IPv6)
    if (req.user?._id) {
      return req.user._id.toString();
    }
    // Utiliser ipKeyGenerator pour gérer correctement IPv6
    return ipKeyGenerator(req.ip);
  },
  message: {
    success: false,
    message: 'Trop d\'uploads d\'avatar. Veuillez réessayer dans 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
});

/**
 * Rate limiter pour les uploads de fichiers messages
 * 20 uploads par 15 minutes par utilisateur
 */
const uploadMessageFileLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // 20 uploads max
  store: createRedisStore({ prefix: 'upload:message:', windowMs: 15 * 60 * 1000 }),
  keyGenerator: (req) => {
    return req.user?._id?.toString() || req.ip;
  },
  message: {
    success: false,
    message: 'Trop d\'uploads de fichiers. Veuillez réessayer dans 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
});

/**
 * Rate limiter pour les uploads de photos véhicules
 * 15 uploads par 15 minutes par utilisateur
 */
const uploadVehiclePhotoLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 15, // 15 uploads max
  store: createRedisStore({ prefix: 'upload:vehicle:', windowMs: 15 * 60 * 1000 }),
  keyGenerator: (req) => {
    return req.user?._id?.toString() || req.ip;
  },
  message: {
    success: false,
    message: 'Trop d\'uploads de photos. Veuillez réessayer dans 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
});

/**
 * Rate limiter pour les uploads de documents véhicules
 * 10 uploads par 15 minutes par utilisateur
 */
const uploadVehicleDocumentLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 uploads max
  store: createRedisStore({ prefix: 'upload:vehicle-doc:', windowMs: 15 * 60 * 1000 }),
  keyGenerator: (req) => {
    return req.user?._id?.toString() || req.ip;
  },
  message: {
    success: false,
    message: 'Trop d\'uploads de documents. Veuillez réessayer dans 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
});

/**
 * Rate limiter pour les uploads de background
 * 5 uploads par 15 minutes par utilisateur
 */
const uploadBackgroundLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 uploads max
  store: createRedisStore({ prefix: 'upload:background:', windowMs: 15 * 60 * 1000 }),
  keyGenerator: (req) => {
    return req.user?._id?.toString() || req.ip;
  },
  message: {
    success: false,
    message: 'Trop d\'uploads de background. Veuillez réessayer dans 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
});

module.exports = {
  uploadAvatarLimiter,
  uploadMessageFileLimiter,
  uploadVehiclePhotoLimiter,
  uploadVehicleDocumentLimiter,
  uploadBackgroundLimiter
};

