/**
 * Service pour la logique métier des balades (Rides)
 * Encapsule toute la logique métier, utilise le repository pour l'accès DB
 */

const rideRepository = require('../repositories/ride.repository');
const { enrichRidesWithLikes } = require('../utils/rideStats');
const { NotFoundError, ForbiddenError, BadRequestError, ConflictError } = require('../utils/errors');
const subscriptionService = require('../services/subscription.service');
const premiumConfig = require('../config/premium.config');
const { createPlanLimitError } = require('../utils/errors');

/**
 * Helper pour normaliser un organisateur supprimé ou introuvable
 */
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

/**
 * Construit les filtres pour la recherche de balades
 * @param {object} queryParams - Paramètres de requête
 * @param {object} user - Utilisateur actuel
 * @returns {object} Filtres MongoDB
 */
function buildRideFilters(queryParams, user) {
  const {
    typeVehicule,
    visibilite,
    dateDebut,
    dateFin,
    organisateur,
    participant,
    search
  } = queryParams;

  const filter = {};

  // Filtre type de véhicule
  if (typeVehicule && ['moto', 'voiture'].includes(typeVehicule)) {
    filter.typeVehicule = typeVehicule;
  }

  // Filtre visibilité
  if (visibilite && ['publique', 'privee', 'secrete'].includes(visibilite)) {
    filter.visibilite = visibilite;
  } else if (user) {
    // Par défaut, inclure les balades publiques + celles de l'utilisateur
    filter.$or = [
      { visibilite: 'publique' },
      { organisateur: user._id },
      { 'participants.userId': user._id }
    ];
  } else {
    // Utilisateur non authentifié : seulement publiques
    filter.visibilite = 'publique';
  }

  // Filtre organisateur
  if (organisateur) {
    filter.organisateur = organisateur;
  }

  // Filtre participant
  if (participant) {
    filter['participants.userId'] = participant;
  }

  // Filtre dates
  if (dateDebut || dateFin) {
    filter.date = {};
    if (dateDebut) {
      filter.date.$gte = new Date(dateDebut);
    }
    if (dateFin) {
      filter.date.$lte = new Date(dateFin);
    }
  }

  // Filtre recherche textuelle
  if (search) {
    filter.$or = [
      ...(filter.$or || []),
      { titre: { $regex: search, $options: 'i' } },
      { description: { $regex: search, $options: 'i' } }
    ];
  }

  return filter;
}

/**
 * Construit les filtres pour la recherche géospatiale
 * @param {object} queryParams - Paramètres de requête
 * @param {object} user - Utilisateur actuel
 * @returns {object} Filtres MongoDB
 */
function buildGeospatialFilters(queryParams, user) {
  const { lat, lng, rayon, typeVehicule, visibilite, dateDebut, dateFin, organisateur, participant, search } = queryParams;
  
  const filter = {
    localisation: {
      $exists: true,
      $ne: null
    }
  };

  if (participant) {
    filter.$or = [
      { 'participants.userId': participant },
      { organisateur: participant }
    ];
  } else {
    if (visibilite && ['privee', 'publique'].includes(visibilite)) {
      filter.visibilite = visibilite;
    } else if (user) {
      filter.$or = [
        { visibilite: 'publique' },
        { visibilite: 'privee', organisateur: user._id },
        { visibilite: 'privee', 'participants.userId': user._id },
        { visibilite: 'privee', 'invitations.userId': user._id, 'invitations.status': { $in: ['pending', 'accepted'] } },
        { visibilite: 'secrete', organisateur: user._id },
        { visibilite: 'secrete', 'participants.userId': user._id }
      ];
    } else {
      filter.visibilite = 'publique';
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

  return filter;
}

/**
 * Liste les balades avec filtres et pagination (avec support géospatial)
 * @param {object} queryParams - Paramètres de requête
 * @param {object} user - Utilisateur actuel
 * @returns {Promise<object>} { rides, total, pagination }
 */
async function listRides(queryParams, user) {
  const pagination = require('../utils/pagination');
  const { validatedPage, validatedLimit } = pagination.validatePaginationParams(
    queryParams.page || 1,
    queryParams.limit || 20
  );
  const skip = (validatedPage - 1) * validatedLimit;

  const { lat, lng, rayon } = queryParams;
  const sortBy = queryParams.sortBy || 'date';
  const sortOrder = queryParams.sortOrder === 'desc' ? -1 : 1;

  // Si recherche géospatiale
  if (lat && lng && rayon) {
    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);
    const radiusKm = Math.min(parseFloat(rayon) || 200, 200);

    if (!isNaN(latitude) && !isNaN(longitude) && 
        latitude >= -90 && latitude <= 90 && 
        longitude >= -180 && longitude <= 180 &&
        !isNaN(radiusKm) && radiusKm > 0 && radiusKm <= 200) {
      
      const filter = buildGeospatialFilters(queryParams, user);
      
      // Pipeline d'aggregation pour géospatial
      const pipeline = [
        {
          $geoNear: {
            near: {
              type: 'Point',
              coordinates: [longitude, latitude]
            },
            distanceField: 'distance',
            maxDistance: radiusKm * 1000,
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
            localField: 'participants.userId',
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
            isOrganizerPremium: -1,
            distance: 1,
            [sortBy]: sortOrder
          }
        },
        {
          $skip: skip
        },
        {
          $limit: validatedLimit
        }
      ];

      const rides = await rideRepository.aggregate(pipeline);
      const total = await rideRepository.count(filter);

      // Enrichir avec les likes
      const enrichedRides = await enrichRidesWithLikes(rides, user?._id);

      // Ajouter isOrganizerPremium
      const ridesWithPremium = enrichedRides.map(ride => {
        const isOrganizerPremium = ride.organisateur && 
          subscriptionService.isPremiumActive(ride.organisateur);
        
        return {
          ...ride,
          isOrganizerPremium: isOrganizerPremium || false
        };
      });

      return {
        rides: ridesWithPremium,
        total,
        pagination: {
          page: validatedPage,
          limit: validatedLimit,
          total,
          pages: Math.ceil(total / validatedLimit)
        }
      };
    }
  }

  // Recherche classique
  const filter = buildRideFilters(queryParams, user);
  
  // Par défaut, ne montrer que les balades futures (sauf si dateDebut/dateFin spécifiées)
  if (!queryParams.dateDebut && !queryParams.dateFin) {
    filter.date = { $gte: new Date() };
  }

  const sort = { [sortBy]: sortOrder };

  // Options de populate
  const populate = [
    { path: 'organisateur', select: 'firstName lastName pseudo email subscription.isPremium subscription.premiumExpiresAt' },
    { path: 'participants.userId', select: 'firstName lastName pseudo' }
  ];

  // Récupérer les balades
  const rides = await rideRepository.find(filter, {
    skip,
    limit: validatedLimit,
    sort,
    populate,
    lean: true
  });

  // Compter le total
  const total = await rideRepository.count(filter);

  // Trier les balades : premium en premier, puis selon le tri demandé
  rides.sort((a, b) => {
    const aIsPremium = a.organisateur && subscriptionService.isPremiumActive(a.organisateur);
    const bIsPremium = b.organisateur && subscriptionService.isPremiumActive(b.organisateur);
    
    if (aIsPremium && !bIsPremium) return -1;
    if (!aIsPremium && bIsPremium) return 1;
    
    const aValue = a[sortBy];
    const bValue = b[sortBy];
    
    if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
    if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
    return 0;
  });

  // Enrichir avec les likes
  const enrichedRides = await enrichRidesWithLikes(rides, user?._id);

  // Ajouter isOrganizerPremium
  const ridesWithPremium = enrichedRides.map(ride => {
    const isOrganizerPremium = ride.organisateur && 
      subscriptionService.isPremiumActive(ride.organisateur);
    
    return {
      ...ride,
      isOrganizerPremium: isOrganizerPremium || false
    };
  });

  return {
    rides: ridesWithPremium,
    total,
    pagination: {
      page: validatedPage,
      limit: validatedLimit,
      total,
      pages: Math.ceil(total / validatedLimit)
    }
  };
}

/**
 * Récupère une balade par ID avec vérification d'accès
 * @param {string} rideId - ID de la balade
 * @param {object} user - Utilisateur actuel
 * @returns {Promise<object>} Balade enrichie
 */
async function getRideById(rideId, user) {
  const populate = [
    { path: 'organisateur', select: 'firstName lastName pseudo email vehiclePreference subscription.isPremium subscription.premiumExpiresAt' },
    { path: 'participants.userId', select: 'firstName lastName pseudo' },
    { path: 'invitations.userId', select: 'firstName lastName pseudo' }
  ];

  const ride = await rideRepository.findById(rideId, { populate });

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Normaliser l'organisateur
  ride.organisateur = normalizeOrganizer(ride.organisateur);

  // Vérifier la visibilité
  if (user) {
    const isOrganizer = ride.organisateur && ride.organisateur._id && 
      ride.organisateur._id.toString() === user._id.toString();
    const isParticipant = ride.participants.some(
      p => p.userId && (p.userId._id ? p.userId._id.toString() : p.userId.toString()) === user._id.toString()
    );
    const isInvited = ride.invitations && ride.invitations.some(
      inv => inv.userId && (inv.userId._id ? inv.userId._id.toString() : inv.userId.toString()) === user._id.toString() &&
      (inv.status === 'pending' || inv.status === 'accepted')
    );

    if (ride.visibilite === 'privee') {
      if (!isOrganizer && !isParticipant && !isInvited) {
        throw new ForbiddenError('Vous n\'avez pas accès à cette balade privée');
      }
    } else if (ride.visibilite === 'secrete') {
      if (!isOrganizer && !isParticipant) {
        throw new ForbiddenError('Cette balade est secrète. Accès uniquement via le lien secret.');
      }
    }
  } else {
    // Utilisateur non authentifié : seulement balades publiques
    if (ride.visibilite !== 'publique') {
      throw new ForbiddenError('Accès non autorisé');
    }
  }

  // Enrichir avec les likes
  const enrichedRides = await enrichRidesWithLikes([ride], user?._id);
  const enrichedRide = enrichedRides[0] || ride;

  // Convertir en objet
  const rideObj = ride.toObject ? ride.toObject() : { ...ride };
  rideObj.totalLikes = enrichedRide.totalLikes || 0;
  rideObj.hasUserLiked = enrichedRide.hasUserLiked || false;
  rideObj.organisateur = normalizeOrganizer(rideObj.organisateur);
  rideObj.isOrganizerPremium = ride.organisateur && 
    subscriptionService.isPremiumActive(ride.organisateur) || false;
  
  // Ajouter le résumé des waypoints
  rideObj.waypointSummary = calculateWaypointSummary(rideObj);

  return rideObj;
}

/**
 * Crée une nouvelle balade
 * @param {object} rideData - Données de la balade depuis req.body
 * @param {object} user - Utilisateur créateur
 * @returns {Promise<object>} Balade créée
 */
async function createRide(rideData, user) {
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
    waypoints,
    vehicleId,
    ridingStyle,
    groupId // Nouveau : association avec un groupe
  } = rideData;

  // Vérifier les limites du plan pour les balades privées
  const userPlan = premiumConfig.getUserPlan(user);
  const limits = premiumConfig.getPlanLimits(userPlan);

  const hasWaypoints = waypoints && Array.isArray(waypoints) && waypoints.length >= 2;
  
  if (!hasWaypoints && (!lieuDepart || !lieuArrivee)) {
    throw new BadRequestError('Vous devez fournir soit des waypoints (départ, checkpoints, arrivée), soit un lieu de départ et d\'arrivée');
  }

  const rideDate = new Date(date);
  if (rideDate < new Date()) {
    throw new BadRequestError('La date de la balade doit être dans le futur');
  }

  // Préparer la localisation
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
      rideLocalisation = {
        type: 'Point',
        coordinates: [parseFloat(localisation.longitude), parseFloat(localisation.latitude)]
      };
    } else if (localisation.type === 'Point' && Array.isArray(localisation.coordinates)) {
      rideLocalisation = {
        type: 'Point',
        coordinates: localisation.coordinates
      };
    }
  }

  // Préparer les lieux de départ et d'arrivée
  let finalLieuDepart = lieuDepart;
  let finalLieuArrivee = lieuArrivee;
  
  if (hasWaypoints) {
    const departWaypoint = waypoints.find(w => w.type === 'depart') || waypoints[0];
    const arriveeWaypoint = waypoints.find(w => w.type === 'arrivee') || waypoints[waypoints.length - 1];
    
    finalLieuDepart = departWaypoint.address || JSON.stringify(departWaypoint.coordinates);
    finalLieuArrivee = arriveeWaypoint.address || JSON.stringify(arriveeWaypoint.coordinates);
  }

  const finalVisibilite = visibilite || 'publique';
  
  // Vérifier la limite de balades privées par mois
  if (finalVisibilite === 'privee' && !premiumConfig.isPremium(userPlan)) {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const privateRidesThisMonth = await rideRepository.count({
      organisateur: user._id,
      visibilite: 'privee',
      date: { $gte: startOfMonth }
    });
    
    if (privateRidesThisMonth >= limits.maxPrivateRidesCreatedPerMonth) {
      throw createPlanLimitError(
        'maxPrivateRidesCreatedPerMonth',
        limits.maxPrivateRidesCreatedPerMonth,
        privateRidesThisMonth,
        userPlan,
        'balade(s) privée(s) par mois'
      );
    }
  }
  
  // Valider le véhicule si fourni
  let validatedVehicleId = null;
  if (vehicleId) {
    const Vehicle = require('../models/Vehicle');
    const vehicle = await Vehicle.findOne({
      _id: vehicleId,
      ownerUserId: user._id,
      active: true
    });
    
    if (!vehicle) {
      throw new BadRequestError('Véhicule non trouvé ou n\'appartient pas à l\'utilisateur');
    }
    
    if (vehicle.type !== typeVehicule) {
      throw new BadRequestError(`Le véhicule sélectionné est de type "${vehicle.type}" mais la balade est de type "${typeVehicule}"`);
    }
    
    validatedVehicleId = vehicle._id;
  }
  
  // Vérifier que le groupe existe si groupId est fourni
  if (groupId) {
    const Group = require('../models/Group');
    const group = await Group.findById(groupId);
    if (!group) {
      throw new NotFoundError('Groupe');
    }
    // Vérifier que l'utilisateur est membre du groupe
    if (!group.isMember(user._id) && group.createur.toString() !== user._id.toString()) {
      throw new ForbiddenError('Vous devez être membre du groupe pour créer une balade associée');
    }
  }

  // Préparer les données finales de la balade
  const finalRideData = {
    titre,
    description,
    typeVehicule,
    date: rideDate,
    heure,
    lieuDepart: finalLieuDepart,
    lieuArrivee: finalLieuArrivee,
    rayon: rayon || 0,
    organisateur: user._id,
    groupId: groupId || null, // Associer au groupe si fourni
    visibilite: finalVisibilite,
    participants: [{ 
      userId: user._id,
      vehicleId: validatedVehicleId
    }],
    localisation: rideLocalisation,
    status: 'scheduled',
    ridingStyle: ridingStyle || null,
    rideEvents: []
  };

  // Ajouter les waypoints si présents (normalisés avec nouveaux champs)
  if (hasWaypoints) {
    finalRideData.waypoints = normalizeWaypoints(waypoints, user._id);
  }

  // Créer la balade
  const populate = [
    { path: 'organisateur', select: 'firstName lastName pseudo email' },
    { path: 'participants.userId', select: 'firstName lastName pseudo' }
  ];

  const ride = await rideRepository.create(finalRideData, { populate });

  return ride;
}

/**
 * Rejoint une balade
 * @param {string} rideId - ID de la balade
 * @param {object} user - Utilisateur
 * @param {string} vehicleId - ID du véhicule (optionnel)
 * @returns {Promise<object>} { ride, status, position?, compatibility? }
 */
async function joinRide(rideId, user, vehicleId = null) {
  const ride = await rideRepository.findById(rideId);

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que la balade n'est pas passée
  const rideDate = new Date(ride.date);
  if (rideDate < new Date()) {
    throw new BadRequestError('Impossible de rejoindre une balade passée');
  }

  // Vérifier la visibilité
  if (ride.visibilite === 'privee') {
    const isOrganizer = ride.organisateur.toString() === user._id.toString();
    const isParticipant = ride.participants.some(
      p => p.userId && p.userId.toString() === user._id.toString()
    );
    const isInvited = ride.invitations && ride.invitations.some(
      inv => inv.userId && inv.userId.toString() === user._id.toString() && 
      (inv.status === 'pending' || inv.status === 'accepted')
    );
    
    if (!isOrganizer && !isParticipant && !isInvited) {
      throw new ForbiddenError('Cette balade est privée');
    }
  }

  // Vérifier si l'utilisateur est déjà participant
  const isAlreadyParticipant = ride.participants.some(
    p => p.userId && p.userId.toString() === user._id.toString()
  );
  
  if (isAlreadyParticipant) {
    throw new ConflictError('Vous êtes déjà participant à cette balade');
  }

  // Vérifier si l'utilisateur est déjà en liste d'attente
  const isInWaitlist = ride.waitlist?.some(
    w => w.userId.toString() === user._id.toString()
  );
  if (isInWaitlist) {
    throw new BadRequestError('Vous êtes déjà en liste d\'attente pour cette balade');
  }

  // Vérifier si une demande est déjà en attente
  const hasPendingRequest = ride.pendingRequests?.some(
    r => r.userId.toString() === user._id.toString()
  );
  if (hasPendingRequest) {
    throw new BadRequestError('Vous avez déjà une demande en attente pour cette balade');
  }

  // Valider le véhicule si fourni
  if (vehicleId) {
    const Vehicle = require('../models/Vehicle');
    const vehicle = await Vehicle.findById(vehicleId);
    
    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== user._id.toString()) {
      throw new ForbiddenError('Ce véhicule ne vous appartient pas');
    }

    if (vehicle.type !== ride.typeVehicule) {
      throw new BadRequestError(`Le type de véhicule ne correspond pas (balade: ${ride.typeVehicule}, véhicule: ${vehicle.type})`);
    }
  }

  // Si validation manuelle requise, créer une demande
  if (ride.requiresApproval) {
    ride.pendingRequests = ride.pendingRequests || [];
    ride.pendingRequests.push({
      userId: user._id,
      vehicleId: vehicleId || null,
      requestedAt: new Date()
    });
    await ride.save();

    return {
      ride,
      status: 'pending_approval'
    };
  }

  // Vérifier la limite de participants
  if (ride.maxParticipants && ride.participants.length >= ride.maxParticipants) {
    // Si liste d'attente activée, ajouter à la waitlist
    if (ride.enableWaitlist) {
      ride.waitlist = ride.waitlist || [];
      const position = ride.waitlist.length + 1;
      ride.waitlist.push({
        userId: user._id,
        vehicleId: vehicleId || null,
        addedAt: new Date(),
        position
      });
      await ride.save();

      return {
        ride,
        status: 'waitlisted',
        position
      };
    } else {
      throw new BadRequestError('La balade est complète');
    }
  }

  // Calculer la compatibilité avec l'organisateur (optionnel)
  let compatibility = null;
  try {
    const compatibilityService = require('../services/compatibility.service');
    compatibility = await compatibilityService.checkCompatibility(
      user._id.toString(),
      ride.organisateur.toString(),
      ride._id.toString()
    );
  } catch (error) {
    // Ne pas bloquer si le check de compatibilité échoue
    console.warn('Erreur lors du calcul de compatibilité:', error);
  }

  // Ajouter le participant
  ride.participants.push({
    userId: user._id,
    vehicleId: vehicleId || null
  });
  
  // Ajouter un événement participant_joined
  ride.rideEvents.push({
    type: 'participant_joined',
    timestamp: new Date(),
    userId: user._id,
    details: {}
  });
  
  await ride.save();

  // Populate pour retour
  await ride.populate('organisateur', 'firstName lastName pseudo email');
  await ride.populate('participants.userId', 'firstName lastName pseudo');
  await ride.populate('participants.vehicleId', 'nickname make model year');

  return {
    ride,
    status: 'joined',
    compatibility: compatibility || undefined
  };
}

/**
 * Quitte une balade
 * @param {string} rideId - ID de la balade
 * @param {object} user - Utilisateur
 * @returns {Promise<object>} Balade mise à jour
 */
async function leaveRide(rideId, user) {
  const ride = await rideRepository.findById(rideId);

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier si l'utilisateur est participant
  const isParticipant = ride.participants.some(
    p => p.userId && p.userId.toString() === user._id.toString()
  );
  
  if (!isParticipant) {
    throw new BadRequestError('Vous n\'êtes pas participant à cette balade');
  }

  // Ne pas permettre à l'organisateur de quitter sa propre balade
  if (ride.organisateur && ride.organisateur.toString() === user._id.toString()) {
    throw new BadRequestError('L\'organisateur ne peut pas quitter sa propre balade');
  }

  // Retirer le participant
  ride.participants = ride.participants.filter(
    p => !p.userId || p.userId.toString() !== user._id.toString()
  );
  
  // Ajouter un événement participant_left
  ride.rideEvents.push({
    type: 'participant_left',
    timestamp: new Date(),
    userId: user._id,
    details: {}
  });
  
  await ride.save();

  // Populate pour retour
  await ride.populate('organisateur', 'firstName lastName pseudo email');
  await ride.populate('participants.userId', 'firstName lastName pseudo');

  return ride;
}

/**
 * Like une balade
 * Note: Le modèle Ride a un champ `likes` (array) ET il y a un modèle Like séparé
 * Cette fonction utilise le modèle Like pour la cohérence avec rideStats
 * @param {string} rideId - ID de la balade
 * @param {object} user - Utilisateur
 * @returns {Promise<object>} Like créé
 */
async function likeRide(rideId, user) {
  const Like = require('../models/Like');

  // Vérifier que la balade existe
  const ride = await rideRepository.findById(rideId);
  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier si l'utilisateur a déjà liké (modèle Like)
  const existingLike = await Like.findOne({
    balade: rideId,
    utilisateur: user._id
  });

  if (existingLike) {
    throw new ConflictError('Vous avez déjà liké cette balade');
  }

  // Créer le like dans le modèle Like
  const like = new Like({
    balade: rideId,
    utilisateur: user._id
  });

  await like.save();

  // Optionnel: Mettre à jour aussi ride.likes si le modèle le supporte
  // (pour compatibilité avec l'ancien système)
  if (ride.likes && Array.isArray(ride.likes)) {
    if (!ride.likes.includes(user._id)) {
      ride.likes.push(user._id);
      await ride.save();
    }
  }

  return like;
}

/**
 * Unlike une balade
 * @param {string} rideId - ID de la balade
 * @param {object} user - Utilisateur
 * @returns {Promise<void>}
 */
async function unlikeRide(rideId, user) {
  const Like = require('../models/Like');

  // Supprimer le like du modèle Like
  const like = await Like.findOneAndDelete({
    balade: rideId,
    utilisateur: user._id
  });

  if (!like) {
    throw new NotFoundError('Like');
  }

  // Optionnel: Retirer aussi de ride.likes si le modèle le supporte
  const ride = await rideRepository.findById(rideId);
  if (ride && ride.likes && Array.isArray(ride.likes)) {
    ride.likes = ride.likes.filter(
      likeId => likeId && likeId.toString() !== user._id.toString()
    );
    await ride.save();
  }
}

/**
 * Met à jour une balade
 * @param {string} rideId - ID de la balade
 * @param {object} updateData - Données à mettre à jour
 * @param {object} user - Utilisateur
 * @returns {Promise<object>} Balade mise à jour
 */
/**
 * Associer une balade à un groupe
 * @param {string} rideId - ID de la balade
 * @param {string} groupId - ID du groupe
 * @param {object} user - Utilisateur (doit être organisateur de la balade ET membre du groupe)
 * @returns {Promise<object>} Balade mise à jour
 */
async function associateRideToGroup(rideId, groupId, user) {
  const ride = await rideRepository.findById(rideId);
  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que le groupe existe
  const Group = require('../models/Group');
  const group = await Group.findById(groupId);
  if (!group) {
    throw new NotFoundError('Groupe');
  }

  // Vérifier que l'utilisateur est membre du groupe
  if (!group.isMember(user._id) && group.createur.toString() !== user._id.toString()) {
    throw new ForbiddenError('Vous devez être membre du groupe pour associer une balade');
  }

  // Vérifier les permissions pour associer la balade :
  // - L'utilisateur est l'organisateur OU
  // - La balade est publique OU
  // - L'utilisateur est participant à la balade
  const isOrganizer = ride.organisateur.toString() === user._id.toString();
  const isParticipant = ride.participants && ride.participants.some(
    p => p.userId && p.userId.toString() === user._id.toString()
  );
  const isPublic = ride.visibilite === 'publique';

  if (!isOrganizer && !isPublic && !isParticipant) {
    throw new ForbiddenError('Vous ne pouvez associer que vos propres balades, les balades publiques ou celles auxquelles vous participez');
  }

  // Associer le groupe à la balade (même si déjà associée à un autre groupe, on la réassocie)
  ride.groupId = groupId;
  await ride.save();

  return ride;
}

async function updateRide(rideId, updateData, user) {
  const ride = await rideRepository.findById(rideId);

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Normaliser l'organisateur
  ride.organisateur = normalizeOrganizer(ride.organisateur);

  // Vérifier que l'utilisateur est l'organisateur (ou que l'organisateur est supprimé)
  const isOrganizer = ride.organisateur && ride.organisateur._id && 
    ride.organisateur._id.toString() === user._id.toString();
  
  if (!isOrganizer && !ride.organisateur.isDeleted) {
    throw new ForbiddenError('Vous n\'êtes pas autorisé à modifier cette balade');
  }

  // Extraire les champs à mettre à jour
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
    localisation
  } = updateData;

  // Mettre à jour les champs fournis
  if (titre !== undefined) ride.titre = titre;
  if (description !== undefined) ride.description = description;
  if (typeVehicule !== undefined) ride.typeVehicule = typeVehicule;
  if (date !== undefined) {
    const rideDate = new Date(date);
    if (rideDate < new Date()) {
      throw new BadRequestError('La date de la balade doit être dans le futur');
    }
    ride.date = rideDate;
  }
  if (heure !== undefined) ride.heure = heure;
  if (lieuDepart !== undefined) ride.lieuDepart = lieuDepart;
  if (lieuArrivee !== undefined) ride.lieuArrivee = lieuArrivee;
  if (rayon !== undefined) ride.rayon = rayon;
  if (visibilite !== undefined) ride.visibilite = visibilite;
  
  // Gérer la localisation GPS
  if (localisation !== undefined) {
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

  // Populate pour retour
  const populate = [
    { path: 'organisateur', select: 'firstName lastName pseudo email' },
    { path: 'participants.userId', select: 'firstName lastName pseudo' }
  ];
  
  for (const pop of populate) {
    await ride.populate(pop.path, pop.select);
  }

  return ride;
}

/**
 * Supprime une balade
 * @param {string} rideId - ID de la balade
 * @param {object} user - Utilisateur
 * @returns {Promise<void>}
 */
async function deleteRide(rideId, user) {
  const ride = await rideRepository.findById(rideId);

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Normaliser l'organisateur
  ride.organisateur = normalizeOrganizer(ride.organisateur);

  // Vérifier que l'utilisateur est l'organisateur
  const isOrganizer = ride.organisateur && ride.organisateur._id && 
    ride.organisateur._id.toString() === user._id.toString();
  
  if (!isOrganizer && !ride.organisateur.isDeleted) {
    throw new ForbiddenError('Vous n\'êtes pas autorisé à supprimer cette balade');
  }

  // Supprimer la balade
  await rideRepository.deleteById(rideId);
}

/**
 * Normalise les waypoints lors de la création/mise à jour
 * Gère la rétrocompatibilité avec l'ancien format
 * @param {Array} waypoints - Waypoints à normaliser
 * @param {string} userId - ID de l'utilisateur créateur
 * @returns {Array} Waypoints normalisés
 */
function normalizeWaypoints(waypoints, userId) {
  if (!waypoints || !Array.isArray(waypoints)) {
    return [];
  }

  return waypoints.map((wp, index) => {
    // Si waypoint a lat/lng sans location/type => créer location Point + type="normal"
    let coordinates = null;
    if (wp.coordinates) {
      if (wp.coordinates.coordinates && Array.isArray(wp.coordinates.coordinates)) {
        coordinates = wp.coordinates;
      } else if (Array.isArray(wp.coordinates)) {
        coordinates = {
          type: 'Point',
          coordinates: wp.coordinates
        };
      }
    } else if (wp.latitude !== undefined && wp.longitude !== undefined) {
      // Ancien format lat/lng
      coordinates = {
        type: 'Point',
        coordinates: [parseFloat(wp.longitude), parseFloat(wp.latitude)]
      };
    }

    if (!coordinates || !coordinates.coordinates || coordinates.coordinates.length !== 2) {
      throw new BadRequestError(`Waypoint ${index}: coordonnées invalides`);
    }

    return {
      type: wp.type || (index === 0 ? 'depart' : index === waypoints.length - 1 ? 'arrivee' : 'checkpoint'),
      address: wp.address || '',
      coordinates: coordinates,
      order: wp.order !== undefined ? wp.order : index,
      waypointType: wp.waypointType || 'normal',
      isMandatoryStop: wp.isMandatoryStop || false,
      note: wp.note || null,
      createdBy: wp.createdBy || userId || null,
      createdAt: wp.createdAt || new Date()
    };
  });
}

/**
 * Calcule le résumé des waypoints d'une balade
 * @param {object} ride - La balade
 * @returns {object} Résumé des waypoints
 */
function calculateWaypointSummary(ride) {
  if (!ride.waypoints || !Array.isArray(ride.waypoints)) {
    return {
      mandatoryStopsCount: 0,
      dangerCount: 0,
      fuelStopsCount: 0,
      coffeeStopsCount: 0,
      viewpointCount: 0
    };
  }

  const summary = {
    mandatoryStopsCount: 0,
    dangerCount: 0,
    fuelStopsCount: 0,
    coffeeStopsCount: 0,
    viewpointCount: 0
  };

  ride.waypoints.forEach(wp => {
    if (wp.isMandatoryStop) {
      summary.mandatoryStopsCount++;
    }
    switch (wp.waypointType) {
      case 'danger':
        summary.dangerCount++;
        break;
      case 'fuel':
        summary.fuelStopsCount++;
        break;
      case 'coffee':
        summary.coffeeStopsCount++;
        break;
      case 'viewpoint':
        summary.viewpointCount++;
        break;
    }
  });

  return summary;
}

/**
 * Ajoute ou modifie un waypoint dans une balade
 * @param {string} rideId - ID de la balade
 * @param {object} waypointData - Données du waypoint
 * @param {object} user - Utilisateur effectuant l'action
 * @returns {Promise<object>} La balade mise à jour
 */
async function addOrUpdateWaypoint(rideId, waypointData, user) {
  const ride = await rideRepository.findById(rideId);

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que l'utilisateur est l'organisateur
  if (ride.organisateur.toString() !== user._id.toString()) {
    throw new ForbiddenError('Vous n\'êtes pas autorisé à modifier les waypoints de cette balade');
  }

  // Normaliser le waypoint
  const normalizedWaypoint = normalizeWaypoints([waypointData], user._id)[0];

  // Si waypointId fourni, mettre à jour le waypoint existant
  if (waypointData._id || waypointData.id) {
    const waypointId = waypointData._id || waypointData.id;
    const waypointIndex = ride.waypoints.findIndex(
      wp => wp._id && wp._id.toString() === waypointId.toString()
    );

    if (waypointIndex === -1) {
      throw new NotFoundError('Waypoint');
    }

    // Mettre à jour le waypoint
    ride.waypoints[waypointIndex] = {
      ...ride.waypoints[waypointIndex].toObject(),
      ...normalizedWaypoint,
      _id: ride.waypoints[waypointIndex]._id // Conserver l'ID existant
    };
  } else {
    // Ajouter un nouveau waypoint
    ride.waypoints.push(normalizedWaypoint);
  }

  await ride.save();

  const populatedRide = await rideRepository.findById(rideId, {
    populate: [
      { path: 'organisateur', select: 'firstName lastName pseudo email' },
      { path: 'participants.userId', select: 'firstName lastName pseudo' }
    ]
  });

  return populatedRide;
}

/**
 * Supprime un waypoint d'une balade
 * @param {string} rideId - ID de la balade
 * @param {string} waypointId - ID du waypoint
 * @param {object} user - Utilisateur effectuant l'action
 * @returns {Promise<object>} La balade mise à jour
 */
async function deleteWaypoint(rideId, waypointId, user) {
  const ride = await rideRepository.findById(rideId);

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que l'utilisateur est l'organisateur
  if (ride.organisateur.toString() !== user._id.toString()) {
    throw new ForbiddenError('Vous n\'êtes pas autorisé à supprimer les waypoints de cette balade');
  }

  // Vérifier qu'il reste au moins 2 waypoints (départ et arrivée)
  if (ride.waypoints.length <= 2) {
    throw new BadRequestError('Une balade doit avoir au moins un départ et une arrivée');
  }

  const waypointIndex = ride.waypoints.findIndex(
    wp => wp._id && wp._id.toString() === waypointId.toString()
  );

  if (waypointIndex === -1) {
    throw new NotFoundError('Waypoint');
  }

  // Ne pas permettre la suppression du départ ou de l'arrivée
  const waypoint = ride.waypoints[waypointIndex];
  if (waypoint.type === 'depart' || waypoint.type === 'arrivee') {
    throw new BadRequestError('Le départ et l\'arrivée ne peuvent pas être supprimés');
  }

  ride.waypoints.splice(waypointIndex, 1);

  // Réordonner les waypoints
  ride.waypoints.forEach((wp, index) => {
    wp.order = index;
  });

  await ride.save();

  const populatedRide = await rideRepository.findById(rideId, {
    populate: [
      { path: 'organisateur', select: 'firstName lastName pseudo email' },
      { path: 'participants.userId', select: 'firstName lastName pseudo' }
    ]
  });

  return populatedRide;
}

module.exports = {
  associateRideToGroup,
  listRides,
  getRideById,
  createRide,
  updateRide,
  deleteRide,
  joinRide,
  leaveRide,
  likeRide,
  unlikeRide,
  normalizeOrganizer,
  buildRideFilters,
  buildGeospatialFilters,
  normalizeWaypoints,
  calculateWaypointSummary,
  addOrUpdateWaypoint,
  deleteWaypoint
};

