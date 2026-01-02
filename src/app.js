/**
 * Configuration CORS et Accès Réseau
 * 
 * IMPORTANT - Pourquoi localhost ne fonctionne pas depuis l'iPhone :
 * - localhost (127.0.0.1) fait référence à la machine locale elle-même
 * - Quand vous accédez depuis un iPhone, l'iPhone essaie de se connecter à SON propre localhost (lui-même)
 * - Pas à votre PC de développement
 * - Il faut donc utiliser l'IP locale de votre PC sur le réseau LAN
 * 
 * URLs à utiliser :
 * - API depuis iPhone : http://192.168.1.70:5000
 * - Front Flutter Web depuis iPhone : http://192.168.1.70:8080
 * - API en local (même machine) : http://localhost:5000
 * - Front en local (même machine) : http://localhost:8080
 * 
 * Commandes pour servir le front Flutter Web sur l'IP LAN :
 * cd flutter_app/build/web
 * npx http-server -p 8080 -a 192.168.1.70
 * 
 * Ou pour écouter sur toutes les interfaces :
 * npx http-server -p 8080 -a 0.0.0.0
 */

const express = require('express');
const http = require('http');
const cors = require('cors');
const helmet = require('helmet');
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./config/swagger');
require('dotenv').config();

const connectDB = require('./config/db');
const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const rideRoutes = require('./routes/ride.routes');
const groupRoutes = require('./routes/group.routes');
const messageRoutes = require('./routes/message.routes');
const ratingRoutes = require('./routes/rating.routes');
const likeRoutes = require('./routes/like.routes');
const reviewRoutes = require('./routes/review.routes');
const garageRoutes = require('./routes/garage.routes');
const catalogRoutes = require('./routes/catalog.routes');
const initializeSocket = require('./services/socket.service');

// Initialiser Express
const app = express();

// Créer le serveur HTTP
const server = http.createServer(app);

// Connexion à MongoDB
connectDB();

// Middlewares de sécurité
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" },
  // ⚠️ IMPORTANT : Configuration COOP pour permettre les popups OAuth (Google Sign-In)
  // "same-origin-allow-popups" permet aux popups OAuth de fonctionner correctement
  // tout en conservant la sécurité contre les attaques XS-Leaks
  crossOriginOpenerPolicy: { policy: "same-origin-allow-popups" },
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "https://maps.googleapis.com"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:", "blob:"],
      connectSrc: ["'self'", "https://maps.googleapis.com"],
    },
  },
}));

// ============================================================================
// CONFIGURATION CORS - IMPORTANT: Placer AVANT toutes les routes
// ============================================================================
// Whitelist stricte des origines autorisées
const allowedOrigins = process.env.NODE_ENV === 'development'
  ? [
      'http://192.168.1.70:8080',  // Front Flutter Web depuis iPhone (IP LAN)
      'http://localhost:8080',      // Front Flutter Web en local
      'http://127.0.0.1:8080'       // Front Flutter Web en local (alternative)
    ]
  : (() => {
      // En production, utiliser FRONTEND_URL si défini, sinon utiliser les URLs par défaut
      if (process.env.FRONTEND_URL) {
        return process.env.FRONTEND_URL.split(',').map(url => url.trim());
      }
      // URLs de production par défaut
      return [
        'http://app.ridetogether.fr',
        'https://app.ridetogether.fr',
        'http://www.app.ridetogether.fr',
        'https://www.app.ridetogether.fr'
      ];
    })();

// Configuration CORS robuste
app.use(cors({
  origin: (origin, callback) => {
    // Autoriser les requêtes sans origin (mobile apps natifs, Postman, curl, etc.)
    if (!origin) {
      return callback(null, true);
    }
    
    // En développement, autoriser tous les ports localhost (pour Flutter dev server, hot reload, etc.)
    if (process.env.NODE_ENV === 'development') {
      if (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) {
        return callback(null, true);
      }
    }
    
    // Vérifier si l'origine est dans la whitelist
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      // Log clair pour le débogage
      console.warn(`🚫 CORS blocked for origin: ${origin}`);
      console.warn(`   Allowed origins:`, allowedOrigins);
      callback(new Error(`CORS: Origin ${origin} is not allowed`));
    }
  },
  credentials: true,  // IMPORTANT: Ne pas utiliser origin: '*' si credentials: true
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  exposedHeaders: ['Content-Range', 'X-Content-Range'],
  // Gestion explicite des requêtes preflight OPTIONS
  preflightContinue: false,  // Ne pas passer la requête OPTIONS aux routes suivantes
  optionsSuccessStatus: 204,  // Code de succès pour les requêtes OPTIONS
  maxAge: 86400  // Cache les résultats preflight pendant 24 heures
}));

// Middleware pour logger et gérer explicitement les requêtes OPTIONS (preflight)
// Note: Le middleware cors() ci-dessus devrait déjà gérer cela, mais ce middleware
// ajoute des logs et une gestion explicite pour le débogage
app.use((req, res, next) => {
  if (req.method === 'OPTIONS') {
    const origin = req.headers.origin;
    console.log(`✅ OPTIONS preflight request from: ${origin || 'no origin'}`);
    
    // Le middleware cors() devrait déjà avoir ajouté les headers,
    // mais on peut vérifier ici pour le débogage
    if (origin && allowedOrigins.includes(origin)) {
      console.log(`   ✅ Origin autorisée: ${origin}`);
    } else if (origin) {
      console.warn(`   ⚠️  Origin non autorisée: ${origin}`);
      console.warn(`   Origines autorisées:`, allowedOrigins);
    }
  }
  next();
});

app.use(express.json());
// Configurer urlencoded pour accepter UTF-8 correctement
app.use(express.urlencoded({ 
  extended: true,
  limit: '50mb' // Augmenter la limite pour les fichiers
}));

// Servir les fichiers statiques (avatars et fichiers de messages)
// IMPORTANT: Doit être avant les routes API pour éviter les conflits
const path = require('path');
const fs = require('fs');
const uploadsPath = path.join(__dirname, 'uploads');

// Vérifier que le dossier uploads existe
if (!fs.existsSync(uploadsPath)) {
  console.warn('⚠️ Le dossier uploads n\'existe pas:', uploadsPath);
}

// Middleware de debug pour les fichiers statiques
app.use('/uploads', (req, res, next) => {
  const filePath = path.join(uploadsPath, req.path.replace('/uploads', ''));
  console.log('📂 Tentative d\'accès au fichier:', {
    url: req.path,
    filePath: filePath,
    exists: fs.existsSync(filePath)
  });
  next();
});

app.use('/uploads', (req, res, next) => {
  // Middleware pour définir les headers avant de servir le fichier
  const filePath = path.join(uploadsPath, req.path.replace('/uploads', ''));
  
  // CORS aligné avec la whitelist (pas de '*')
  const origin = req.headers.origin;
  if (origin && allowedOrigins.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  
  // Forcer Content-Disposition: attachment pour fichiers non-image
  const ext = path.extname(filePath).toLowerCase();
  const imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  if (!imageExts.includes(ext)) {
    res.setHeader('Content-Disposition', 'attachment');
  }
  
  next();
}, express.static(uploadsPath, {
  fallthrough: false // Ne pas continuer si le fichier n'existe pas
}));

// Servir les assets statiques (images pour emails, etc.)
const assetsPath = path.join(__dirname, '..', 'flutter_app', 'assets', 'images');
if (fs.existsSync(assetsPath)) {
  app.use('/assets/images', express.static(assetsPath, {
    setHeaders: (res, filePath) => {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Cache-Control', 'public, max-age=31536000'); // Cache 1 an
    }
  }));
}

// Documentation Swagger
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'Balades Moto API Documentation'
}));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/user', userRoutes);
app.use('/api/rides', rideRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/ratings', ratingRoutes);
app.use('/api/likes', likeRoutes);
app.use('/api/garage', garageRoutes);
app.use('/api/catalog', catalogRoutes);

// Route de test
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'API Balades Moto - Serveur actif'
  });
});

// ============================================================================
// ENDPOINT DE TEST RÉSEAU
// ============================================================================
// GET /health - Test de connectivité depuis le réseau
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'API accessible',
    timestamp: new Date().toISOString(),
    origin: req.headers.origin || 'N/A',
    ip: req.ip || req.connection.remoteAddress || 'N/A'
  });
});

// Gestion des erreurs 404 (doit être après toutes les routes et le serveur statique)
app.use((req, res) => {
  // Ne pas retourner 404 pour les fichiers statiques
  if (req.path.startsWith('/uploads/')) {
    return res.status(404).json({
      success: false,
      message: 'Fichier non trouvé',
      path: req.path
    });
  }
  res.status(404).json({
    success: false,
    message: 'Route non trouvée',
    path: req.path
  });
});

// Gestion des erreurs globales (doit être le dernier middleware)
const errorHandler = require('./middlewares/error.middleware');
app.use(errorHandler);

// Initialiser Socket.io
const io = initializeSocket(server);
// Exporter l'instance io pour les contrôleurs HTTP
const socketService = require('./services/socket.service');
if (socketService.setIoInstance) {
  socketService.setIoInstance(io);
}

// Démarrer le scheduler de notifications
const notificationService = require('./services/notification.service');
notificationService.startNotificationScheduler();

// ============================================================================
// DÉMARRAGE DU SERVEUR
// ============================================================================
// Écouter sur toutes les interfaces réseau (0.0.0.0) pour être accessible depuis le LAN
const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || '0.0.0.0'; // 0.0.0.0 = toutes les interfaces réseau

server.listen(PORT, HOST, () => {
  console.log(`🚀 Serveur démarré sur http://${HOST}:${PORT}`);
  console.log(`📡 Accessible depuis le réseau local`);
  console.log(`   - Local: http://localhost:${PORT}`);
  console.log(`   - LAN: http://192.168.1.70:${PORT}`);
  console.log(`🔌 Socket.io initialisé`);
  console.log(`⏰ Scheduler de notifications démarré`);
  console.log(`\n✅ CORS configuré pour les origines suivantes:`);
  console.log(`   ${allowedOrigins.join('\n   ')}`);
  console.log(`\n💡 Pour tester depuis iPhone:`);
  console.log(`   - API: http://192.168.1.70:${PORT}/health`);
  console.log(`   - Front: http://192.168.1.70:8080`);
});

module.exports = { app, server, io };

