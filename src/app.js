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
const { initRedis } = require('./config/redis');
const { buildCorsOptions, getCorsInfo } = require('./config/cors');
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
const vehicleCatalogRoutes = require('./routes/vehicle-catalog.routes');
const adminCatalogRoutes = require('./routes/admin.catalog.routes');
const adminUsersRoutes = require('./routes/admin.users.routes');
const adminRidesRoutes = require('./routes/admin.rides.routes');
const adminGroupsRoutes = require('./routes/admin.groups.routes');
const adminPromoCodesRoutes = require('./routes/admin.promoCodes.routes');
const feedbackRoutes = require('./routes/feedback.routes');
const reputationRoutes = require('./routes/reputation.routes');
const compatibilityRoutes = require('./routes/compatibility.routes');
const liveRideRoutes = require('./routes/liveRide.routes');
const checkInRoutes = require('./routes/checkIn.routes');
const contactRoutes = require('./routes/contact.routes');
const referralRoutes = require('./routes/referral.routes');
const phoneRoutes = require('./routes/phone.routes');
const phoneOtpRoutes = require('./routes/phoneOtp.routes');
const initializeSocket = require('./services/socket.service');

// Initialiser Express
const app = express();

// Créer le serveur HTTP
const server = http.createServer(app);

// Connexion à MongoDB
// Connexion à MongoDB
connectDB();

// Initialisation Redis (optionnel, fail-open vers memory store)
initRedis().catch(err => {
  console.error('❌ Erreur lors de l\'initialisation Redis:', err.message);
  console.log('ℹ️  L\'application continue avec rate limiting en mémoire.');
});

// Middlewares de sécurité
const isDevelopment = process.env.NODE_ENV === 'development' || !process.env.NODE_ENV;
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" },
  // ⚠️ IMPORTANT : Configuration COOP pour permettre les popups OAuth (Google Sign-In)
  // En développement : "unsafe-none" pour éviter les problèmes avec les popups OAuth
  // En production : "same-origin-allow-popups" pour la sécurité tout en permettant OAuth
  crossOriginOpenerPolicy: { 
    policy: isDevelopment ? "unsafe-none" : "same-origin-allow-popups" 
  },
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "https://maps.googleapis.com", "https://accounts.google.com"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:", "blob:"],
      connectSrc: ["'self'", "https://maps.googleapis.com", "https://accounts.google.com"],
    },
  },
}));

// ============================================================================
// CONFIGURATION CORS - IMPORTANT: Placer AVANT toutes les routes
// ============================================================================
const corsOptions = buildCorsOptions();
app.use(cors(corsOptions));

// Gérer explicitement les requêtes OPTIONS pour toutes les routes
app.options('*', cors(corsOptions));

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
  
  // CORS géré par le middleware cors() global, pas besoin de le gérer ici
  
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
app.use('/api/users', userRoutes); // Alias pour compatibilité
app.use('/api/rides', rideRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/ratings', ratingRoutes);
app.use('/api/likes', likeRoutes);
app.use('/api/garage', garageRoutes);
app.use('/api/catalog', catalogRoutes);
app.use('/api/vehicle-catalog', vehicleCatalogRoutes);
app.use('/api/admin/catalog', adminCatalogRoutes);
app.use('/api/admin/users', adminUsersRoutes);
app.use('/api/admin/rides', adminRidesRoutes);
app.use('/api/admin/groups', adminGroupsRoutes);
app.use('/api/admin/promo-codes', adminPromoCodesRoutes);
app.use('/api/feedback', feedbackRoutes);
app.use('/api/reputation', reputationRoutes);
app.use('/api/compatibility', compatibilityRoutes);
app.use('/api/live-rides', liveRideRoutes);
app.use('/api/check-in', checkInRoutes);
app.use('/api/referral', referralRoutes);
app.use('/api/auth/phone', phoneOtpRoutes); // Routes OTP avec Twilio Verify
app.use('/contact', contactRoutes);

// Route de test
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'API Balades Moto - Serveur actif'
  });
});

// ============================================================================
// ENDPOINT HEALTH CHECK
// ============================================================================
// GET /health - Vérification de l'état du serveur
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
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
  const isDevelopment = process.env.NODE_ENV === 'development';
  const baseUrl = process.env.BASE_URL || `http://${HOST === '0.0.0.0' ? 'localhost' : HOST}:${PORT}`;
  
  // Logs de base (toujours affichés)
  console.log(`🚀 Serveur démarré sur le port ${PORT}`);
  console.log(`📡 Base URL: ${baseUrl}`);
  console.log(`🌍 Environnement: ${process.env.NODE_ENV || 'development'}`);
  
  // Logs supplémentaires en développement uniquement
  if (isDevelopment) {
    console.log(`📡 Accessible depuis le réseau local`);
    console.log(`   - Local: http://localhost:${PORT}`);
    console.log(`   - LAN: http://localhost:${PORT}`);
    console.log(`💡 Pour tester depuis iPhone:`);
    console.log(`   - API: http://localhost:${PORT}/health`);
    console.log(`   - Front: http://localhost:8080`);
  }
  
  // Logs des services
  console.log(`🔌 Socket.io initialisé`);
  console.log(`⏰ Scheduler de notifications démarré`);
  
  // Logs CORS
  console.log(`\n✅ CORS configuré:`);
  console.log(`   Origines autorisées: ${getCorsInfo()}`);
  if (process.env.FRONTEND_URL) {
    console.log(`   FRONTEND_URL: ${process.env.FRONTEND_URL}`);
  }
});

module.exports = { app, server, io };

