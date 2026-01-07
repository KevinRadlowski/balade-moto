/**
 * Rate limiting pour les endpoints OTP avec express-rate-limit
 */

const rateLimit = require('express-rate-limit');

/**
 * Rate limiter pour l'envoi d'OTP
 * 10 requêtes par 15 minutes par IP
 */
const sendOtpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 requêtes max
  message: {
    success: false,
    message: 'Trop de tentatives d\'envoi de code. Veuillez réessayer dans 15 minutes.'
  },
  standardHeaders: true, // Retourne rate limit info dans les headers `RateLimit-*`
  legacyHeaders: false, // Désactive les headers `X-RateLimit-*`
  skipSuccessfulRequests: false, // Compter toutes les requêtes, même réussies
  skipFailedRequests: false, // Compter les requêtes échouées aussi
});

/**
 * Rate limiter pour la vérification d'OTP
 * 20 requêtes par 15 minutes par IP
 */
const verifyOtpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // 20 requêtes max
  message: {
    success: false,
    message: 'Trop de tentatives de vérification. Veuillez réessayer dans 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true, // Ne pas compter les vérifications réussies
  skipFailedRequests: false,
});

/**
 * Rate limiter pour l'inscription
 * 20 requêtes par 15 minutes par IP
 */
const registerLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // 20 requêtes max
  message: {
    success: false,
    message: 'Trop de tentatives d\'inscription. Veuillez réessayer dans 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
});

/**
 * Rate limiter pour la connexion
 * 30 requêtes par 15 minutes par IP
 */
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30, // 30 requêtes max
  message: {
    success: false,
    message: 'Trop de tentatives de connexion. Veuillez réessayer dans 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true, // Ne pas compter les connexions réussies
  skipFailedRequests: false,
});

module.exports = {
  sendOtpLimiter,
  verifyOtpLimiter,
  registerLimiter,
  loginLimiter
};
