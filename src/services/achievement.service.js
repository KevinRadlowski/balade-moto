const Achievement = require('../models/Achievement');
const Reputation = require('../models/Reputation');
const Ride = require('../models/Ride');

/**
 * Définition des badges disponibles
 */
const ACHIEVEMENT_DEFINITIONS = {
  first_ride: {
    name: 'Première balade',
    description: 'Vous avez participé à votre première balade',
    target: 1
  },
  ten_rides: {
    name: 'Routier',
    description: 'Vous avez participé à 10 balades',
    target: 10
  },
  fifty_rides: {
    name: 'Voyageur',
    description: 'Vous avez participé à 50 balades',
    target: 50
  },
  hundred_rides: {
    name: 'Explorateur',
    description: 'Vous avez participé à 100 balades',
    target: 100
  },
  organizer: {
    name: 'Organisateur',
    description: 'Vous avez organisé votre première balade',
    target: 1
  },
  regular_organizer: {
    name: 'Organisateur régulier',
    description: 'Vous avez organisé 10 balades',
    target: 10
  },
  punctual: {
    name: 'Ponctuel',
    description: 'Score de ponctualité supérieur à 90%',
    target: 90
  },
  social: {
    name: 'Social',
    description: 'Vous avez rejoint 5 groupes',
    target: 5
  },
  explorer: {
    name: 'Explorateur',
    description: 'Vous avez participé à des balades dans 10 villes différentes',
    target: 10
  },
  early_adopter: {
    name: 'Early Adopter',
    description: 'Vous êtes membre depuis plus d\'un an',
    target: 365
  },
  // Badges garage
  first_maintenance: {
    name: 'Premier entretien',
    description: 'Vous avez enregistré votre premier entretien',
    target: 1
  },
  maintenance_master: {
    name: 'Maître de l\'entretien',
    description: 'Vous avez enregistré 10 entretiens',
    target: 10
  },
  maintenance_expert: {
    name: 'Expert en entretien',
    description: 'Vous avez enregistré 25 entretiens',
    target: 25
  },
  first_document: {
    name: 'Premier document',
    description: 'Vous avez ajouté votre premier document',
    target: 1
  },
  document_collector: {
    name: 'Collectionneur de documents',
    description: 'Vous avez ajouté 10 documents',
    target: 10
  },
  first_photo: {
    name: 'Première photo',
    description: 'Vous avez ajouté votre première photo de véhicule',
    target: 1
  },
  photo_enthusiast: {
    name: 'Passionné de photos',
    description: 'Vous avez ajouté 10 photos de véhicules',
    target: 10
  },
  photo_gallery: {
    name: 'Galerie photo',
    description: 'Vous avez ajouté 25 photos de véhicules',
    target: 25
  },
  // Badges confiance
  reliable_rider: {
    name: 'Pilote fiable',
    description: 'Score de réputation supérieur à 70',
    target: 70
  },
  highly_trusted: {
    name: 'Hautement fiable',
    description: 'Score de réputation supérieur à 90',
    target: 90
  },
  // Badges profil
  profile_complete: {
    name: 'Profil complet',
    description: 'Votre profil est rempli à 100%',
    target: 100
  }
};

/**
 * Vérifie et débloque les badges pour un utilisateur
 * @param {String} userId - ID de l'utilisateur
 * @param {String} event - Type d'événement (ride_completed, ride_organized, etc.)
 * @param {Object} data - Données additionnelles
 */
const checkAndAwardAchievements = async (userId, event, data = {}) => {
  try {
    const achievements = [];

    // Compter les balades
    const ridesAsOrganizer = await Ride.countDocuments({
      organisateur: userId,
      date: { $lt: new Date() }
    });
    
    const ridesAsParticipant = await Ride.countDocuments({
      'participants.userId': userId,
      date: { $lt: new Date() }
    });
    
    const rideCount = ridesAsOrganizer + ridesAsParticipant;

    // Compter les balades organisées
    const organizedCount = await Ride.countDocuments({
      organisateur: userId,
      date: { $lt: new Date() }
    });

    // Vérifier first_ride
    if (rideCount >= 1) {
      await awardAchievement(userId, 'first_ride', 1, 1);
    }

    // Vérifier ten_rides
    if (rideCount >= 10) {
      await awardAchievement(userId, 'ten_rides', 10, 10);
    }

    // Vérifier fifty_rides
    if (rideCount >= 50) {
      await awardAchievement(userId, 'fifty_rides', 50, 50);
    }

    // Vérifier hundred_rides
    if (rideCount >= 100) {
      await awardAchievement(userId, 'hundred_rides', 100, 100);
    }

    // Vérifier organizer
    if (organizedCount >= 1) {
      await awardAchievement(userId, 'organizer', 1, 1);
    }

    // Vérifier regular_organizer
    if (organizedCount >= 10) {
      await awardAchievement(userId, 'regular_organizer', 10, 10);
    }

    // Vérifier punctual (nécessite réputation)
    const reputation = await Reputation.findOne({ userId });
    if (reputation) {
      await awardAchievement(userId, 'punctual', reputation.punctualityScore || 0, 90);
      await awardAchievement(userId, 'trusted_rider', reputation.score || 0, 80);
      await awardAchievement(userId, 'reliable_rider', reputation.score || 0, 70);
      await awardAchievement(userId, 'highly_trusted', reputation.score || 0, 90);
    }

    // Compter les véhicules de l'utilisateur
    const Vehicle = require('../models/Vehicle');
    const MaintenanceLog = require('../models/MaintenanceLog');
    const VehicleDocument = require('../models/VehicleDocument');
    const User = require('../models/User');

    const userVehicles = await Vehicle.find({ ownerUserId: userId }).select('_id');
    const vehicleIds = userVehicles.map(v => v._id);

    // Vérifier les badges d'entretien
    if (vehicleIds.length > 0) {
      const maintenanceCount = await MaintenanceLog.countDocuments({ vehicleId: { $in: vehicleIds } });
      await awardAchievement(userId, 'first_maintenance', maintenanceCount, 1);
      await awardAchievement(userId, 'maintenance_master', maintenanceCount, 10);
      await awardAchievement(userId, 'maintenance_expert', maintenanceCount, 25);
    }

    // Vérifier les badges de documents
    if (vehicleIds.length > 0) {
      const documentCount = await VehicleDocument.countDocuments({ vehicleId: { $in: vehicleIds } });
      await awardAchievement(userId, 'first_document', documentCount, 1);
      await awardAchievement(userId, 'document_collector', documentCount, 10);
    }

    // Vérifier les badges de photos
    if (vehicleIds.length > 0) {
      const vehiclesWithPhotos = await Vehicle.find({ 
        ownerUserId: userId,
        photos: { $exists: true, $ne: [] }
      }).select('photos');
      let photoCount = 0;
      vehiclesWithPhotos.forEach(vehicle => {
        if (vehicle.photos && Array.isArray(vehicle.photos)) {
          photoCount += vehicle.photos.length;
        }
      });
      await awardAchievement(userId, 'first_photo', photoCount, 1);
      await awardAchievement(userId, 'photo_enthusiast', photoCount, 10);
      await awardAchievement(userId, 'photo_gallery', photoCount, 25);
    }

    // Vérifier le badge de profil complet
    const user = await User.findById(userId);
    if (user) {
      const fields = {
        firstName: user.firstName ? 1 : 0,
        lastName: user.lastName ? 1 : 0,
        avatarUrl: user.avatarUrl ? 1 : 0,
        emergencyContact: (user.emergencyContact && user.emergencyContact.name && user.emergencyContact.phone) ? 1 : 0,
        vehiclePreference: user.vehiclePreference ? 1 : 0
      };
      const totalFields = Object.keys(fields).length;
      const completedFields = Object.values(fields).reduce((sum, val) => sum + val, 0);
      const profileCompletion = Math.round((completedFields / totalFields) * 100);
      await awardAchievement(userId, 'profile_complete', profileCompletion, 100);
    }

    return achievements;
  } catch (error) {
    console.error('Erreur lors de la vérification des badges:', error);
    throw error;
  }
};

/**
 * Débloque un badge pour un utilisateur
 * @param {String} userId - ID de l'utilisateur
 * @param {String} type - Type de badge
 * @param {Number} progress - Progression actuelle
 * @param {Number} target - Cible
 */
const awardAchievement = async (userId, type, progress, target) => {
  try {
    const definition = ACHIEVEMENT_DEFINITIONS[type];
    if (!definition) {
      console.warn(`Badge ${type} non défini`);
      return null;
    }

    // Vérifier si le badge existe déjà
    let achievement = await Achievement.findOne({ userId, type });

    if (!achievement) {
      // Créer le badge
      achievement = new Achievement({
        userId,
        type,
        name: definition.name,
        description: definition.description,
        progress: Math.min(progress, target),
        target,
        earnedAt: progress >= target ? new Date() : null
      });

      await achievement.save();

      if (progress >= target) {
        console.log(`✅ Badge débloqué: ${definition.name} pour l'utilisateur ${userId}`);
      }
    } else {
      // Mettre à jour la progression
      const oldProgress = achievement.progress;
      achievement.progress = Math.min(progress, target);
      if (progress >= target && !achievement.earnedAt) {
        achievement.earnedAt = new Date();
        console.log(`✅ Badge débloqué: ${definition.name} pour l'utilisateur ${userId}`);
      }
      // Ne sauvegarder que si la progression a changé
      if (achievement.progress !== oldProgress || achievement.isModified()) {
        await achievement.save();
      }
    }

    return achievement;
  } catch (error) {
    console.error(`Erreur lors du déblocage du badge ${type}:`, error);
    throw error;
  }
};

/**
 * Récupère tous les badges d'un utilisateur (avec progression)
 * @param {String} userId - ID de l'utilisateur
 * @returns {Promise<Array>} Liste des badges avec progression
 */
const getUserAchievements = async (userId) => {
  try {
    // Récupérer les badges existants de l'utilisateur
    const existingAchievements = await Achievement.find({ userId });
    const achievementsMap = new Map();
    existingAchievements.forEach(ach => {
      achievementsMap.set(ach.type, ach);
    });

    // Récupérer les statistiques de l'utilisateur pour calculer la progression
    const Ride = require('../models/Ride');
    const Group = require('../models/Group');
    const Reputation = require('../models/Reputation');
    const User = require('../models/User');
    const Vehicle = require('../models/Vehicle');
    const MaintenanceLog = require('../models/MaintenanceLog');
    const VehicleDocument = require('../models/VehicleDocument');

    // Compter les balades (organisateur ou participant)
    const ridesAsOrganizer = await Ride.countDocuments({
      organisateur: userId,
      date: { $lt: new Date() }
    });
    
    const ridesAsParticipant = await Ride.countDocuments({
      'participants.userId': userId,
      date: { $lt: new Date() }
    });
    
    const rideCount = ridesAsOrganizer + ridesAsParticipant;

    // Compter les balades organisées
    const organizedCount = await Ride.countDocuments({
      organisateur: userId,
      date: { $lt: new Date() }
    });

    // Compter les groupes
    const groupCount = await Group.countDocuments({
      'membres.userId': userId
    });

    // Récupérer la réputation
    const reputation = await Reputation.findOne({ userId });

    // Récupérer la date de création de l'utilisateur
    const user = await User.findById(userId);
    const daysSinceSignup = user ? Math.floor((new Date() - user.createdAt) / (1000 * 60 * 60 * 24)) : 0;

    // Récupérer les villes uniques visitées
    const ridesAsOrganizerForCities = await Ride.find({
      organisateur: userId,
      date: { $lt: new Date() }
    }).select('lieuDepart lieuArrivee');
    
    const ridesAsParticipantForCities = await Ride.find({
      'participants.userId': userId,
      date: { $lt: new Date() }
    }).select('lieuDepart lieuArrivee');
    
    const rides = [...ridesAsOrganizerForCities, ...ridesAsParticipantForCities];

    const cities = new Set();
    rides.forEach(ride => {
      if (ride.lieuDepart && typeof ride.lieuDepart === 'string') {
        const city = ride.lieuDepart.split(',')[0].trim();
        if (city) cities.add(city);
      }
      if (ride.lieuArrivee && typeof ride.lieuArrivee === 'string') {
        const city = ride.lieuArrivee.split(',')[0].trim();
        if (city) cities.add(city);
      }
    });
    const uniqueCitiesCount = cities.size;

    // Compter les véhicules de l'utilisateur
    const userVehicles = await Vehicle.find({ ownerUserId: userId }).select('_id');
    const vehicleIds = userVehicles.map(v => v._id);

    // Compter les entretiens (maintenance logs)
    const maintenanceCount = vehicleIds.length > 0
      ? await MaintenanceLog.countDocuments({ vehicleId: { $in: vehicleIds } })
      : 0;

    // Compter les documents
    const documentCount = vehicleIds.length > 0
      ? await VehicleDocument.countDocuments({ vehicleId: { $in: vehicleIds } })
      : 0;

    // Compter les photos (somme des photos de tous les véhicules)
    let photoCount = 0;
    if (vehicleIds.length > 0) {
      const vehiclesWithPhotos = await Vehicle.find({ 
        ownerUserId: userId,
        photos: { $exists: true, $ne: [] }
      }).select('photos');
      vehiclesWithPhotos.forEach(vehicle => {
        if (vehicle.photos && Array.isArray(vehicle.photos)) {
          photoCount += vehicle.photos.length;
        }
      });
    }

    // Calculer le pourcentage de complétion du profil
    let profileCompletion = 0;
    if (user) {
      const fields = {
        firstName: user.firstName ? 1 : 0,
        lastName: user.lastName ? 1 : 0,
        avatarUrl: user.avatarUrl ? 1 : 0,
        emergencyContact: (user.emergencyContact && user.emergencyContact.name && user.emergencyContact.phone) ? 1 : 0,
        vehiclePreference: user.vehiclePreference ? 1 : 0
      };
      const totalFields = Object.keys(fields).length;
      const completedFields = Object.values(fields).reduce((sum, val) => sum + val, 0);
      profileCompletion = Math.round((completedFields / totalFields) * 100);
    }

    // Construire la liste de tous les badges avec progression
    const allAchievements = Object.keys(ACHIEVEMENT_DEFINITIONS).map(type => {
      const definition = ACHIEVEMENT_DEFINITIONS[type];
      const existing = achievementsMap.get(type);

      // Calculer la progression selon le type de badge
      let progress = 0;
      if (type === 'first_ride' || type === 'five_rides' || type === 'ten_rides' || 
          type === 'twenty_five_rides' || type === 'fifty_rides' || type === 'hundred_rides') {
        progress = Math.min(rideCount, definition.target);
      } else if (type === 'organizer' || type === 'five_organizer' || type === 'regular_organizer') {
        progress = Math.min(organizedCount, definition.target);
      } else if (type === 'punctual') {
        progress = reputation ? Math.min(reputation.punctualityScore || 0, definition.target) : 0;
      } else if (type === 'social' || type === 'social_butterfly') {
        progress = Math.min(groupCount, definition.target);
      } else if (type === 'explorer' || type === 'city_explorer') {
        progress = Math.min(uniqueCitiesCount, definition.target);
      } else if (type === 'early_adopter') {
        progress = Math.min(daysSinceSignup, definition.target);
      } else if (type === 'trusted_rider') {
        progress = reputation ? Math.min(reputation.score || 0, definition.target) : 0;
      } else if (type === 'first_maintenance' || type === 'maintenance_master' || type === 'maintenance_expert') {
        progress = Math.min(maintenanceCount, definition.target);
      } else if (type === 'first_document' || type === 'document_collector') {
        progress = Math.min(documentCount, definition.target);
      } else if (type === 'first_photo' || type === 'photo_enthusiast' || type === 'photo_gallery') {
        progress = Math.min(photoCount, definition.target);
      } else if (type === 'reliable_rider' || type === 'highly_trusted') {
        progress = reputation ? Math.min(reputation.score || 0, definition.target) : 0;
      } else if (type === 'profile_complete') {
        progress = profileCompletion;
      }

      // Utiliser la progression existante si elle existe, sinon utiliser la progression calculée
      const finalProgress = existing ? existing.progress : progress;
      const isEarned = finalProgress >= definition.target;
      const finalEarnedAt = existing && existing.earnedAt 
        ? existing.earnedAt 
        : (isEarned ? new Date() : null);

      return {
        type,
        name: definition.name,
        description: definition.description,
        progress: finalProgress,
        target: definition.target,
        earnedAt: finalEarnedAt,
        _id: existing ? existing._id : null
      };
    });

    return allAchievements;
  } catch (error) {
    console.error('Erreur lors de la récupération des badges:', error);
    throw error;
  }
};

/**
 * Récupère la progression vers un badge spécifique
 * @param {String} userId - ID de l'utilisateur
 * @param {String} achievementType - Type de badge
 * @returns {Promise<Object>} Progression
 */
const getAchievementProgress = async (userId, achievementType) => {
  try {
    const achievement = await Achievement.findOne({ userId, type: achievementType });
    const definition = ACHIEVEMENT_DEFINITIONS[achievementType];

    if (!definition) {
      return null;
    }

    return {
      type: achievementType,
      name: definition.name,
      description: definition.description,
      progress: achievement?.progress || 0,
      target: definition.target,
      earned: achievement?.earnedAt ? true : false,
      earnedAt: achievement?.earnedAt || null
    };
  } catch (error) {
    console.error('Erreur lors de la récupération de la progression:', error);
    throw error;
  }
};

module.exports = {
  checkAndAwardAchievements,
  getUserAchievements,
  getAchievementProgress,
  ACHIEVEMENT_DEFINITIONS
};

