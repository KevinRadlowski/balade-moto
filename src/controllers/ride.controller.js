const Ride = require('../models/Ride');
const User = require('../models/User');
const Like = require('../models/Like');
const icsService = require('../services/ics.service');
const https = require('https');
const { NotFoundError, ForbiddenError, BadRequestError, ConflictError, InternalServerError } = require('../utils/errors');
const { routeCache, geocodeCache, reverseGeocodeCache } = require('../utils/cache');
const compatibilityService = require('../services/compatibility.service');
const achievementService = require('../services/achievement.service');
const vehicleStatsService = require('../services/vehicleStats.service');

exports.createRide = async (req, res, next) => {
  try {
    const {
      titre,
      description,
      typeVehicule,
      date,
      heure,
      lieuDepart,
      lieuArrivee,
      rayon,
      visibilite,
      localisation,
      waypoints // Nouveau système de waypoints
    } = req.body;

    const hasWaypoints = waypoints && Array.isArray(waypoints) && waypoints.length >= 2;
    
    if (!hasWaypoints && (!lieuDepart || !lieuArrivee)) {
      throw new BadRequestError('Vous devez fournir soit des waypoints (départ, checkpoints, arrivée), soit un lieu de départ et d\'arrivée');
    }

    const rideDate = new Date(date);
    if (rideDate < new Date()) {
      throw new BadRequestError('La date de la balade doit être dans le futur');
    }

    let rideLocalisation = null;
    if (hasWaypoints && waypoints.length > 0) {
      const firstWaypoint = waypoints[0];
      if (firstWaypoint.coordinates && firstWaypoint.coordinates.coordinates) {
        rideLocalisation = {
          type: 'Point',
          coordinates: firstWaypoint.coordinates.coordinates
        };
      }
    } else if (localisation) {
      if (localisation.latitude !== undefined && localisation.longitude !== undefined) {
        // Format simple { latitude, longitude }
        rideLocalisation = {
          type: 'Point',
          coordinates: [parseFloat(localisation.longitude), parseFloat(localisation.latitude)]
        };
      } else if (localisation.type === 'Point' && Array.isArray(localisation.coordinates)) {
        // Format GeoJSON déjà correct
        rideLocalisation = {
          type: 'Point',
          coordinates: localisation.coordinates
        };
      }
    }

    let finalLieuDepart = lieuDepart;
    let finalLieuArrivee = lieuArrivee;
    
    if (hasWaypoints) {
      // Extraire le départ et l'arrivée des waypoints
      const departWaypoint = waypoints.find(w => w.type === 'depart') || waypoints[0];
      const arriveeWaypoint = waypoints.find(w => w.type === 'arrivee') || waypoints[waypoints.length - 1];
      
      finalLieuDepart = departWaypoint.address || JSON.stringify(departWaypoint.coordinates);
      finalLieuArrivee = arriveeWaypoint.address || JSON.stringify(arriveeWaypoint.coordinates);
    }

    const rideData = {
      titre,
      description,
      typeVehicule,
      date: rideDate,
      heure,
      lieuDepart: finalLieuDepart,
      lieuArrivee: finalLieuArrivee,
      rayon: rayon || 0,
      organisateur: req.user._id,
      visibilite: visibilite || 'publique',
      participants: [{ userId: req.user._id }], // L'organisateur est automatiquement participant
      localisation: rideLocalisation,
      status: 'scheduled', // Statut par défaut
      ridingStyle: req.body.ridingStyle || null, // Style de conduite (optionnel)
      rideEvents: [] // Initialiser les événements
    };

    if (hasWaypoints) {
      rideData.waypoints = waypoints.map((wp, index) => ({
        type: wp.type || (index === 0 ? 'depart' : index === waypoints.length - 1 ? 'arrivee' : 'checkpoint'),
        address: wp.address,
        coordinates: {
          type: 'Point',
          coordinates: wp.coordinates?.coordinates || [wp.coordinates?.longitude || wp.longitude, wp.coordinates?.latitude || wp.latitude]
        },
        order: wp.order !== undefined ? wp.order : index
      }));
    }

    const ride = new Ride(rideData);

    await ride.save();
    await ride.populate('organisateur', 'firstName lastName pseudo email');
    await ride.populate('participants.userId', 'firstName lastName pseudo');

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
exports.getRides = async (req, res) => {
  try {
    const {
      typeVehicule,
      visibilite,
      dateDebut,
      dateFin,
      organisateur,
      participant,
      search,
      lat,
      lng,
      rayon,
      page = 1,
      limit = 10,
      sortBy = 'date',
      sortOrder = 'asc'
    } = req.query;

    // Si lat, lng et rayon sont fournis, utiliser la recherche géospatiale
    if (lat && lng && rayon) {
      const latitude = parseFloat(lat);
      const longitude = parseFloat(lng);
      const radiusKm = Math.min(parseFloat(rayon) || 200, 200); // Max 200 km

      // Validation des coordonnées
      if (!isNaN(latitude) && !isNaN(longitude) && 
          latitude >= -90 && latitude <= 90 && 
          longitude >= -180 && longitude <= 180 &&
          !isNaN(radiusKm) && radiusKm > 0 && radiusKm <= 200) {
        
        // Construire le filtre de base
        const filter = {
          localisation: {
            $exists: true,
            $ne: null
          }
        };

        if (participant) {
          // Si on filtre par participant, on veut les balades où l'utilisateur est participant OU organisateur
          // Peu importe la visibilité (car s'il est participant, il a le droit de voir)
          filter.$or = [
            { 'participants.userId': participant },
            { organisateur: participant }
          ];
        } else {
          // Sinon, appliquer le filtre de visibilité normal
          if (visibilite && ['privee', 'publique'].includes(visibilite)) {
            filter.visibilite = visibilite;
          } else {
            filter.$or = [
              { visibilite: 'publique' },
              { organisateur: req.user._id },
              { 'participants.userId': req.user._id }
            ];
          }
        }

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

        if (organisateur) {
          filter.organisateur = organisateur;
        }

        if (search) {
          filter.$or = [
            ...(filter.$or || []),
            { titre: { $regex: search, $options: 'i' } },
            { description: { $regex: search, $options: 'i' } }
          ];
        }

        // Utiliser une aggregation avec $geoNear pour la recherche géospatiale
        const pipeline = [
          {
            $geoNear: {
              near: {
                type: 'Point',
                coordinates: [longitude, latitude] // MongoDB utilise [lng, lat]
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
              distance: 1, // Plus proche en premier
              [sortBy]: sortOrder === 'desc' ? -1 : 1
            }
          },
          {
            $skip: (parseInt(page) - 1) * parseInt(limit)
          },
          {
            $limit: parseInt(limit)
          }
        ];

        const rides = await Ride.aggregate(pipeline);
        const total = await Ride.countDocuments(filter);

        // Vérifier si l'utilisateur a liké chaque balade et compter les likes
        const ridesWithLikes = await Promise.all(
          rides.map(async (ride) => {
            const totalLikes = await Like.countLikesByRide(ride._id);
            const hasUserLiked = await Like.hasUserLiked(ride._id, req.user._id);
            
            return {
              ...ride,
              totalLikes,
              hasUserLiked
            };
          })
        );

        return res.status(200).json({
          success: true,
          data: {
            rides: ridesWithLikes,
            pagination: {
              page: parseInt(page),
              limit: parseInt(limit),
              total,
              pages: Math.ceil(total / parseInt(limit))
            }
          }
        });
      }
    }

    // Sinon, utiliser la recherche classique
    // Construire le filtre
    const filter = {};

    if (typeVehicule && ['moto', 'voiture'].includes(typeVehicule)) {
      filter.typeVehicule = typeVehicule;
    }

    if (participant) {
      // Si on filtre par participant, on veut les balades où l'utilisateur est participant OU organisateur
      // Peu importe la visibilité (car s'il est participant, il a le droit de voir)
      filter.$or = [
        { 'participants.userId': participant },
        { organisateur: participant }
      ];
    } else {
      // Sinon, appliquer le filtre de visibilité normal
      if (visibilite && ['privee', 'publique'].includes(visibilite)) {
        filter.visibilite = visibilite;
      } else {
        // Montrer les publiques et les privées où l'utilisateur est participant/organisateur
        filter.$or = [
          { visibilite: 'publique' },
          { organisateur: req.user._id },
          { 'participants.userId': req.user._id }
        ];
      }
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

    if (organisateur) {
      filter.organisateur = organisateur;
    }

    if (search) {
      filter.$or = [
        ...(filter.$or || []),
        { titre: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } }
      ];
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const sort = {};
    sort[sortBy] = sortOrder === 'desc' ? -1 : 1;

    const rides = await Ride.find(filter)
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo')
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Ride.countDocuments(filter);

    const ridesWithLikes = await Promise.all(
      rides.map(async (ride) => {
        const rideObj = ride.toObject();
        const totalLikes = await Like.countLikesByRide(ride._id);
        const hasUserLiked = await Like.hasUserLiked(ride._id, req.user._id);
        
        return {
          ...rideObj,
          totalLikes,
          hasUserLiked
        };
      })
    );

    res.status(200).json({
      success: true,
      data: {
        rides: ridesWithLikes,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / parseInt(limit))
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des balades',
      error: error.message
    });
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
    
    const dateFilter = { $lt: tomorrow };
    
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

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const sort = {};
    sort[sortBy] = sortOrder === 'desc' ? -1 : 1;

    let rides = await Ride.find(filter)
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo')
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit) * 2);

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

    rides = rides.slice(0, parseInt(limit));
    const allRides = await Ride.find(filter)
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo')
      .sort(sort);
    
    const filteredRides = allRides.filter(ride => {
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
    
    const total = filteredRides.length;

    const ridesWithLikes = await Promise.all(
      rides.map(async (ride) => {
        const rideObj = ride.toObject();
        const totalLikes = await Like.countLikesByRide(ride._id);
        const hasUserLiked = await Like.hasUserLiked(ride._id, req.user._id);
        
        return {
          ...rideObj,
          totalLikes,
          hasUserLiked
        };
      })
    );

    res.status(200).json({
      success: true,
      data: {
        rides: ridesWithLikes,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / parseInt(limit))
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
    
    const dateFilter = { $lt: tomorrow };
    
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

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const sort = {};
    sort[sortBy] = sortOrder === 'desc' ? -1 : 1;

    let rides = await Ride.find(filter)
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo')
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit) * 2);

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

    rides = rides.slice(0, parseInt(limit));
    const allRides = await Ride.find(filter)
      .populate('organisateur', 'firstName lastName pseudo email')
      .populate('participants.userId', 'firstName lastName pseudo')
      .sort(sort);
    
    const filteredRides = allRides.filter(ride => {
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
    
    const total = filteredRides.length;

    const ridesWithLikes = await Promise.all(
      rides.map(async (ride) => {
        const rideObj = ride.toObject();
        const totalLikes = await Like.countLikesByRide(ride._id);
        const hasUserLiked = await Like.hasUserLiked(ride._id, req.user._id);
        
        return {
          ...rideObj,
          totalLikes,
          hasUserLiked
        };
      })
    );

    res.status(200).json({
      success: true,
      data: {
        rides: ridesWithLikes,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / parseInt(limit))
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
    const { lat, lng, rayon = 10, typeVehicule, dateDebut, dateFin, limit = 20 } = req.query;

    // Validation des paramètres requis
    if (!lat || !lng) {
      return res.status(400).json({
        success: false,
        message: 'Les paramètres lat (latitude) et lng (longitude) sont requis'
      });
    }

    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);
    const radiusKm = Math.min(parseFloat(rayon) || 10, 100); // Max 100 km
    const limitNum = Math.min(parseInt(limit) || 20, 50); // Max 50 résultats

    // Validation des coordonnées
    if (isNaN(latitude) || isNaN(longitude) || 
        latitude < -90 || latitude > 90 || 
        longitude < -180 || longitude > 180) {
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
        { 'participants.userId': req.user._id }
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
            coordinates: [longitude, latitude] // MongoDB utilise [lng, lat]
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
          distance: 1, // Plus proche en premier
          date: 1 // Puis par date
        }
      },
      {
        $limit: limitNum
      }
    ];

    const rides = await Ride.aggregate(pipeline);

    // Vérifier si l'utilisateur a liké chaque balade et compter les likes
    const ridesWithLikes = await Promise.all(
      rides.map(async (ride) => {
        const rideId = ride._id;
        const totalLikes = await Like.countLikesByRide(rideId);
        const hasUserLiked = await Like.hasUserLiked(rideId, req.user._id);
        
        // Convertir _id en string pour la compatibilité
        const rideObj = {
          ...ride,
          id: ride._id.toString(),
          distance: ride.distance ? (ride.distance / 1000).toFixed(2) : null, // Convertir en km
          totalLikes,
          hasUserLiked
        };
        delete rideObj._id;
        return rideObj;
      })
    );

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
      .populate('organisateur', 'firstName lastName pseudo email vehiclePreference')
      .populate('participants.userId', 'firstName lastName pseudo')
      .populate('likes', 'firstName lastName pseudo');

    if (!ride) {
      throw new NotFoundError('Balade');
    }

    // Vérifier la visibilité
    if (ride.visibilite === 'privee') {
      const isOrganizer = ride.organisateur._id.toString() === req.user._id.toString();
      const isParticipant = ride.participants.some(
        p => p._id.toString() === req.user._id.toString()
      );
      
      if (!isOrganizer && !isParticipant) {
        return res.status(403).json({
          success: false,
          message: 'Vous n\'avez pas accès à cette balade privée'
        });
      }
    }

    // Vérifier si l'utilisateur a liké cette balade et compter les likes
    const totalLikes = await Like.countLikesByRide(ride._id);
    const hasUserLiked = await Like.hasUserLiked(ride._id, req.user._id);

    const rideObj = ride.toObject();
    rideObj.totalLikes = totalLikes;
    rideObj.hasUserLiked = hasUserLiked;

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
    const {
      titre,
      description,
      typeVehicule,
      date,
      heure,
      lieuDepart,
      lieuArrivee,
      rayon,
      visibilite
    } = req.body;

    const ride = await Ride.findById(id);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Vous n\'êtes pas autorisé à modifier cette balade'
      });
    }

    // Mettre à jour les champs fournis
    if (titre !== undefined) ride.titre = titre;
    if (description !== undefined) ride.description = description;
    if (typeVehicule !== undefined) ride.typeVehicule = typeVehicule;
    if (date !== undefined) {
      const rideDate = new Date(date);
      if (rideDate < new Date()) {
        return res.status(400).json({
          success: false,
          message: 'La date de la balade doit être dans le futur'
        });
      }
      ride.date = rideDate;
    }
    if (heure !== undefined) ride.heure = heure;
    if (lieuDepart !== undefined) ride.lieuDepart = lieuDepart;
    if (lieuArrivee !== undefined) ride.lieuArrivee = lieuArrivee;
    if (rayon !== undefined) ride.rayon = rayon;
    if (visibilite !== undefined) ride.visibilite = visibilite;
    if (localisation !== undefined) {
      // Préparer la localisation GPS si fournie
      let rideLocalisation = null;
      if (localisation) {
        if (localisation.latitude !== undefined && localisation.longitude !== undefined) {
          const lat = parseFloat(localisation.latitude);
          const lng = parseFloat(localisation.longitude);
          if (!isNaN(lat) && !isNaN(lng) && 
              lat >= -90 && lat <= 90 && 
              lng >= -180 && lng <= 180) {
            rideLocalisation = {
              type: 'Point',
              coordinates: [lng, lat]
            };
          }
        } else if (localisation.type === 'Point' && Array.isArray(localisation.coordinates)) {
          rideLocalisation = {
            type: 'Point',
            coordinates: localisation.coordinates
          };
        }
      }
      ride.localisation = rideLocalisation;
    }

    await ride.save();
    await ride.populate('organisateur', 'firstName lastName pseudo email');
    await ride.populate('participants.userId', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: 'Balade modifiée avec succès',
      data: { ride }
    });
  } catch (error) {
    if (error.name === 'ValidationError') {
      return res.status(400).json({
        success: false,
        message: 'Erreur de validation',
        errors: Object.values(error.errors).map(err => err.message)
      });
    }
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID de balade invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la modification de la balade',
      error: error.message
    });
  }
};

// Supprimer une balade (uniquement par l'organisateur)
exports.deleteRide = async (req, res, next) => {
  try {
    const { id } = req.params;

    const ride = await Ride.findById(id);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Vous n\'êtes pas autorisé à supprimer cette balade'
      });
    }

    await Ride.findByIdAndDelete(id);

    res.status(200).json({
      success: true,
      message: 'Balade supprimée avec succès'
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
      message: 'Erreur lors de la suppression de la balade',
      error: error.message
    });
  }
};

// Rejoindre une balade
exports.joinRide = async (req, res) => {
  try {
    const { id } = req.params;
    const { vehicleId } = req.body; // Véhicule optionnel avec lequel participer

    const ride = await Ride.findById(id);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier que la balade n'est pas passée
    const rideDate = new Date(ride.date);
    if (rideDate < new Date()) {
      return res.status(400).json({
        success: false,
        message: 'Impossible de rejoindre une balade passée'
      });
    }

    // Vérifier la visibilité
    if (ride.visibilite === 'privee') {
      const isOrganizer = ride.organisateur.toString() === req.user._id.toString();
      const isParticipant = ride.participants.some(
        p => p.toString() === req.user._id.toString()
      );
      
      if (!isOrganizer && !isParticipant) {
        return res.status(403).json({
          success: false,
          message: 'Cette balade est privée'
        });
      }
    }

    // Vérifier si l'utilisateur est déjà participant (comparaison de string pour éviter les problèmes d'ObjectId)
    const isAlreadyParticipant = ride.participants.some(
      p => p.userId && p.userId.toString() === req.user._id.toString()
    );
    
    if (isAlreadyParticipant) {
      return res.status(400).json({
        success: false,
        message: 'Vous êtes déjà participant à cette balade'
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

    // Calculer la compatibilité avec l'organisateur (optionnel, pour warning)
    let compatibility = null;
    try {
      compatibility = await compatibilityService.checkCompatibility(
        req.user._id.toString(),
        ride.organisateur.toString(),
        ride._id.toString()
      );
    } catch (error) {
      // Ne pas bloquer si le check de compatibilité échoue
      console.warn('Erreur lors du calcul de compatibilité:', error);
    }

    // Ajouter l'utilisateur aux participants avec la nouvelle structure
    ride.participants.push({
      userId: req.user._id,
      vehicleId: vehicleId || null
    });
    
    // Ajouter un événement participant_joined
    ride.rideEvents.push({
      type: 'participant_joined',
      timestamp: new Date(),
      userId: req.user._id,
      details: {}
    });
    
    await ride.save();
    await ride.populate('participants.userId', 'firstName lastName pseudo');
    await ride.populate('participants.vehicleId', 'nickname make model year');

    res.status(200).json({
      success: true,
      message: 'Vous avez rejoint la balade avec succès',
      data: { 
        ride,
        compatibility: compatibility || undefined // Inclure seulement si calculé
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
      message: 'Erreur lors de la participation à la balade',
      error: error.message
    });
  }
};

// Quitter une balade
exports.leaveRide = async (req, res, next) => {
  try {
    const { id } = req.params;

    const ride = await Ride.findById(id);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier si l'utilisateur est participant
    const isParticipant = ride.participants.some(
      p => p.toString() === req.user._id.toString()
    );
    
    if (!isParticipant) {
      return res.status(400).json({
        success: false,
        message: 'Vous n\'êtes pas participant à cette balade'
      });
    }

    // Ne pas permettre à l'organisateur de quitter sa propre balade
    if (ride.organisateur.toString() === req.user._id.toString()) {
      return res.status(400).json({
        success: false,
        message: 'L\'organisateur ne peut pas quitter sa propre balade'
      });
    }

    // Retirer l'utilisateur des participants
    ride.participants = ride.participants.filter(
      p => p.toString() !== req.user._id.toString()
    );
    
    // Ajouter un événement participant_left
    ride.rideEvents.push({
      type: 'participant_left',
      timestamp: new Date(),
      userId: req.user._id,
      details: {}
    });
    
    await ride.save();
    await ride.populate('participants.userId', 'firstName lastName pseudo');

    res.status(200).json({
      success: true,
      message: 'Vous avez quitté la balade avec succès',
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
      message: 'Erreur lors de la sortie de la balade',
      error: error.message
    });
  }
};

// Liker une balade
exports.likeRide = async (req, res, next) => {
  try {
    const { id } = req.params;

    const ride = await Ride.findById(id);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    const userId = req.user._id;
    const isLiked = ride.likes.includes(userId);

    if (isLiked) {
      // Retirer le like
      ride.likes = ride.likes.filter(like => like.toString() !== userId.toString());
      await ride.save();
      
      res.status(200).json({
        success: true,
        message: 'Like retiré',
        data: { ride, liked: false }
      });
    } else {
      // Ajouter le like
      ride.likes.push(userId);
      await ride.save();
      
      res.status(200).json({
        success: true,
        message: 'Balade likée avec succès',
        data: { ride, liked: true }
      });
    }
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID de balade invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors du like de la balade',
      error: error.message
    });
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
      p => p.toString() === req.user._id.toString()
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

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== userId.toString()) {
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

    // Vérifier le cache (inclure avoid dans la clé de cache)
    const cacheKey = { 
      origin, 
      destination, 
      waypoints: waypoints || '',
      avoid: avoidParam || ''
    };
    const cached = routeCache.get(cacheKey);
    if (cached) {
      return res.status(200).json(cached);
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

        response.on('end', () => {
          try {
            const jsonData = JSON.parse(data);
            
            if (jsonData.status === 'OK') {
              const responseData = {
                success: true,
                data: jsonData
              };
              // Mettre en cache
              routeCache.set(cacheKey, responseData);
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

    // Vérifier que l'utilisateur est l'organisateur
    if (ride.organisateur.toString() !== req.user._id.toString()) {
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
