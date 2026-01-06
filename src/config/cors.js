/**
 * Configuration CORS centralisée
 * 
 * Gère les origines autorisées selon FRONTEND_URL :
 * - FRONTEND_URL="*" -> autorise toutes les origines
 * - FRONTEND_URL="url1,url2" -> autorise uniquement ces URLs
 * - FRONTEND_URL vide -> utilise les fallbacks par défaut
 */

const cors = require('cors');

/**
 * Parse FRONTEND_URL et retourne la liste des origines autorisées
 * @returns {string[]|null} Liste d'origines ou null si "*" (toutes autorisées)
 */
function getAllowedOrigins() {
  const frontendUrl = process.env.FRONTEND_URL;
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  // Mode développement : origines locales
  if (isDevelopment) {
    return [
      'http://192.168.1.70:8080',
      'http://localhost:8080',
      'http://127.0.0.1:8080'
    ];
  }
  
  // Production : parser FRONTEND_URL
  if (frontendUrl) {
    const trimmed = frontendUrl.trim();
    
    // Si "*", autoriser toutes les origines
    if (trimmed === '*') {
      return null; // null = toutes les origines autorisées
    }
    
    // Sinon, parser la liste d'URLs
    const origins = trimmed
      .split(',')
      .map(url => url.trim())
      .filter(url => url && url !== '*');
    
    if (origins.length > 0) {
      return origins;
    }
  }
  
  // Fallback : origines par défaut en production
  return [
    'http://localhost:3000',
    'http://localhost:59219',
    'https://app.ridetogether.fr',
    'https://www.app.ridetogether.fr'
  ];
}

/**
 * Construit les options CORS
 * @returns {object} Options pour le middleware cors()
 */
function buildCorsOptions() {
  const allowedOrigins = getAllowedOrigins();
  const isDevelopment = process.env.NODE_ENV === 'development' || !process.env.NODE_ENV;
  
  return {
    origin: (origin, callback) => {
      // Autoriser les requêtes sans origin (mobile apps natifs, Postman, curl, etc.)
      if (!origin) {
        if (isDevelopment) {
          console.log('✅ CORS: Requête sans origin autorisée (app native/Postman)');
        }
        return callback(null, true);
      }
      
      // En développement, autoriser tous les ports localhost et 127.0.0.1
      if (isDevelopment) {
        if (origin.startsWith('http://localhost:') || 
            origin.startsWith('http://127.0.0.1:') ||
            origin.startsWith('http://192.168.1.70:')) {
          console.log(`✅ CORS: Origin autorisée en développement: ${origin}`);
          return callback(null, true);
        }
      }
      
      // Si allowedOrigins est null, autoriser toutes les origines (FRONTEND_URL="*")
      if (allowedOrigins === null) {
        if (isDevelopment) {
          console.log(`✅ CORS: Origin autorisée (FRONTEND_URL="*"): ${origin}`);
        }
        return callback(null, true);
      }
      
      // Vérifier si l'origine est dans la whitelist
      if (allowedOrigins.includes(origin)) {
        if (isDevelopment) {
          console.log(`✅ CORS: Origin dans whitelist: ${origin}`);
        }
        callback(null, true);
      } else {
        // Log uniquement en développement ou si DEBUG_CORS est défini
        if (isDevelopment || process.env.DEBUG_CORS === 'true') {
          console.warn(`🚫 CORS blocked for origin: ${origin}`);
          console.warn(`   NODE_ENV: ${process.env.NODE_ENV || 'non défini'}`);
          console.warn(`   isDevelopment: ${isDevelopment}`);
          console.warn(`   Allowed origins:`, allowedOrigins);
        }
        callback(new Error(`CORS: Origin ${origin} is not allowed`));
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    exposedHeaders: ['Content-Range', 'X-Content-Range'],
    preflightContinue: false,
    optionsSuccessStatus: 204,
    maxAge: 86400 // Cache preflight 24h
  };
}

/**
 * Retourne la liste des origines autorisées pour les logs
 * @returns {string} Description des origines autorisées
 */
function getCorsInfo() {
  const allowedOrigins = getAllowedOrigins();
  
  if (allowedOrigins === null) {
    return 'Toutes les origines (*)';
  }
  
  return allowedOrigins.join(', ');
}

module.exports = {
  buildCorsOptions,
  getAllowedOrigins,
  getCorsInfo
};







