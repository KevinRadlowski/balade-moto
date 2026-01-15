const Ride = require('../models/Ride');
const User = require('../models/User');
const Like = require('../models/Like');
const RouteCache = require('../models/RouteCache');
const icsService = require('../services/ics.service');
const https = require('https');
const PDFDocument = require('pdfkit');
const crypto = require('crypto');
const { NotFoundError, ForbiddenError, BadRequestError, ConflictError, InternalServerError, createPlanLimitError } = require('../utils/errors');
const { routeCache, geocodeCache, reverseGeocodeCache } = require('../utils/cache');
const compatibilityService = require('../services/compatibility.service');
const achievementService = require('../services/achievement.service');
const vehicleStatsService = require('../services/vehicleStats.service');
const subscriptionService = require('../services/subscription.service');

// Services et repositories (refactoring progressif)
const rideService = require('../services/ride.service');
const rideRepository = require('../repositories/ride.repository');
const dangerReportService = require('../services/danger-report.service');
const rideCancellationService = require('../services/ride-cancellation.service');
const weatherService = require('../services/weather.service');

// Helper pour normaliser un organisateur supprimé ou introuvable
function normalizeOrganizer(organisateur) {
  if (!organisateur || organisateur.isDeleted) {
    return {
      _id: organisateur?._id || null,
      id: organisateur?._id?.toString() || null,
      firstName: null,
      lastName: null,
      pseudo: 'Utilisateur supprimé',
      email: null,
      vehiclePreference: null,
      isDeleted: true
    };
  }
  return organisateur;
}

// ========== WAYPOINTS ENDPOINTS ==========

/**
 * Ajouter ou modifier un waypoint
 */
exports.addOrUpdateWaypoint = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { waypoint } = req.body;
    const ride = await rideService.addOrUpdateWaypoint(id, waypoint, req.user);
    res.status(200).json({
      success: true,
      message: 'Waypoint ajouté/modifié avec succès',
      data: { ride, waypoint: waypoint._id ? ride.waypoints.find(w => w._id.toString() === waypoint._id.toString()) : ride.waypoints[ride.waypoints.length - 1] }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Supprimer un waypoint
 */
exports.deleteWaypoint = async (req, res, next) => {
  try {
    const { id, waypointId } = req.params;
    const ride = await rideService.deleteWaypoint(id, waypointId, req.user);
    res.status(200).json({
      success: true,
      message: 'Waypoint supprimé avec succès',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Obtenir le résumé des waypoints
 */
exports.getWaypointSummary = async (req, res, next) => {
  try {
    const { id } = req.params;
    const ride = await rideService.getRideById(id, req.user);
    const summary = rideService.calculateWaypointSummary(ride);
    res.status(200).json({
      success: true,
      data: { waypointSummary: summary }
    });
  } catch (error) {
    next(error);
  }
};

// ========== DANGER REPORTS ENDPOINTS ==========

/**
 * Signaler un danger (crowdsourcing)
 */
exports.reportDanger = async (req, res, next) => {
  try {
    const { id } = req.params;
    const report = await dangerReportService.reportDanger(id, req.body, req.user);
    res.status(201).json({
      success: true,
      message: 'Signalement en attente de validation par l\'organisateur',
      data: { report }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Approuver un signalement (organisateur)
 */
exports.approveDangerReport = async (req, res, next) => {
  try {
    const { reportId } = req.params;
    const report = await dangerReportService.approveDangerReport(reportId, req.user);
    res.status(200).json({
      success: true,
      message: 'Signalement approuvé',
      data: { report }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Rejeter un signalement (organisateur)
 */
exports.rejectDangerReport = async (req, res, next) => {
  try {
    const { reportId } = req.params;
    const report = await dangerReportService.rejectDangerReport(reportId, req.user);
    res.status(200).json({
      success: true,
      message: 'Signalement rejeté',
      data: { report }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Promouvoir un signalement en waypoint (organisateur)
 */
exports.promoteDangerReportToWaypoint = async (req, res, next) => {
  try {
    const { reportId } = req.params;
    const ride = await dangerReportService.promoteDangerReportToWaypoint(reportId, req.user);
    res.status(200).json({
      success: true,
      message: 'Signalement promu en waypoint DANGER',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Lister les signalements d'une balade
 */
exports.getDangerReports = async (req, res, next) => {
  try {
    const { id } = req.params;
    const reports = await dangerReportService.getDangerReports(id, req.user);
    res.status(200).json({
      success: true,
      data: { reports }
    });
  } catch (error) {
    next(error);
  }
};

// ========== ANNULATION / REPORT / REPROGRAMMATION ==========

/**
 * Annuler une balade
 */
exports.cancelRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { reasonCode, reasonText } = req.body;
    const ride = await rideCancellationService.cancelRide(id, { reasonCode, reasonText }, req.user);
    res.status(200).json({
      success: true,
      message: 'Balade annulée avec succès',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Reporter une balade
 */
exports.postponeRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { reasonCode, reasonText, newDateTime } = req.body;
    const ride = await rideCancellationService.postponeRide(id, { reasonCode, reasonText, newDateTime }, req.user);
    res.status(200).json({
      success: true,
      message: 'Balade reportée avec succès',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Reprogrammer une balade (créer une nouvelle balade)
 */
exports.rescheduleRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { newDateTime, keepVisibility, keepParticipants } = req.body;
    const newRide = await rideCancellationService.rescheduleRide(id, { newDateTime, keepVisibility, keepParticipants }, req.user);
    res.status(201).json({
      success: true,
      message: 'Balade reprogrammée avec succès',
      data: { ride: newRide }
    });
  } catch (error) {
    next(error);
  }
};

exports.createRide = async (req, res, next) => {
  try {
    // Utiliser le service pour créer la balade
    const ride = await rideService.createRide(req.body, req.user);

    res.status(201).json({
      success: true,
      message: 'Balade créée avec succès',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

// Lister les balades avec filtres
exports.getRides = async (req, res, next) => {
  try {
    // Utiliser le service pour lister les balades
    const result = await rideService.listRides(req.query, req.user);

    // Ajouter headers de pagination
    const pagination = require('../utils/pagination');
    const paginationHeaders = pagination.buildPaginationHeaders({
      nextCursor: null,
      hasNextPage: result.pagination.page * result.pagination.limit < result.pagination.total
    });
    Object.keys(paginationHeaders).forEach(key => {
      res.setHeader(key, paginationHeaders[key]);
    });

    res.status(200).json({
      success: true,
      data: {
        rides: result.rides,
        pagination: result.pagination
      }
    });
  } catch (error) {
    next(error);
  }
};

// Récupérer les balades passées
exports.getPastRides = async (req, res) => {
  try {
    const {
      typeVehicule,
      dateFin,
      search,
      page = 1,
      limit = 50,
      sortBy = 'date',
      sortOrder = 'desc'
    } = req.query;

    // Standardiser la pagination avec limites strictes
    const pagination = require('../utils/pagination');
    const maxLimit = parseInt(process.env.PAGINATION_MAX_LIMIT) || 50;
    const defaultLimit = parseInt(process.env.PAGINATION_DEFAULT_LIMIT) || 20;
    
    // Valider et borner limit
    const validatedLimit = Math.min(
      Math.max(parseInt(limit) || defaultLimit, 1),
      maxLimit
    );
    const validatedPage = Math.max(parseInt(page) || 1, 1);

    const filter = {};

    if (typeVehicule && ['moto', 'voiture'].includes(typeVehicule)) {
      filter.typeVehicule = typeVehicule;
    }

    const nowUTC = new Date(Date.now());
    const now = new Date(Date.UTC(
      nowUTC.getUTCFullYear(),
      nowUTC.getUTCMonth(),
      nowUTC.getUTCDate(),
      nowUTC.getUTCHours(),
      nowUTC.getUTCMinutes(),
      nowUTC.getUTCSeconds(),
      nowUTC.getUTCMilliseconds()
    ));
    const tomorrow = new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() + 1,
      0, 0, 0, 0
    ));
    
    // Vérifier si l'utilisateur est premium
    const isPremium = subscriptionService.isPremiumActive(req.user);
    
    // Pour les utilisateurs standard, limiter à 3 mois d'historique
    // Pour les premium, historique illimité
    let dateFilter = { $lt: tomorrow };
    if (!isPremium) {
      // Calculer la date il y a 3 mois
      const threeMonthsAgo = new Date(Date.UTC(
        now.getUTCFullYear(),
        now.getUTCMonth() - 3,
        now.getUTCDate(),
        0, 0, 0, 0
      ));
      dateFilter = {
        $lt: tomorrow,
        $gte: threeMonthsAgo
      };
    }
    
    filter.$and = [
      {
        $or: [
          { visibilite: 'publique' },
          { organisateur: req.user._id },
          { 'participants.userId': req.user._id }
        ]
      },
      {
        date: dateFilter
      }
    ];

    if (search) {
      filter.$and.push({
        $or: [
          { titre: { $regex: search, $options: 'i' } },
          { description: { $regex: search, $options: 'i' } }
        ]
      });
    }

    const sort = {};
    sort[sortBy] = sortOrder === 'desc' ? -1 : 1;

    let rides = await Ride.find(filter)
      .populate('organisateur', 'firstName lastName pseudo email subscription.isPremium subscription.premiumExpiresAt')
      .populate('participants.userId', 'firstName lastName pseudo')
      .lean();
    
    // Trier les balades : premium en premier, puis selon le tri demandé
    rides.sort((a, b) => {
      const aIsPremium = a.organisateur && subscriptionService.isPremiumActive(a.organisateur);
      const bIsPremium = b.organisateur && subscriptionService.isPremiumActive(b.organisateur);
      
      // Premium en premier
      if (aIsPremium && !bIsPremium) return -1;
      if (!aIsPremium && bIsPremium) return 1;
      
      // Si même statut premium, trier selon sortBy
      const aValue = a[sortBy];
      const bValue = b[sortBy];
      
      if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });

    // Filtrer par date/heure
    rides = rides.filter(ride => {
      const rideDate = new Date(ride.date);
      const [hours, minutes] = ride.heure.split(':').map(Number);
      const rideDateTime = new Date(Date.UTC(
        rideDate.getUTCFullYear(),
        rideDate.getUTCMonth(),
        rideDate.getUTCDate(),
        hours,
        minutes,
        0
      ));
      return rideDateTime < now;
    });
    
    const total = rides.length;
    
    // Appliquer pagination après tri
    const skip = (validatedPage - 1) * validatedLimit;
    const paginatedRides = rides.slice(skip, skip + validatedLimit);

    // Enrichir avec les likes en batch (évite N+1)
    const rideStats = require('../utils/rideStats');
    let ridesWithLikes = await rideStats.enrichRidesWithLikes(paginatedRides, req.user._id);
    
    // Ajouter isOrganizerPremium pour chaque ride
    ridesWithLikes = ridesWithLikes.map(ride => {
      const isOrganizerPremium = ride.organisateur && 
        subscriptionService.isPremiumActive(ride.organisateur);
      
      return {
        ...ride,
        isOrganizerPremium: isOrganizerPremium || false
      };
    });

    // Ajouter headers de pagination
    const paginationHeaders = pagination.buildPaginationHeaders({
      nextCursor: null,
      hasNextPage: validatedPage * validatedLimit < total
    });
    Object.keys(paginationHeaders).forEach(key => {
      res.setHeader(key, paginationHeaders[key]);
    });

    res.status(200).json({
      success: true,
      data: {
        rides: ridesWithLikes,
        pagination: {
          page: validatedPage,
          limit: validatedLimit,
          total,
          pages: Math.ceil(total / validatedLimit)
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des balades passées',
      error: error.message
    });
  }
};

// Récupérer mes balades passées (auxquelles j'ai participé)
exports.getMyPastRides = async (req, res) => {
  try {
    const {
      typeVehicule,
      dateFin,
      search,
      page = 1,
      limit = 50,
      sortBy = 'date',
      sortOrder = 'desc'
    } = req.query;

    // Standardiser la pagination avec limites strictes
    const pagination = require('../utils/pagination');
    const maxLimit = parseInt(process.env.PAGINATION_MAX_LIMIT) || 50;
    const defaultLimit = parseInt(process.env.PAGINATION_DEFAULT_LIMIT) || 20;
    
    // Valider et borner limit
    const validatedLimit = Math.min(
      Math.max(parseInt(limit) || defaultLimit, 1),
      maxLimit
    );
    const validatedPage = Math.max(parseInt(page) || 1, 1);

    // Utiliser Date.now() pour obtenir le timestamp UTC actuel, puis créer une date UTC
    const nowUTC = new Date(Date.now());
    const now = new Date(Date.UTC(
      nowUTC.getUTCFullYear(),
      nowUTC.getUTCMonth(),
      nowUTC.getUTCDate(),
      nowUTC.getUTCHours(),
      nowUTC.getUTCMinutes(),
      nowUTC.getUTCSeconds(),
      nowUTC.getUTCMilliseconds()
    ));
    const tomorrow = new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() + 1,
      0, 0, 0, 0
    ));
    
    // Vérifier si l'utilisateur est premium
    const isPremium = subscriptionService.isPremiumActive(req.user);
    
    // Pour les utilisateurs standard, limiter à 3 mois d'historique
    // Pour les premium, historique illimité
    let dateFilter = { $lt: tomorrow };
    if (!isPremium) {
      // Calculer la date il y a 3 mois
      const threeMonthsAgo = new Date(Date.UTC(
        now.getUTCFullYear(),
        now.getUTCMonth() - 3,
        now.getUTCDate(),
        0, 0, 0, 0
      ));
      dateFilter = {
        $lt: tomorrow,
        $gte: threeMonthsAgo
      };
    }
    
    const filter = {
      $and: [
        {
          $or: [
            { organisateur: req.user._id },
            { 'participants.userId': req.user._id }
          ]
        },
        {
          date: dateFilter
        }
      ]
    };

    if (typeVehicule && ['moto', 'voiture'].includes(typeVehicule)) {
      filter.typeVehicule = typeVehicule;
    }

    if (search) {
      filter.$and.push({
        $or: [
          { titre: { $regex: search, $options: 'i' } },
          { description: { $regex: search, $options: 'i' } }
        ]
      });
    }

    const sort = {};
    sort[sortBy] = sortOrder === 'desc' ? -1 : 1;

    let rides = await Ride.find(filter)
      .populate('organisateur', 'firstName lastName pseudo email subscription.isPremium subscription.premiumExpiresAt')
      .populate('participants.userId', 'firstName lastName pseudo')
      .lean();
    
    // Trier les balades : premium en premier, puis selon le tri demandé
    rides.sort((a, b) => {
      const aIsPremium = a.organisateur && subscriptionService.isPremiumActive(a.organisateur);
      const bIsPremium = b.organisateur && subscriptionService.isPremiumActive(b.organisateur);
      
      // Premium en premier
      if (aIsPremium && !bIsPremium) return -1;
      if (!aIsPremium && bIsPremium) return 1;
      
      // Si même statut premium, trier selon sortBy
      const aValue = a[sortBy];
      const bValue = b[sortBy];
      
      if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });

    // Filtrer par date/heure
    rides = rides.filter(ride => {
      const rideDate = new Date(ride.date);
      const [hours, minutes] = ride.heure.split(':').map(Number);
      const rideDateTime = new Date(Date.UTC(
        rideDate.getUTCFullYear(),
        rideDate.getUTCMonth(),
        rideDate.getUTCDate(),
        hours,
        minutes,
        0
      ));
      return rideDateTime < now;
    });
    
    const total = rides.length;
    
    // Appliquer pagination après tri
    const skip = (validatedPage - 1) * validatedLimit;
    const paginatedRides = rides.slice(skip, skip + validatedLimit);

    // Enrichir avec les likes en batch (évite N+1)
    const rideStats = require('../utils/rideStats');
    let ridesWithLikes = await rideStats.enrichRidesWithLikes(paginatedRides, req.user._id);
    
    // Ajouter isOrganizerPremium pour chaque ride
    ridesWithLikes = ridesWithLikes.map(ride => {
      const isOrganizerPremium = ride.organisateur && 
        subscriptionService.isPremiumActive(ride.organisateur);
      
      return {
        ...ride,
        isOrganizerPremium: isOrganizerPremium || false
      };
    });

    // Ajouter headers de pagination
    const paginationHeaders = pagination.buildPaginationHeaders({
      nextCursor: null,
      hasNextPage: validatedPage * validatedLimit < total
    });
    Object.keys(paginationHeaders).forEach(key => {
      res.setHeader(key, paginationHeaders[key]);
    });

    res.status(200).json({
      success: true,
      data: {
        rides: ridesWithLikes,
        pagination: {
          page: validatedPage,
          limit: validatedLimit,
          total,
          pages: Math.ceil(total / validatedLimit)
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération de mes balades passées',
      error: error.message
    });
  }
};

/**
 * @swagger
 * /api/rides/proches:
 *   get:
 *     summary: Récupérer les balades proches d'une position GPS
 *     tags: [Rides]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: lat
 *         required: true
 *         schema:
 *           type: number
 *           format: double
 *         description: Latitude de la position de l'utilisateur
 *       - in: query
 *         name: lng
 *         required: true
 *         schema:
 *           type: number
 *           format: double
 *         description: Longitude de la position de l'utilisateur
 *       - in: query
 *         name: rayon
 *         schema:
 *           type: number
 *           format: double
 *           default: 10
 *         description: "Rayon de recherche en kilomètres (défaut 10 km, max 100 km)"
 *       - in: query
 *         name: typeVehicule
 *         schema:
 *           type: string
 *           enum: [moto, voiture]
 *         description: Filtrer par type de véhicule
 *       - in: query
 *         name: dateDebut
 *         schema:
 *           type: string
 *           format: date
 *         description: Date de début pour filtrer les balades
 *       - in: query
 *         name: dateFin
 *         schema:
 *           type: string
 *           format: date
 *         description: Date de fin pour filtrer les balades
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *           maximum: 50
 *         description: Nombre maximum de résultats
 *     responses:
 *       200:
 *         description: Liste des balades proches récupérée avec succès
 *       400:
 *         description: Paramètres invalides
 *       401:
 *         description: Non authentifié
 *       429:
 *         description: Trop de requêtes
 */
exports.getRidesNearby = async (req, res) => {
  try {
    const { latitude, longitude, rayon = 10, typeVehicule, dateDebut, dateFin, limit = 20 } = req.query;

    // Validation des paramètres requis
    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        message: 'Les paramètres latitude et longitude sont requis'
      });
    }

    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);
    const radiusKm = Math.min(parseFloat(rayon) || 10, 100); // Max 100 km
    const limitNum = Math.min(parseInt(limit) || 20, 50); // Max 50 résultats

    // Validation des coordonnées
    if (isNaN(lat) || isNaN(lng) || 
        lat < -90 || lat > 90 || 
        lng < -180 || lng > 180) {
      return res.status(400).json({
        success: false,
        message: 'Coordonnées GPS invalides. Latitude doit être entre -90 et 90, longitude entre -180 et 180'
      });
    }

    // Validation du rayon
    if (isNaN(radiusKm) || radiusKm <= 0 || radiusKm > 100) {
      return res.status(400).json({
        success: false,
        message: 'Le rayon doit être un nombre positif entre 1 et 100 kilomètres'
      });
    }

    // Construire le filtre de base
    const filter = {
      localisation: {
        $exists: true,
        $ne: null
      },
      $or: [
        { visibilite: 'publique' },
        { organisateur: req.user._id },
        { 'participants.userId': req.user._id },
        { 'invitations.userId': req.user._id, 'invitations.status': { $in: ['pending', 'accepted'] } }
      ]
    };

    if (typeVehicule && ['moto', 'voiture'].includes(typeVehicule)) {
      filter.typeVehicule = typeVehicule;
    }

    if (dateDebut || dateFin) {
      filter.date = {};
      if (dateDebut) {
        filter.date.$gte = new Date(dateDebut);
      }
      if (dateFin) {
        filter.date.$lte = new Date(dateFin);
      }
    } else {
      // Par défaut, ne montrer que les balades futures
      filter.date = { $gte: new Date() };
    }

    // Requête géospatiale avec $geoNear (nécessite un index 2dsphere)
    // Note: $geoNear doit être la première étape d'une aggregation pipeline
    const pipeline = [
      {
        $geoNear: {
          near: {
            type: 'Point',
            coordinates: [lng, lat] // MongoDB utilise [lng, lat]
          },
          distanceField: 'distance',
          maxDistance: radiusKm * 1000, // Convertir km en mètres
          spherical: true,
          query: filter
        }
      },
      {
        $lookup: {
          from: 'users',
          localField: 'organisateur',
          foreignField: '_id',
          as: 'organisateur'
        }
      },
      {
        $unwind: {
          path: '$organisateur',
          preserveNullAndEmptyArrays: true
        }
      },
      {
        // Ajouter un champ isOrganizerPremium pour le tri
        $addFields: {
          isOrganizerPremium: {
            $cond: {
              if: {
                $and: [
                  { $ne: ['$organisateur', null] },
                  { $eq: ['$organisateur.subscription.isPremium', true] },
                  {
                    $or: [
                      { $eq: ['$organisateur.subscription.premiumExpiresAt', null] },
                      { $gte: ['$organisateur.subscription.premiumExpiresAt', new Date()] }
                    ]
                  }
                ]
              },
              then: 1,
              else: 0
            }
          }
        }
      },
      {
        $lookup: {
          from: 'users',
          localField: 'participants',
          foreignField: '_id',
          as: 'participants'
        }
      },
      {
        $project: {
          'organisateur.password': 0,
          'organisateur.refreshToken': 0,
          'participants.password': 0,
          'participants.refreshToken': 0
        }
      },
      {
        $sort: {
          isOrganizerPremium: -1, // Premium en premier
          distance: 1, // Plus proche en premier
          date: 1 // Puis par date
        }
      },
      {
        $limit: limitNum
      }
    ];

    const rides = await Ride.aggregate(pipeline);

    // Enrichir avec les likes en batch (évite N+1)
    const rideStats = require('../utils/rideStats');
    let ridesWithLikes = await rideStats.enrichRidesWithLikes(rides, req.user._id);
    
    // Ajouter isOrganizerPremium et formater pour chaque ride
    ridesWithLikes = ridesWithLikes.map(ride => {
      const isOrganizerPremium = ride.organisateur && 
        subscriptionService.isPremiumActive(ride.organisateur);
      
      // Convertir _id en string pour la compatibilité
      const rideObj = {
        ...ride,
        id: ride._id ? ride._id.toString() : ride.id,
        distance: ride.distance ? (ride.distance / 1000).toFixed(2) : null, // Convertir en km
        isOrganizerPremium: isOrganizerPremium || false
      };
      if (rideObj._id) delete rideObj._id;
      return rideObj;
    });

    res.status(200).json({
      success: true,
      data: {
        rides: ridesWithLikes,
        position: {
          latitude,
          longitude
        },
        rayon: radiusKm,
        total: ridesWithLikes.length
      }
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des balades proches:', error);
    
    // Gérer les erreurs spécifiques à MongoDB
    if (error.message && error.message.includes('geoNear')) {
      return res.status(400).json({
        success: false,
        message: 'Erreur de requête géospatiale. Vérifiez que les balades ont des coordonnées GPS valides et qu\'un index 2dsphere existe sur le champ localisation.'
      });
    }

    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des balades proches',
      error: error.message
    });
  }
};

// Obtenir les détails d'une balade
exports.getRideById = async (req, res, next) => {
  try {
    const { id } = req.params;

    const ride = await Ride.findById(id)
      .populate('organisateur', 'firstName lastName pseudo email vehiclePreference subscription.isPremium subscription.premiumExpiresAt')
      .populate('participants.userId', 'firstName lastName pseudo')
      .populate('invitations.userId', 'firstName lastName pseudo')
      .populate('likes', 'firstName lastName pseudo');

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Normaliser l'organisateur si supprimé
    ride.organisateur = normalizeOrganizer(ride.organisateur);

    // Vérifier la visibilité
    const isOrganizer = ride.organisateur && ride.organisateur._id && 
      ride.organisateur._id.toString() === req.user._id.toString();
    const isParticipant = ride.participants.some(
      p => p.userId && (p.userId._id ? p.userId._id.toString() : p.userId.toString()) === req.user._id.toString()
    );
    const isInvited = ride.invitations && ride.invitations.some(
      inv => inv.userId && (inv.userId._id ? inv.userId._id.toString() : inv.userId.toString()) === req.user._id.toString() &&
      (inv.status === 'pending' || inv.status === 'accepted')
    );

    if (ride.visibilite === 'privee') {
      if (!isOrganizer && !isParticipant && !isInvited) {
        return res.status(403).json({
          success: false,
          message: 'Vous n\'avez pas accès à cette balade privée'
        });
      }
    } else if (ride.visibilite === 'secrete') {
      // Les balades secrètes ne sont accessibles que par l'organisateur, les participants, ou via le lien secret
      if (!isOrganizer && !isParticipant) {
        return res.status(403).json({
          success: false,
          message: 'Cette balade est secrète. Accès uniquement via le lien secret.'
        });
      }
    }

    // Enrichir avec les likes (utilise batch même pour un seul ride)
    const rideStats = require('../utils/rideStats');
    const enrichedRides = await rideStats.enrichRidesWithLikes([ride], req.user._id);
    const enrichedRide = enrichedRides[0] || ride;

    // Convertir en objet si nécessaire
    const rideObj = ride.toObject ? ride.toObject() : { ...ride };
    rideObj.totalLikes = enrichedRide.totalLikes || 0;
    rideObj.hasUserLiked = enrichedRide.hasUserLiked || false;
    // S'assurer que l'organisateur est normalisé dans l'objet
    rideObj.organisateur = normalizeOrganizer(rideObj.organisateur);
    // Calculer isOrganizerPremium
    rideObj.isOrganizerPremium = ride.organisateur && 
      subscriptionService.isPremiumActive(ride.organisateur) || false;

    res.status(200).json({
      success: true,
      data: { ride: rideObj }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID de balade invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération de la balade',
      error: error.message
    });
  }
};

// Modifier une balade (uniquement par l'organisateur)
exports.updateRide = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Utiliser le service pour mettre à jour la balade
    const ride = await rideService.updateRide(id, req.body, req.user);

    res.status(200).json({
      success: true,
      message: 'Balade modifiée avec succès',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

// Supprimer une balade (uniquement par l'organisateur)
exports.deleteRide = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Utiliser le service pour supprimer la balade
    await rideService.deleteRide(id, req.user);

    res.status(200).json({
      success: true,
      message: 'Balade supprimée avec succès'
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Associer une balade à un groupe
 */
exports.associateRideToGroup = async (req, res, next) => {
  try {
    const { id: rideId } = req.params;
    const { groupId } = req.body;

    if (!groupId) {
      return next(new BadRequestError('Le groupId est requis'));
    }

    const ride = await rideService.associateRideToGroup(rideId, groupId, req.user);

    res.status(200).json({
      success: true,
      message: 'Balade associée au groupe avec succès',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

// Rejoindre une balade
exports.joinRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { vehicleId } = req.body; // Véhicule optionnel avec lequel participer

    // Utiliser le service pour rejoindre la balade
    const result = await rideService.joinRide(id, req.user, vehicleId);

    // Construire la réponse selon le statut
    if (result.status === 'pending_approval') {
      return res.status(200).json({
        success: true,
        message: 'Demande envoyée. L\'organisateur doit approuver votre participation.',
        data: { status: 'pending_approval' }
      });
    }

    if (result.status === 'waitlisted') {
      return res.status(200).json({
        success: true,
        message: `Balade complète. Vous êtes en position ${result.position} sur la liste d'attente.`,
        data: { 
          ride: result.ride,
          status: 'waitlisted', 
          position: result.position 
        }
      });
    }

    // Statut 'joined'
    res.status(200).json({
      success: true,
      message: 'Vous avez rejoint la balade avec succès',
      data: { 
        ride: result.ride,
        status: 'joined',
        compatibility: result.compatibility || undefined
      }
    });
  } catch (error) {
    next(error);
  }
};

// Quitter une balade
exports.leaveRide = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Utiliser le service pour quitter la balade
    const ride = await rideService.leaveRide(id, req.user);

    res.status(200).json({
      success: true,
      message: 'Vous avez quitté la balade avec succès',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

// Liker une balade
exports.likeRide = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Utiliser le service pour liker la balade
    await rideService.likeRide(id, req.user);

    // Récupérer la balade mise à jour pour la réponse
    const ride = await rideService.getRideById(id, req.user);

    res.status(200).json({
      success: true,
      message: 'Balade likée avec succès',
      data: { ride, liked: true }
    });
  } catch (error) {
    next(error);
  }
};

// Noter une balade
exports.rateRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { note } = req.body;

    if (!note || note < 0 || note > 5) {
      return res.status(400).json({
        success: false,
        message: 'La note doit être entre 0 et 5'
      });
    }

    const ride = await Ride.findById(id);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier que l'utilisateur est participant
    const isParticipant = ride.participants.some(
      p => p.userId && p.userId.toString() === req.user._id.toString()
    );

    if (!isParticipant) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être participant pour noter cette balade'
      });
    }

    // Vérifier si l'utilisateur a déjà noté
    const existingNoteIndex = ride.notes.findIndex(
      n => n.userId.toString() === req.user._id.toString()
    );

    if (existingNoteIndex !== -1) {
      // Mettre à jour la note existante
      ride.notes[existingNoteIndex].note = note;
      ride.notes[existingNoteIndex].createdAt = new Date();
    } else {
      // Ajouter une nouvelle note
      ride.notes.push({
        userId: req.user._id,
        note: note
      });
    }

    // La note moyenne sera calculée automatiquement par le pre-save hook
    await ride.save();

    res.status(200).json({
      success: true,
      message: 'Note ajoutée avec succès',
      data: { ride }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID de balade invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'ajout de la note',
      error: error.message
    });
  }
};

// Marquer une balade comme terminée et mettre à jour les stats
exports.completeRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { distanceKm, cost } = req.body;
    const userId = req.user._id;

    const ride = await Ride.findById(id);

    if (!ride) {
      throw new NotFoundError('Balade non trouvée');
    }

    // Normaliser l'organisateur si supprimé
    ride.organisateur = normalizeOrganizer(ride.organisateur);

    // Vérifier que l'utilisateur est l'organisateur
    const isOrganizer = ride.organisateur && ride.organisateur._id && 
      ride.organisateur._id.toString() === userId.toString();
    
    if (!isOrganizer) {
      throw new ForbiddenError('Seul l\'organisateur peut marquer la balade comme terminée');
    }

    // Vérifier que la balade est en cours
    if (ride.status !== 'in_progress') {
      throw new BadRequestError('La balade doit être en cours pour être terminée');
    }

    // Mettre à jour le statut
    ride.status = 'completed';

    // Ajouter un événement
    ride.rideEvents.push({
      type: 'completed',
      timestamp: new Date(),
      userId: userId,
      details: {}
    });

    await ride.save();

    // Mettre à jour les stats véhicule pour tous les participants
    const Vehicle = require('../models/Vehicle');
    for (const participantId of ride.participants) {
      try {
        // Trouver le véhicule actif du participant
        const vehicle = await Vehicle.findOne({
          ownerUserId: participantId,
          active: true,
          type: ride.typeVehicule
        });

        if (vehicle) {
          // Mettre à jour les stats
          await vehicleStatsService.updateStatsOnRideCompletion(vehicle._id, {
            distanceKm: distanceKm || 0,
            cost: cost || 0
          });

          // Vérifier et débloquer les badges
          await achievementService.checkAndAwardAchievements(
            participantId.toString(),
            'ride_completed',
            { rideId: ride._id }
          );
        }
      } catch (error) {
        console.error(`Erreur lors de la mise à jour des stats pour ${participantId}:`, error);
      }
    }

    // Mettre à jour la réputation de tous les participants
    const reputationService = require('../services/reputation.service');
    for (const participantId of ride.participants) {
      try {
        await reputationService.calculateReputationScore(participantId.toString());
      } catch (error) {
        console.error(`Erreur lors de la mise à jour de la réputation pour ${participantId}:`, error);
      }
    }

    await ride.populate('organisateur', 'firstName lastName pseudo');
    await ride.populate('participants.userId', 'firstName lastName pseudo');

    res.json({
      success: true,
      message: 'Balade marquée comme terminée',
      data: { ride }
    });
  } catch (error) {
    next(error);
  }
};

// Obtenir le calendrier des balades à venir
exports.getCalendar = async (req, res, next) => {
  try {
    const { startDate, endDate, includeICS } = req.query;

    // Construire le filtre pour les balades à venir
    const filter = {
      date: { $gte: new Date() }
    };

    if (startDate) {
      filter.date.$gte = new Date(startDate);
    }
    if (endDate) {
      filter.date.$lte = new Date(endDate);
    }

    // Inclure les balades publiques et celles où l'utilisateur est participant/organisateur
    filter.$or = [
      { visibilite: 'publique' },
      { organisateur: req.user._id },
      { 'participants.userId': req.user._id }
    ];

    // Récupérer les balades
    const rides = await Ride.find(filter)
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo')
      .sort({ date: 1, heure: 1 });

    // Formater les balades pour le calendrier
    const calendarEvents = rides.map(ride => {
      const rideDate = new Date(ride.date);
      const [hours, minutes] = ride.heure.split(':').map(Number);
      rideDate.setHours(hours, minutes, 0, 0);

      const endDate = new Date(rideDate);
      endDate.setHours(endDate.getHours() + 1); // Durée par défaut: 1h

      const event = {
        id: ride._id.toString(),
        title: ride.titre,
        start: rideDate.toISOString(),
        end: endDate.toISOString(),
        description: ride.description || '',
        location: typeof ride.lieuDepart === 'string' 
          ? `${ride.lieuDepart} → ${ride.lieuArrivee}`
          : `${JSON.stringify(ride.lieuDepart)} → ${JSON.stringify(ride.lieuArrivee)}`,
        typeVehicule: ride.typeVehicule,
        organisateur: {
          id: ride.organisateur._id.toString(),
          name: ride.organisateur.firstName && ride.organisateur.lastName
            ? `${ride.organisateur.firstName} ${ride.organisateur.lastName}`
            : ride.organisateur.pseudo || ride.organisateur.email,
          email: ride.organisateur.email
        },
        participants: ride.participants.length,
        visibilite: ride.visibilite,
        noteMoyenne: ride.noteMoyenne,
        url: `${process.env.FRONTEND_URL || 'http://localhost:3000'}/rides/${ride._id}`,
        icsUrl: `${process.env.FRONTEND_URL || 'http://localhost:3000'}/api/rides/${ride._id}/ics`
      };

      return event;
    });

    // Générer l'ICS global si demandé
    let globalICS = null;
    if (includeICS === 'true') {
      try {
        const icsService = require('../services/ics.service');
        const rideIds = rides.map(r => r._id);
        globalICS = await icsService.generateMultipleICS(rideIds);
      } catch (error) {
        console.error('Erreur génération ICS global:', error);
      }
    }

    res.status(200).json({
      success: true,
      data: {
        events: calendarEvents,
        total: calendarEvents.length,
        ics: globalICS || undefined
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération du calendrier',
      error: error.message
    });
  }
};

// Exporter une balade en format ICS
exports.exportRideICS = async (req, res, next) => {
  try {
    const { id } = req.params;

    const ride = await Ride.findById(id);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier l'accès
    if (ride.visibilite === 'privee') {
      const isOrganizer = ride.organisateur.toString() === req.user._id.toString();
      const isParticipant = ride.participants.some(
        p => p.toString() === req.user._id.toString()
      );
      
      if (!isOrganizer && !isParticipant) {
        return res.status(403).json({
          success: false,
          message: 'Vous n\'avez pas accès à cette balade'
        });
      }
    }

    const icsService = require('../services/ics.service');
    const icsContent = await icsService.generateICS(id);

    // Définir les headers pour le téléchargement
    res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="balade-${id}.ics"`);

    res.send(icsContent);
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la génération du fichier ICS',
      error: error.message
    });
  }
};

// Calculer un itinéraire via Google Directions API (pour éviter CORS)
exports.calculateRoute = async (req, res, next) => {
  try {
    const { origin, destination, waypoints, avoidTolls, avoidHighways } = req.query;

    // Validation des paramètres requis
    if (!origin || !destination) {
      return next(new BadRequestError('Les paramètres origin et destination sont requis'));
    }

    // Construire le paramètre avoid pour Google Directions
    const avoidParams = [];
    if (avoidTolls === 'true') {
      avoidParams.push('tolls');
    }
    if (avoidHighways === 'true') {
      avoidParams.push('highways');
    }
    const avoidParam = avoidParams.length > 0 ? avoidParams.join('|') : null;

    // Générer une clé de cache unique basée sur les paramètres
    const waypointsStr = waypoints || '';
    const avoidStr = avoidParam || '';
    const cacheKeyString = `${origin}|${destination}|${waypointsStr}|${avoidStr}`;
    const cacheKeyHash = crypto.createHash('sha256').update(cacheKeyString).digest('hex');

    // Vérifier d'abord le cache en mémoire (pour les requêtes récentes)
    const memoryCacheKey = { 
      origin, 
      destination, 
      waypoints: waypointsStr,
      avoid: avoidStr
    };
    const memoryCached = routeCache.get(memoryCacheKey);
    if (memoryCached) {
      return res.status(200).json(memoryCached);
    }

    // Vérifier le cache MongoDB (persistant)
    const dbCached = await RouteCache.findOne({ cacheKey: cacheKeyHash });
    if (dbCached) {
      const responseData = {
        success: true,
        data: dbCached.directionsData
      };
      // Mettre aussi en cache mémoire pour les prochaines requêtes
      routeCache.set(memoryCacheKey, responseData);
      return res.status(200).json(responseData);
    }

    // Construire l'URL de l'API Directions
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return next(new InternalServerError('Configuration serveur incomplète : clé API Google Maps manquante'));
    }
    let url = `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&mode=driving&key=${apiKey}`;
    
    if (waypoints && waypoints.trim() !== '') {
      url += `&waypoints=${encodeURIComponent(waypoints)}`;
    }
    
    if (avoidParam) {
      url += `&avoid=${encodeURIComponent(avoidParam)}`;
    }

    // Faire la requête à l'API Directions
    const urlObj = new URL(url);
    
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: 'GET'
    };

    return new Promise((resolve, reject) => {
      const request = https.request(options, (response) => {
        let data = '';

        response.on('data', (chunk) => {
          data += chunk;
        });

        response.on('end', async () => {
          try {
            const jsonData = JSON.parse(data);
            
            if (jsonData.status === 'OK') {
              const responseData = {
                success: true,
                data: jsonData
              };
              
              // Mettre en cache mémoire (pour les requêtes récentes)
              routeCache.set(memoryCacheKey, responseData);
              
              // Mettre en cache MongoDB (persistant) - ne pas bloquer la réponse
              RouteCache.findOneAndUpdate(
                { cacheKey: cacheKeyHash },
                {
                  cacheKey: cacheKeyHash,
                  origin,
                  destination,
                  waypoints: waypointsStr,
                  avoid: avoidStr,
                  directionsData: jsonData,
                  createdAt: new Date()
                },
                { upsert: true, new: true }
              ).catch((cacheError) => {
                // Ne pas bloquer la réponse si le cache échoue
                console.error('Erreur lors de la mise en cache MongoDB:', cacheError);
              });
              
              res.status(200).json(responseData);
            } else {
              return next(new BadRequestError(`Erreur Directions API: ${jsonData.status} - ${jsonData.error_message || 'Erreur inconnue'}`));
            }
          } catch (error) {
            return next(new InternalServerError(`Erreur lors du parsing de la réponse: ${error.message}`));
          }
        });
      });

      request.on('error', (error) => {
        return next(new InternalServerError(`Erreur lors de la requête à l'API Directions: ${error.message}`));
      });

      request.end();
    });
  } catch (error) {
    return next(new InternalServerError(`Erreur lors du calcul de l'itinéraire: ${error.message}`));
  }
};

// Géocoder une adresse via Google Maps Geocoding API (pour éviter CORS)
// Géocodage inverse (coordonnées -> adresse)
// Autocomplete Places
exports.placesAutocomplete = async (req, res, next) => {
  try {
    const { input } = req.query;

    if (!input || input.trim().length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Le paramètre "input" est requis et doit contenir au moins 2 caractères'
      });
    }

    // Construire l'URL de l'API Places Autocomplete
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return next(new InternalServerError('Configuration serveur incomplète : clé API Google Maps manquante'));
    }

    const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(input.trim())}&key=${apiKey}&language=fr&components=country:fr`;

    // Faire la requête à l'API Places Autocomplete
    const urlObj = new URL(url);
    
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: 'GET'
    };

    return new Promise((resolve, reject) => {
      const request = https.request(options, (response) => {
        let data = '';

        response.on('data', (chunk) => {
          data += chunk;
        });

        response.on('end', () => {
          try {
            const jsonData = JSON.parse(data);
            
            if (jsonData.status === 'OK' || jsonData.status === 'ZERO_RESULTS') {
              const responseData = {
                success: true,
                data: {
                  predictions: jsonData.predictions || []
                }
              };
              res.status(200).json(responseData);
            } else {
              return next(new BadRequestError(`Erreur Places Autocomplete API: ${jsonData.status} - ${jsonData.error_message || 'Aucun résultat'}`));
            }
          } catch (error) {
            return next(new InternalServerError(`Erreur lors du parsing de la réponse: ${error.message}`));
          }
        });
      });

      request.on('error', (error) => {
        return next(new InternalServerError(`Erreur lors de la requête à l'API Places: ${error.message}`));
      });

      request.end();
    });
  } catch (error) {
    return next(new InternalServerError(`Erreur lors de l'autocomplete Places: ${error.message}`));
  }
};

// Place Details
/**
 * Récupère la météo pour une balade (départ et arrivée)
 */
exports.getRideWeather = async (req, res, next) => {
  try {
    const { id } = req.params;
    const ride = await rideService.getRideById(id, req.user);
    
    if (!ride) {
      return next(new NotFoundError('Balade'));
    }

    // Récupérer la météo
    const weather = await weatherService.getRideWeather(ride);

    // Si la météo est null (clé API non configurée), retourner un message explicite
    if (!weather) {
      return res.status(503).json({
        success: false,
        message: 'Service météo temporairement indisponible. La clé API OpenWeatherMap n\'est pas configurée.',
        code: 'WEATHER_SERVICE_UNAVAILABLE'
      });
    }

    res.status(200).json({
      success: true,
      data: weather
    });
  } catch (error) {
    // Si erreur liée à la clé API, retourner un message plus clair
    if (error.message && error.message.includes('WEATHER_API_KEY')) {
      return res.status(503).json({
        success: false,
        message: 'Service météo temporairement indisponible. La clé API OpenWeatherMap n\'est pas configurée.',
        code: 'WEATHER_SERVICE_UNAVAILABLE'
      });
    }
    next(error);
  }
};

exports.placeDetails = async (req, res, next) => {
  try {
    const { placeId } = req.query;

    if (!placeId) {
      return res.status(400).json({
        success: false,
        message: 'Le paramètre "placeId" est requis'
      });
    }

    // Construire l'URL de l'API Place Details
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return next(new InternalServerError('Configuration serveur incomplète : clé API Google Maps manquante'));
    }

    const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${encodeURIComponent(placeId)}&key=${apiKey}&language=fr&fields=address_components,geometry,formatted_address,name`;

    // Faire la requête à l'API Place Details
    const urlObj = new URL(url);
    
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: 'GET'
    };

    return new Promise((resolve, reject) => {
      const request = https.request(options, (response) => {
        let data = '';

        response.on('data', (chunk) => {
          data += chunk;
        });

        response.on('end', () => {
          try {
            const jsonData = JSON.parse(data);
            
            if (jsonData.status === 'OK' && jsonData.result) {
              const responseData = {
                success: true,
                data: jsonData.result
              };
              res.status(200).json(responseData);
            } else {
              return next(new BadRequestError(`Erreur Place Details API: ${jsonData.status} - ${jsonData.error_message || 'Lieu non trouvé'}`));
            }
          } catch (error) {
            return next(new InternalServerError(`Erreur lors du parsing de la réponse: ${error.message}`));
          }
        });
      });

      request.on('error', (error) => {
        return next(new InternalServerError(`Erreur lors de la requête à l'API Place Details: ${error.message}`));
      });

      request.end();
    });
  } catch (error) {
    return next(new InternalServerError(`Erreur lors de la récupération des détails du lieu: ${error.message}`));
  }
};

exports.reverseGeocode = async (req, res, next) => {
  try {
    const { lat, lng } = req.query;

    // Vérifier le cache
    const cacheKey = { lat: parseFloat(lat), lng: parseFloat(lng) };
    const cached = reverseGeocodeCache.get(cacheKey);
    if (cached) {
      return res.status(200).json(cached);
    }

    // Construire l'URL de l'API Geocoding inverse
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return next(new InternalServerError('Configuration serveur incomplète : clé API Google Maps manquante'));
    }
    const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${apiKey}&language=fr`;

    // Faire la requête à l'API Geocoding
    const urlObj = new URL(url);
    
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: 'GET'
    };

    return new Promise((resolve, reject) => {
      const request = https.request(options, (response) => {
        let data = '';

        response.on('data', (chunk) => {
          data += chunk;
        });

        response.on('end', () => {
          try {
            const result = JSON.parse(data);
            
            if (result.status === 'OK' && result.results && result.results.length > 0) {
              const addressComponents = result.results[0].address_components;
              const formattedAddress = result.results[0].formatted_address;
              
              // Extraire les informations importantes
              let streetNumber = '';
              let streetName = '';
              let postalCode = '';
              let locality = '';
              let country = '';
              
              addressComponents.forEach(component => {
                const types = component.types;
                if (types.includes('street_number')) {
                  streetNumber = component.long_name || component.short_name || '';
                }
                if (types.includes('route')) {
                  streetName = component.long_name || component.short_name || '';
                }
                if (types.includes('postal_code')) {
                  postalCode = component.long_name || component.short_name || '';
                }
                // Essayer plusieurs types pour la localité
                if (types.includes('locality')) {
                  locality = component.long_name || component.short_name || locality;
                } else if (types.includes('administrative_area_level_2')) {
                  if (!locality) {
                    locality = component.long_name || component.short_name || '';
                  }
                } else if (types.includes('sublocality') || types.includes('sublocality_level_1')) {
                  if (!locality) {
                    locality = component.long_name || component.short_name || '';
                  }
                }
                if (types.includes('country')) {
                  country = component.long_name || component.short_name || '';
                }
              });
              
              // Combiner le numéro et le nom de la rue
              let street = '';
              if (streetNumber && streetName) {
                street = `${streetNumber} ${streetName}`;
              } else if (streetName) {
                street = streetName;
              } else if (streetNumber) {
                street = streetNumber;
              }
              
              // Construire une adresse formatée complète
              // Priorité: rue + code postal + ville, sinon code postal + ville, sinon ville seule
              let address = formattedAddress || '';
              
              // Si on a tous les éléments, construire l'adresse complète
              if (street && postalCode && locality) {
                address = `${street}, ${postalCode} ${locality}`;
              } else if (postalCode && locality) {
                // Au moins code postal + ville
                address = `${postalCode} ${locality}`;
              } else if (street && locality) {
                // Rue + ville
                address = `${street}, ${locality}`;
              } else if (locality) {
                // Juste la ville
                address = locality;
              } else if (postalCode) {
                // Juste le code postal
                address = postalCode;
              } else if (street) {
                // Juste la rue
                address = street;
              }
              
              // Si l'adresse est toujours vide, utiliser formattedAddress
              if (!address || address.trim() === '') {
                address = formattedAddress || 'Adresse non disponible';
              }
              
              const responseData = {
                success: true,
                data: {
                  address: address,
                  formattedAddress: formattedAddress,
                  street: street,
                  postalCode: postalCode,
                  locality: locality,
                  country: country
                }
              };
              // Mettre en cache
              reverseGeocodeCache.set(cacheKey, responseData);
              resolve(res.json(responseData));
            } else {
              resolve(next(new NotFoundError('Adresse non trouvée pour ces coordonnées')));
            }
          } catch (error) {
            reject(next(new InternalServerError(`Erreur lors du traitement de la réponse: ${error.message}`)));
          }
        });
      });

      request.on('error', (error) => {
        reject(next(new InternalServerError(`Erreur lors de la requête à l'API Google Maps: ${error.message}`)));
      });

      request.end();
    });
  } catch (error) {
    return next(new InternalServerError(`Erreur lors du géocodage inverse: ${error.message}`));
  }
};

exports.geocodeAddress = async (req, res, next) => {
  try {
    const { address } = req.query;

    // Vérifier le cache
    const cacheKey = { address };
    const cached = geocodeCache.get(cacheKey);
    if (cached) {
      return res.status(200).json(cached);
    }

    // Construire l'URL de l'API Geocoding
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return next(new InternalServerError('Configuration serveur incomplète : clé API Google Maps manquante'));
    }
    const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${apiKey}`;

    // Faire la requête à l'API Geocoding
    const urlObj = new URL(url);
    
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: 'GET'
    };

    return new Promise((resolve, reject) => {
      const request = https.request(options, (response) => {
        let data = '';

        response.on('data', (chunk) => {
          data += chunk;
        });

        response.on('end', () => {
          try {
            const jsonData = JSON.parse(data);
            
            if (jsonData.status === 'OK' && jsonData.results && jsonData.results.length > 0) {
              const result = jsonData.results[0];
              const location = result.geometry.location;
              
              const responseData = {
                success: true,
                data: {
                  address: result.formatted_address,
                  latitude: location.lat,
                  longitude: location.lng,
                  placeId: result.place_id
                }
              };
              // Mettre en cache
              geocodeCache.set(cacheKey, responseData);
              res.status(200).json(responseData);
            } else {
              return next(new BadRequestError(`Erreur Geocoding API: ${jsonData.status} - ${jsonData.error_message || 'Adresse non trouvée'}`));
            }
          } catch (error) {
            return next(new InternalServerError(`Erreur lors du parsing de la réponse: ${error.message}`));
          }
        });
      });

      request.on('error', (error) => {
        return next(new InternalServerError(`Erreur lors de la requête à l'API Geocoding: ${error.message}`));
      });

      request.end();
    });
  } catch (error) {
    return next(new InternalServerError(`Erreur lors du géocodage de l'adresse: ${error.message}`));
  }
};

// Indiquer son arrivée au lieu de départ (pour un participant)
exports.markArrival = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const ride = await Ride.findById(id);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier que l'utilisateur est bien participant
    const participant = ride.participants.find(
      p => p.userId && p.userId.toString() === userId.toString()
    );

    if (!participant) {
      return res.status(403).json({
        success: false,
        message: 'Vous n\'êtes pas participant à cette balade'
      });
    }

    // Vérifier que l'arrivée n'a pas déjà été enregistrée
    if (participant.arrivalTime) {
      return res.status(400).json({
        success: false,
        message: 'Votre arrivée a déjà été enregistrée'
      });
    }

    // Enregistrer l'heure d'arrivée
    participant.arrivalTime = new Date();
    await ride.save();

    await ride.populate('participants.userId', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: 'Votre arrivée a été enregistrée',
      data: {
        ride,
        arrivalTime: participant.arrivalTime
      }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID de balade invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'enregistrement de l\'arrivée',
      error: error.message
    });
  }
};

// Valider/invalider la ponctualité d'un participant (pour l'organisateur)
exports.validatePunctuality = async (req, res) => {
  try {
    const { id, userId } = req.params;
    const { isOnTime } = req.body; // true = à l'heure, false = en retard

    if (typeof isOnTime !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'Le paramètre isOnTime doit être un booléen (true ou false)'
      });
    }

    const ride = await Ride.findById(id);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Normaliser l'organisateur si supprimé
    ride.organisateur = normalizeOrganizer(ride.organisateur);

    // Vérifier que l'utilisateur est l'organisateur
    const isOrganizer = ride.organisateur && ride.organisateur._id && 
      ride.organisateur._id.toString() === req.user._id.toString();
    
    if (!isOrganizer) {
      return res.status(403).json({
        success: false,
        message: 'Seul l\'organisateur peut valider la ponctualité'
      });
    }

    // Trouver le participant
    const participant = ride.participants.find(
      p => p.userId && p.userId.toString() === userId.toString()
    );

    if (!participant) {
      return res.status(404).json({
        success: false,
        message: 'Participant non trouvé dans cette balade'
      });
    }

    // Si le participant n'a pas encore indiqué son arrivée, l'enregistrer automatiquement
    // Cela permet à l'organisateur de valider la ponctualité même si le participant a oublié de marquer son arrivée
    if (!participant.arrivalTime) {
      // Utiliser l'heure de début de la balade comme heure d'arrivée par défaut
      // Si le participant est dans la balade en cours, c'est qu'il était présent au départ
      const rideDateTime = new Date(ride.date);
      const [hours, minutes] = ride.heure.split(':').map(Number);
      rideDateTime.setHours(hours, minutes, 0, 0);
      
      // Utiliser l'heure de début de la balade comme heure d'arrivée par défaut
      participant.arrivalTime = rideDateTime;
    }

    // Valider/invalider la ponctualité
    participant.isOnTime = isOnTime;
    participant.validatedBy = req.user._id;
    participant.validatedAt = new Date();

    await ride.save();

    // Mettre à jour le score de ponctualité du participant
    const reputationService = require('../services/reputation.service');
    try {
      await reputationService.calculateReputationScore(userId);
    } catch (error) {
      console.warn('Erreur lors de la mise à jour du score de ponctualité:', error);
      // Ne pas bloquer la réponse si le calcul échoue
    }

    await ride.populate('participants.userId', 'firstName lastName pseudo');
    await ride.populate('participants.validatedBy', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: isOnTime 
        ? 'Le participant a été marqué comme étant à l\'heure'
        : 'Le participant a été marqué comme étant en retard',
      data: {
        ride,
        participant: {
          userId: participant.userId,
          arrivalTime: participant.arrivalTime,
          isOnTime: participant.isOnTime,
          validatedAt: participant.validatedAt
        }
      }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la validation de la ponctualité',
      error: error.message
    });
  }
};

// Reprendre l'organisation d'une balade si l'organisateur est supprimé
exports.claimOrganizer = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    // Vérifier que l'utilisateur n'est pas supprimé
    if (req.user.isDeleted) {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez pas reprendre l\'organisation d\'une balade avec un compte supprimé'
      });
    }

    // Récupérer la balade
    const ride = await Ride.findById(id);
    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier que l'utilisateur est participant
    const isParticipant = ride.participants.some(
      p => p.userId && p.userId.toString() === userId.toString()
    );

    if (!isParticipant) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être participant de cette balade pour reprendre l\'organisation'
      });
    }

    // Vérifier que l'organisateur actuel est supprimé ou introuvable
    const currentOrganizer = await User.findById(ride.organisateur);
    const isOrganizerDeleted = !currentOrganizer || currentOrganizer.isDeleted;

    if (!isOrganizerDeleted) {
      return res.status(409).json({
        success: false,
        message: 'L\'organisateur actuel est toujours actif. Vous ne pouvez pas reprendre l\'organisation'
      });
    }

    // Update atomique : transférer l'organisation
    const updatedRide = await Ride.findOneAndUpdate(
      {
        _id: id,
        // Double vérification : l'utilisateur doit être participant
        'participants.userId': userId
      },
      {
        $set: {
          organisateur: userId
        }
      },
      {
        new: true,
        runValidators: true
      }
    );

    if (!updatedRide) {
      // Cas de concurrence : la balade a changé entre temps
      return res.status(409).json({
        success: false,
        message: 'La balade a été modifiée. Veuillez réessayer'
      });
    }

    // Populate pour la réponse
    await updatedRide.populate('organisateur', 'firstName lastName pseudo email');
    await updatedRide.populate('participants.userId', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: 'Vous avez repris l\'organisation de cette balade',
      data: {
        ride: updatedRide
      }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la reprise de l\'organisation',
      error: error.message
    });
  }
};

// Inviter des utilisateurs à une balade privée
exports.inviteUsersToRide = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { userIds } = req.body;

    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Vous devez fournir au moins un utilisateur à inviter'
      });
    }

    const ride = await Ride.findById(id);

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Seul l\'organisateur peut inviter des participants'
      });
    }

    // Vérifier que la balade est privée (optionnel mais logique)
    if (ride.visibilite !== 'privee') {
      return res.status(400).json({
        success: false,
        message: 'Les invitations ne sont disponibles que pour les balades privées'
      });
    }

    // Vérifier que les utilisateurs existent
    const users = await User.find({ _id: { $in: userIds } });
    if (users.length !== userIds.length) {
      return res.status(400).json({
        success: false,
        message: 'Un ou plusieurs utilisateurs n\'existent pas'
      });
    }

    // Ajouter les invitations (ne pas dupliquer)
    const newInvitations = [];
    for (const userId of userIds) {
      // Vérifier si l'utilisateur n'est pas déjà invité
      const existingInvitation = ride.invitations.find(
        inv => inv.userId && inv.userId.toString() === userId.toString()
      );

      // Vérifier si l'utilisateur n'est pas déjà participant
      const isAlreadyParticipant = ride.participants.some(
        p => p.userId && p.userId.toString() === userId.toString()
      );

      // Vérifier que ce n'est pas l'organisateur
      if (userId.toString() === ride.organisateur.toString()) {
        continue; // Skip l'organisateur
      }

      if (!existingInvitation && !isAlreadyParticipant) {
        ride.invitations.push({
          userId: userId,
          status: 'pending',
          invitedAt: new Date()
        });
        newInvitations.push(userId);
      }
    }

    await ride.save();

    // Populer les données pour la réponse
    const updatedRide = await Ride.findById(id)
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo')
      .populate('invitations.userId', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: `${newInvitations.length} invitation(s) envoyée(s)`,
      data: {
        ride: updatedRide,
        invitedCount: newInvitations.length
      }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    if (error instanceof NotFoundError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'envoi des invitations',
      error: error.message
    });
  }
};

// Accepter une invitation à une balade
exports.acceptRideInvitation = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { vehicleId } = req.body; // Véhicule optionnel avec lequel participer

    const ride = await Ride.findById(id);

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Trouver l'invitation pending pour cet utilisateur
    const invitation = ride.invitations.find(
      inv => inv.userId && inv.userId.toString() === req.user._id.toString() && inv.status === 'pending'
    );

    if (!invitation) {
      return res.status(404).json({
        success: false,
        message: 'Aucune invitation en attente trouvée'
      });
    }

    // Si un vehicleId est fourni, vérifier qu'il appartient à l'utilisateur et correspond au type de véhicule
    if (vehicleId) {
      const Vehicle = require('../models/Vehicle');
      const vehicle = await Vehicle.findById(vehicleId);
      
      if (!vehicle) {
        return res.status(404).json({
          success: false,
          message: 'Véhicule non trouvé'
        });
      }

      if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
        return res.status(403).json({
          success: false,
          message: 'Ce véhicule ne vous appartient pas'
        });
      }

      if (vehicle.type !== ride.typeVehicule) {
        return res.status(400).json({
          success: false,
          message: `Le type de véhicule ne correspond pas (balade: ${ride.typeVehicule}, véhicule: ${vehicle.type})`
        });
      }
    }

    // Mettre à jour l'invitation
    invitation.status = 'accepted';
    invitation.respondedAt = new Date();

    // Ajouter l'utilisateur aux participants s'il n'est pas déjà présent
    const isAlreadyParticipant = ride.participants.some(
      p => p.userId && p.userId.toString() === req.user._id.toString()
    );

    if (!isAlreadyParticipant) {
      ride.participants.push({
        userId: req.user._id,
        vehicleId: vehicleId || null
      });

      // Ajouter un événement participant_joined
      ride.rideEvents.push({
        type: 'participant_joined',
        timestamp: new Date(),
        userId: req.user._id
      });
    } else if (vehicleId) {
      // Si l'utilisateur est déjà participant, mettre à jour son vehicleId
      const participant = ride.participants.find(
        p => p.userId && p.userId.toString() === req.user._id.toString()
      );
      if (participant) {
        participant.vehicleId = vehicleId;
      }
    }

    await ride.save();

    // Populer les données pour la réponse
    const updatedRide = await Ride.findById(id)
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo')
      .populate('invitations.userId', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: 'Invitation acceptée',
      data: {
        ride: updatedRide
      }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    if (error instanceof NotFoundError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'acceptation de l\'invitation',
      error: error.message
    });
  }
};

// Refuser une invitation à une balade
exports.declineRideInvitation = async (req, res, next) => {
  try {
    const { id } = req.params;

    const ride = await Ride.findById(id);

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Trouver l'invitation pending pour cet utilisateur
    const invitation = ride.invitations.find(
      inv => inv.userId && inv.userId.toString() === req.user._id.toString() && inv.status === 'pending'
    );

    if (!invitation) {
      return res.status(404).json({
        success: false,
        message: 'Aucune invitation en attente trouvée'
      });
    }

    // Mettre à jour l'invitation
    invitation.status = 'declined';
    invitation.respondedAt = new Date();

    await ride.save();

    // Populer les données pour la réponse
    const updatedRide = await Ride.findById(id)
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo')
      .populate('invitations.userId', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: 'Invitation refusée',
      data: {
        ride: updatedRide
      }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    if (error instanceof NotFoundError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors du refus de l\'invitation',
      error: error.message
    });
  }
};

// ========== OUTILS ORGANISATEUR ==========

// Mettre à jour les paramètres organisateur d'une balade
exports.updateOrganizerSettings = async (req, res, next) => {
  try {
    const { id } = req.params;
    const {
      requiresApproval,
      maxParticipants,
      enableWaitlist,
      autoReminder,
      recurrence
    } = req.body;

    const ride = await Ride.findById(id);
    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Seul l\'organisateur peut modifier ces paramètres');
    }

    // Mettre à jour les paramètres
    if (typeof requiresApproval === 'boolean') {
      ride.requiresApproval = requiresApproval;
    }

    if (maxParticipants !== undefined) {
      ride.maxParticipants = maxParticipants === 0 ? null : maxParticipants;
    }

    if (typeof enableWaitlist === 'boolean') {
      ride.enableWaitlist = enableWaitlist;
    }

    if (autoReminder) {
      ride.autoReminder = {
        ...ride.autoReminder,
        enabled: autoReminder.enabled ?? ride.autoReminder?.enabled ?? false,
        hoursBefore: autoReminder.hoursBefore ?? ride.autoReminder?.hoursBefore ?? 24,
        message: autoReminder.message ?? ride.autoReminder?.message ?? null
      };
    }

    if (recurrence) {
      ride.recurrence = {
        ...ride.recurrence,
        enabled: recurrence.enabled ?? ride.recurrence?.enabled ?? false,
        frequency: recurrence.frequency ?? ride.recurrence?.frequency ?? 'weekly',
        dayOfWeek: recurrence.dayOfWeek ?? ride.recurrence?.dayOfWeek ?? null,
        endDate: recurrence.endDate ? new Date(recurrence.endDate) : ride.recurrence?.endDate ?? null
      };
      
      // Calculer la prochaine occurrence si la récurrence est activée
      if (ride.recurrence.enabled) {
        ride.recurrence.nextOccurrence = calculateNextOccurrence(
          ride.date,
          ride.recurrence.frequency,
          ride.recurrence.dayOfWeek
        );
      }
    }

    await ride.save();

    res.status(200).json({
      success: true,
      message: 'Paramètres mis à jour',
      data: { ride }
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise à jour des paramètres',
      error: error.message
    });
  }
};

// Demander à rejoindre une balade (avec validation manuelle)
exports.requestToJoin = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { vehicleId, message } = req.body;

    const ride = await Ride.findById(id);
    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier que la balade n'est pas passée
    if (new Date(ride.date) < new Date()) {
      throw new BadRequestError('Impossible de rejoindre une balade passée');
    }

    // Vérifier si l'utilisateur est déjà participant
    const isParticipant = ride.participants.some(
      p => p.userId && p.userId.toString() === req.user._id.toString()
    );
    if (isParticipant) {
      throw new ConflictError('Vous êtes déjà participant à cette balade');
    }

    // Vérifier si une demande est déjà en attente
    const hasPendingRequest = ride.pendingRequests?.some(
      r => r.userId.toString() === req.user._id.toString()
    );
    if (hasPendingRequest) {
      throw new ConflictError('Vous avez déjà une demande en attente');
    }

    // Vérifier si l'utilisateur est déjà en liste d'attente
    const isInWaitlist = ride.waitlist?.some(
      w => w.userId.toString() === req.user._id.toString()
    );
    if (isInWaitlist) {
      throw new ConflictError('Vous êtes déjà en liste d\'attente');
    }

    // Si validation manuelle requise, ajouter à pendingRequests
    if (ride.requiresApproval) {
      ride.pendingRequests = ride.pendingRequests || [];
      ride.pendingRequests.push({
        userId: req.user._id,
        vehicleId: vehicleId || null,
        message: message || null,
        requestedAt: new Date()
      });

      await ride.save();

      return res.status(200).json({
        success: true,
        message: 'Demande envoyée. L\'organisateur doit approuver votre participation.',
        data: { status: 'pending_approval' }
      });
    }

    // Sinon, vérifier la limite de participants
    if (ride.maxParticipants && ride.participants.length >= ride.maxParticipants) {
      // Si liste d'attente activée, ajouter à la waitlist
      if (ride.enableWaitlist) {
        ride.waitlist = ride.waitlist || [];
        const position = ride.waitlist.length + 1;
        ride.waitlist.push({
          userId: req.user._id,
          vehicleId: vehicleId || null,
          addedAt: new Date(),
          position
        });

        await ride.save();

        return res.status(200).json({
          success: true,
          message: `Balade complète. Vous êtes en position ${position} sur la liste d'attente.`,
          data: { status: 'waitlisted', position }
        });
      } else {
        throw new BadRequestError('La balade est complète');
      }
    }

    // Ajouter directement comme participant
    ride.participants.push({
      userId: req.user._id,
      vehicleId: vehicleId || null
    });

    ride.rideEvents.push({
      type: 'participant_joined',
      timestamp: new Date(),
      userId: req.user._id
    });

    await ride.save();

    res.status(200).json({
      success: true,
      message: 'Vous avez rejoint la balade',
      data: { status: 'joined' }
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError || 
        error instanceof BadRequestError || error instanceof ConflictError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la demande',
      error: error.message
    });
  }
};

// Approuver une demande de participation
exports.approveRequest = async (req, res, next) => {
  try {
    const { id, userId } = req.params;

    const ride = await Ride.findById(id);
    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Seul l\'organisateur peut approuver les demandes');
    }

    // Trouver la demande
    const requestIndex = ride.pendingRequests?.findIndex(
      r => r.userId.toString() === userId
    );
    if (requestIndex === -1 || requestIndex === undefined) {
      throw new NotFoundError('Demande non trouvée');
    }

    const request = ride.pendingRequests[requestIndex];

    // Vérifier la limite de participants
    if (ride.maxParticipants && ride.participants.length >= ride.maxParticipants) {
      if (ride.enableWaitlist) {
        // Ajouter à la liste d'attente
        ride.waitlist = ride.waitlist || [];
        const position = ride.waitlist.length + 1;
        ride.waitlist.push({
          userId: request.userId,
          vehicleId: request.vehicleId,
          addedAt: new Date(),
          position
        });
        ride.pendingRequests.splice(requestIndex, 1);
        await ride.save();

        return res.status(200).json({
          success: true,
          message: `Balade complète. L'utilisateur a été ajouté en position ${position} sur la liste d'attente.`,
          data: { status: 'waitlisted', position }
        });
      } else {
        throw new BadRequestError('La balade est complète');
      }
    }

    // Ajouter comme participant
    ride.participants.push({
      userId: request.userId,
      vehicleId: request.vehicleId
    });

    ride.rideEvents.push({
      type: 'participant_joined',
      timestamp: new Date(),
      userId: request.userId
    });

    // Retirer de pendingRequests
    ride.pendingRequests.splice(requestIndex, 1);

    await ride.save();

    // Populer pour la réponse
    await ride.populate('participants.userId', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: 'Demande approuvée',
      data: { ride }
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError || error instanceof BadRequestError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'approbation',
      error: error.message
    });
  }
};

// Refuser une demande de participation
exports.rejectRequest = async (req, res, next) => {
  try {
    const { id, userId } = req.params;

    const ride = await Ride.findById(id);
    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Seul l\'organisateur peut refuser les demandes');
    }

    // Trouver et retirer la demande
    const requestIndex = ride.pendingRequests?.findIndex(
      r => r.userId.toString() === userId
    );
    if (requestIndex === -1 || requestIndex === undefined) {
      throw new NotFoundError('Demande non trouvée');
    }

    ride.pendingRequests.splice(requestIndex, 1);
    await ride.save();

    res.status(200).json({
      success: true,
      message: 'Demande refusée'
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors du refus',
      error: error.message
    });
  }
};

// Obtenir les demandes en attente
exports.getPendingRequests = async (req, res, next) => {
  try {
    const { id } = req.params;

    const ride = await Ride.findById(id)
      .populate('pendingRequests.userId', 'firstName lastName pseudo avatarUrl')
      .populate('pendingRequests.vehicleId', 'nickname make model');

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Seul l\'organisateur peut voir les demandes');
    }

    res.status(200).json({
      success: true,
      data: {
        pendingRequests: ride.pendingRequests || [],
        count: ride.pendingRequests?.length || 0
      }
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des demandes',
      error: error.message
    });
  }
};

// Obtenir la liste d'attente
exports.getWaitlist = async (req, res, next) => {
  try {
    const { id } = req.params;

    const ride = await Ride.findById(id)
      .populate('waitlist.userId', 'firstName lastName pseudo avatarUrl')
      .populate('waitlist.vehicleId', 'nickname make model');

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // L'organisateur ou les personnes en liste d'attente peuvent voir
    const isOrganizer = ride.organisateur.toString() === req.user._id.toString();
    const isInWaitlist = ride.waitlist?.some(
      w => w.userId._id?.toString() === req.user._id.toString() || 
           w.userId.toString() === req.user._id.toString()
    );

    if (!isOrganizer && !isInWaitlist) {
      throw new ForbiddenError('Accès non autorisé');
    }

    res.status(200).json({
      success: true,
      data: {
        waitlist: ride.waitlist || [],
        count: ride.waitlist?.length || 0,
        maxParticipants: ride.maxParticipants,
        currentParticipants: ride.participants.length
      }
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération de la liste d\'attente',
      error: error.message
    });
  }
};

// Promouvoir un utilisateur de la liste d'attente
exports.promoteFromWaitlist = async (req, res, next) => {
  try {
    const { id, userId } = req.params;

    const ride = await Ride.findById(id);
    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Seul l\'organisateur peut promouvoir');
    }

    // Trouver l'utilisateur dans la waitlist
    const waitlistIndex = ride.waitlist?.findIndex(
      w => w.userId.toString() === userId
    );
    if (waitlistIndex === -1 || waitlistIndex === undefined) {
      throw new NotFoundError('Utilisateur non trouvé dans la liste d\'attente');
    }

    const waitlistEntry = ride.waitlist[waitlistIndex];

    // Ajouter comme participant
    ride.participants.push({
      userId: waitlistEntry.userId,
      vehicleId: waitlistEntry.vehicleId
    });

    ride.rideEvents.push({
      type: 'participant_joined',
      timestamp: new Date(),
      userId: waitlistEntry.userId
    });

    // Retirer de la waitlist et réorganiser les positions
    ride.waitlist.splice(waitlistIndex, 1);
    ride.waitlist.forEach((w, index) => {
      w.position = index + 1;
    });

    await ride.save();
    await ride.populate('participants.userId', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: 'Utilisateur promu de la liste d\'attente',
      data: { ride }
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la promotion',
      error: error.message
    });
  }
};

// Retirer un utilisateur de la liste d'attente
exports.removeFromWaitlist = async (req, res, next) => {
  try {
    const { id, userId } = req.params;

    const ride = await Ride.findById(id);
    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // L'organisateur ou l'utilisateur lui-même peut se retirer
    const isOrganizer = ride.organisateur.toString() === req.user._id.toString();
    const isSelf = userId === req.user._id.toString();

    if (!isOrganizer && !isSelf) {
      throw new ForbiddenError('Non autorisé');
    }

    const waitlistIndex = ride.waitlist?.findIndex(
      w => w.userId.toString() === userId
    );
    if (waitlistIndex === -1 || waitlistIndex === undefined) {
      throw new NotFoundError('Utilisateur non trouvé dans la liste d\'attente');
    }

    // Retirer et réorganiser les positions
    ride.waitlist.splice(waitlistIndex, 1);
    ride.waitlist.forEach((w, index) => {
      w.position = index + 1;
    });

    await ride.save();

    res.status(200).json({
      success: true,
      message: 'Retiré de la liste d\'attente'
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors du retrait',
      error: error.message
    });
  }
};

// Helper pour calculer la prochaine occurrence
function calculateNextOccurrence(baseDate, frequency, dayOfWeek) {
  const date = new Date(baseDate);
  const now = new Date();
  
  // S'assurer qu'on part d'une date future
  while (date <= now) {
    switch (frequency) {
      case 'weekly':
        date.setDate(date.getDate() + 7);
        break;
      case 'biweekly':
        date.setDate(date.getDate() + 14);
        break;
      case 'monthly':
        date.setMonth(date.getMonth() + 1);
        break;
    }
  }
  
  return date;
}

// Créer la prochaine occurrence d'une balade récurrente
exports.createRecurringRide = async (req, res, next) => {
  try {
    const { id } = req.params;

    const parentRide = await Ride.findById(id);
    if (!parentRide) {
      throw new NotFoundError('Balade');
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (parentRide.organisateur.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Seul l\'organisateur peut créer des occurrences');
    }

    if (!parentRide.recurrence?.enabled) {
      throw new BadRequestError('La récurrence n\'est pas activée pour cette balade');
    }

    // Vérifier la date de fin
    if (parentRide.recurrence.endDate && new Date() > parentRide.recurrence.endDate) {
      throw new BadRequestError('La période de récurrence est terminée');
    }

    const nextDate = calculateNextOccurrence(
      parentRide.date,
      parentRide.recurrence.frequency,
      parentRide.recurrence.dayOfWeek
    );

    // Créer la nouvelle balade
    const newRide = new Ride({
      titre: parentRide.titre,
      description: parentRide.description,
      typeVehicule: parentRide.typeVehicule,
      date: nextDate,
      heure: parentRide.heure,
      lieuDepart: parentRide.lieuDepart,
      lieuArrivee: parentRide.lieuArrivee,
      waypoints: parentRide.waypoints,
      localisation: parentRide.localisation,
      rayon: parentRide.rayon,
      organisateur: parentRide.organisateur,
      visibilite: parentRide.visibilite,
      ridingStyle: parentRide.ridingStyle,
      requiresApproval: parentRide.requiresApproval,
      maxParticipants: parentRide.maxParticipants,
      enableWaitlist: parentRide.enableWaitlist,
      autoReminder: parentRide.autoReminder,
      recurrence: {
        ...parentRide.recurrence.toObject(),
        parentRideId: parentRide._id
      },
      participants: [{
        userId: parentRide.organisateur,
        vehicleId: null
      }]
    });

    await newRide.save();

    // Mettre à jour la prochaine occurrence sur la balade parente
    parentRide.recurrence.nextOccurrence = calculateNextOccurrence(
      nextDate,
      parentRide.recurrence.frequency,
      parentRide.recurrence.dayOfWeek
    );
    await parentRide.save();

    res.status(201).json({
      success: true,
      message: 'Nouvelle occurrence créée',
      data: { ride: newRide }
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError || error instanceof BadRequestError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la création',
      error: error.message
    });
  }
};

// Envoyer un rappel manuel aux participants
exports.sendReminderToParticipants = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { message } = req.body;

    const ride = await Ride.findById(id)
      .populate('participants.userId', 'firstName lastName pseudo email');

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Seul l\'organisateur peut envoyer des rappels');
    }

    // Pour l'instant, on simule l'envoi (TODO: intégrer avec un service de notification)
    const participantEmails = ride.participants
      .filter(p => p.userId?.email)
      .map(p => p.userId.email);

    // Marquer comme envoyé
    ride.autoReminder = ride.autoReminder || {};
    ride.autoReminder.sentAt = new Date();
    await ride.save();

    res.status(200).json({
      success: true,
      message: `Rappel envoyé à ${participantEmails.length} participant(s)`,
      data: {
        sentTo: participantEmails.length,
        sentAt: ride.autoReminder.sentAt
      }
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'envoi du rappel',
      error: error.message
    });
  }
};

// ========== FONCTIONS AVANCÉES ==========

// Exporter une balade en format GPX
exports.exportRideGPX = async (req, res, next) => {
  try {
    // Vérifier que l'utilisateur est premium
    if (!req.userIsPremium) {
      throw new ForbiddenError('Cette fonctionnalité est réservée aux membres premium');
    }

    const { id } = req.params;
    const ride = await Ride.findById(id);

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier les droits d'accès
    const isOrganizer = ride.organisateur.toString() === req.user._id.toString();
    const isParticipant = ride.participants.some(
      p => p.userId && p.userId.toString() === req.user._id.toString()
    );
    
    if (ride.visibilite === 'secrete' && !isOrganizer && !isParticipant) {
      throw new ForbiddenError('Accès non autorisé');
    }

    if (ride.visibilite === 'privee' && !isOrganizer && !isParticipant) {
      const isInvited = ride.invitations && ride.invitations.some(
        inv => inv.userId && inv.userId.toString() === req.user._id.toString() && 
        (inv.status === 'pending' || inv.status === 'accepted')
      );
      if (!isInvited) {
        throw new ForbiddenError('Accès non autorisé');
      }
    }

    // Générer le GPX à partir des waypoints
    let gpxContent = '<?xml version="1.0" encoding="UTF-8"?>\n';
    gpxContent += '<gpx version="1.1" creator="RideTogether">\n';
    gpxContent += `  <metadata>\n`;
    gpxContent += `    <name>${ride.titre}</name>\n`;
    if (ride.description) {
      gpxContent += `    <desc>${ride.description}</desc>\n`;
    }
    gpxContent += `  </metadata>\n`;

    if (ride.waypoints && ride.waypoints.length > 0) {
      // Trier les waypoints par ordre
      const sortedWaypoints = [...ride.waypoints].sort((a, b) => a.order - b.order);
      
      gpxContent += `  <trk>\n`;
      gpxContent += `    <name>${ride.titre}</name>\n`;
      gpxContent += `    <trkseg>\n`;
      
      for (const waypoint of sortedWaypoints) {
        if (waypoint.coordinates && waypoint.coordinates.coordinates) {
          const [lon, lat] = waypoint.coordinates.coordinates;
          gpxContent += `      <trkpt lat="${lat}" lon="${lon}">\n`;
          gpxContent += `        <name>${waypoint.address || waypoint.type}</name>\n`;
          gpxContent += `        <desc>${waypoint.type}</desc>\n`;
          gpxContent += `      </trkpt>\n`;
        }
      }
      
      gpxContent += `    </trkseg>\n`;
      gpxContent += `  </trk>\n`;
    }

    gpxContent += '</gpx>';

    res.setHeader('Content-Type', 'application/gpx+xml');
    res.setHeader('Content-Disposition', `attachment; filename="balade_${ride._id}.gpx"`);
    res.send(gpxContent);
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'export GPX',
      error: error.message
    });
  }
};

// Exporter une balade en format PDF
exports.exportRidePDF = async (req, res, next) => {
  try {
    // Vérifier que l'utilisateur est premium
    if (!req.userIsPremium) {
      throw new ForbiddenError('Cette fonctionnalité est réservée aux membres premium');
    }

    const { id } = req.params;
    const ride = await Ride.findById(id)
      .populate('organisateur', 'firstName lastName pseudo')
      .populate('participants.userId', 'firstName lastName pseudo');

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier les droits d'accès
    const isOrganizer = ride.organisateur.toString() === req.user._id.toString();
    const isParticipant = ride.participants.some(
      p => p.userId && p.userId.toString() === req.user._id.toString()
    );
    
    if (ride.visibilite === 'secrete' && !isOrganizer && !isParticipant) {
      throw new ForbiddenError('Accès non autorisé');
    }

    if (ride.visibilite === 'privee' && !isOrganizer && !isParticipant) {
      const isInvited = ride.invitations && ride.invitations.some(
        inv => inv.userId && inv.userId.toString() === req.user._id.toString() && 
        (inv.status === 'pending' || inv.status === 'accepted')
      );
      if (!isInvited) {
        throw new ForbiddenError('Accès non autorisé');
      }
    }

    // Générer un PDF avec pdfkit
    const doc = new PDFDocument();
    const chunks = [];

    doc.on('data', chunk => chunks.push(chunk));
    doc.on('end', () => {
      const pdfBuffer = Buffer.concat(chunks);
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename="balade_${ride._id}.pdf"`);
      res.send(pdfBuffer);
    });

    // Contenu du PDF
    doc.fontSize(20).text(ride.titre, { align: 'center' });
    doc.moveDown();
    
    if (ride.description) {
      doc.fontSize(12).text('Description:', { underline: true });
      doc.fontSize(10).text(ride.description);
      doc.moveDown();
    }

    doc.fontSize(12).text('Informations:', { underline: true });
    doc.fontSize(10);
    doc.text(`Type de véhicule: ${ride.typeVehicule === 'moto' ? 'Moto' : 'Voiture'}`);
    doc.text(`Date: ${new Date(ride.date).toLocaleDateString('fr-FR')}`);
    doc.text(`Heure: ${ride.heure}`);
    
    if (typeof ride.lieuDepart === 'string') {
      doc.text(`Lieu de départ: ${ride.lieuDepart}`);
    }
    if (typeof ride.lieuArrivee === 'string') {
      doc.text(`Lieu d'arrivée: ${ride.lieuArrivee}`);
    }
    
    doc.moveDown();
    doc.fontSize(12).text('Organisateur:', { underline: true });
    doc.fontSize(10);
    const organizerName = ride.organisateur.pseudo || 
      `${ride.organisateur.firstName || ''} ${ride.organisateur.lastName || ''}`.trim() ||
      'Organisateur';
    doc.text(organizerName);
    
    doc.moveDown();
    doc.fontSize(12).text(`Participants (${ride.participants.length}):`, { underline: true });
    doc.fontSize(10);
    ride.participants.forEach((p, index) => {
      const participantName = p.userId?.pseudo || 
        `${p.userId?.firstName || ''} ${p.userId?.lastName || ''}`.trim() ||
        'Participant';
      doc.text(`${index + 1}. ${participantName}`);
    });

    doc.end();
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'export PDF',
      error: error.message
    });
  }
};

// Mettre à jour la visibilité d'une balade (pour le mode secret)
exports.updateRideVisibility = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { visibilite } = req.body;

    if (!['privee', 'publique', 'secrete'].includes(visibilite)) {
      throw new BadRequestError('Visibilité invalide');
    }

    const ride = await Ride.findById(id);
    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Seul l\'organisateur peut modifier la visibilité');
    }

    // Vérifier que l'utilisateur est premium pour activer le mode secret
    if (visibilite === 'secrete' && !req.userIsPremium) {
      throw new ForbiddenError('Le mode "balade privée secrète" est réservé aux membres premium');
    }

    ride.visibilite = visibilite;

    // Si mode secret activé, générer un lien secret unique
    if (visibilite === 'secrete') {
      if (!ride.secretLink) {
        const crypto = require('crypto');
        ride.secretLink = crypto.randomBytes(32).toString('hex');
      }
    } else {
      // Si on désactive le mode secret, on peut garder le lien ou le supprimer
      // Pour l'instant, on le garde au cas où l'utilisateur réactive le mode
    }

    await ride.save();

    // Recharger la balade pour avoir les données à jour
    const updatedRide = await Ride.findById(id)
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: 'Visibilité mise à jour',
      data: {
        ride: updatedRide,
        secretLink: ride.secretLink ? `${process.env.FRONTEND_URL || 'http://localhost:3000'}/rides/secret/${ride.secretLink}` : null
      }
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError || error instanceof BadRequestError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise à jour de la visibilité',
      error: error.message
    });
  }
};

// Accéder à une balade via son lien secret
exports.getRideBySecretLink = async (req, res, next) => {
  try {
    const { secretLink } = req.params;

    const ride = await Ride.findOne({ secretLink })
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo')
      .populate('invitations.userId', 'firstName lastName pseudo');

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    if (ride.visibilite !== 'secrete') {
      return res.status(400).json({
        success: false,
        message: 'Cette balade n\'est pas en mode secret'
      });
    }

    // Vérifier si l'utilisateur a liké la balade et compter les likes
    const totalLikes = await Like.countLikesByRide(ride._id);
    const hasUserLiked = req.user ? await Like.hasUserLiked(ride._id, req.user._id) : false;
    
    // Calculer isOrganizerPremium
    const isOrganizerPremium = ride.organisateur && 
      subscriptionService.isPremiumActive(ride.organisateur);

    const rideObject = ride.toObject();
    rideObject.totalLikes = totalLikes;
    rideObject.hasUserLiked = hasUserLiked;
    rideObject.isOrganizerPremium = isOrganizerPremium || false;

    res.status(200).json({
      success: true,
      data: {
        ride: rideObject
      }
    });
  } catch (error) {
    if (error instanceof NotFoundError) {
      return next(error);
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération de la balade',
      error: error.message
    });
  }
};
