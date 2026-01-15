/**
 * Configuration CORS centralisée - Production Ready
 * 
 * Gère les origines autorisées selon CORS_ORIGINS (priorité) ou FRONTEND_URL (compatibilité) :
 * - CORS_ORIGINS="url1,url2" -> autorise uniquement ces URLs (STRICT en production)
 * - CORS_ORIGINS="*" -> autorise toutes les origines (⚠️ DÉCONSEILLÉ en production)
 * - CORS_ORIGINS vide + FRONTEND_URL="url1,url2" -> utilise FRONTEND_URL (compatibilité)
 * - En production sans config : REFUSE toutes les origines (sécurité stricte)
 * - En développement : autorise localhost/127.0.0.1/192.168.* (flexible)
 */

const cors = require('cors');

/**
 * Parse CORS_ORIGINS ou FRONTEND_URL et retourne la liste des origines autorisées
 * @returns {string[]|null} Liste d'origines ou null si "*" (toutes autorisées)
 */
function getAllowedOrigins() {
  const corsOrigins = process.env.CORS_ORIGINS;
  const frontendUrl = process.env.FRONTEND_URL; // Compatibilité
  const isDevelopment = process.env.NODE_ENV === 'development' || !process.env.NODE_ENV;
  
  // Mode développement : origines locales flexibles
  if (isDevelopment) {
    // En dev, autoriser tous les localhost/127.0.0.1/192.168.*
    // Pour faciliter le développement avec Flutter Web qui change de port
    return [
      'http://192.168.1.70:8080',
      'http://localhost:8080',
      'http://127.0.0.1:8080',
      'http://localhost:3000',
      'http://localhost:5173',
      'http://localhost:59219'
    ];
  }
  
  // PRODUCTION : Utiliser CORS_ORIGINS en priorité
  const originsEnv = corsOrigins || frontendUrl;
  
  if (originsEnv) {
    const trimmed = originsEnv.trim();
    
    // Si "*", autoriser toutes les origines (⚠️ DÉCONSEILLÉ mais possible)
    if (trimmed === '*') {
      console.warn('⚠️  CORS: Mode "*" activé - TOUTES les origines sont autorisées (non recommandé en production)');
      return null; // null = toutes les origines autorisées
    }
    
    // Parser la liste d'URLs
    const origins = trimmed
      .split(',')
      .map(url => url.trim())
      .filter(url => url && url !== '*');
    
    if (origins.length > 0) {
      return origins;
    }
  }
  
  // PRODUCTION SANS CONFIG : Refuser toutes les origines (sécurité stricte)
  // Ne pas utiliser de fallback par défaut en production
  console.error('❌ CORS: Aucune origine configurée en production. CORS_ORIGINS ou FRONTEND_URL requis.');
  console.error('   Exemple: CORS_ORIGINS=https://app.ridetogether.fr,https://www.app.ridetogether.fr');
  return []; // Liste vide = aucune origine autorisée (sécurité stricte)
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
      if (allowedOrigins && allowedOrigins.length > 0 && allowedOrigins.includes(origin)) {
        if (isDevelopment) {
          console.log(`✅ CORS: Origin dans whitelist: ${origin}`);
        }
        callback(null, true);
      } else if (allowedOrigins && allowedOrigins.length === 0) {
        // Production sans config : refuser
        const errorMsg = `CORS: Origin ${origin} is not allowed. Aucune origine configurée en production.`;
        if (process.env.DEBUG_CORS === 'true') {
          console.error(`🚫 ${errorMsg}`);
          console.error(`   Configurez CORS_ORIGINS ou FRONTEND_URL dans votre .env`);
        }
        callback(new Error(errorMsg));
      } else {
        // Origine non dans la whitelist
        const errorMsg = `CORS: Origin ${origin} is not allowed`;
        // Log uniquement en développement ou si DEBUG_CORS est défini
        if (isDevelopment || process.env.DEBUG_CORS === 'true') {
          console.warn(`🚫 ${errorMsg}`);
          console.warn(`   NODE_ENV: ${process.env.NODE_ENV || 'non défini'}`);
          console.warn(`   isDevelopment: ${isDevelopment}`);
          console.warn(`   Allowed origins:`, allowedOrigins || 'Toutes (*)');
        }
        callback(new Error(errorMsg));
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














