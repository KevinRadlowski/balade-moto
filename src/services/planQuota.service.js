const Vehicle = require('../models/Vehicle');
const Group = require('../models/Group');
const Ride = require('../models/Ride');

/**
 * Service pour compter les quotas d'utilisation des utilisateurs
 * 
 * Ce service ne connaît pas les limites FREE/PREMIUM, il ne fait que compter.
 * Les limites sont définies dans premium.config.js
 */

/**
 * Compte les véhicules d'un utilisateur
 * @param {string|ObjectId} userId - L'ID de l'utilisateur
 * @returns {Promise<object>} { total, byType: { moto, voiture }, photosTotal }
 */
async function countVehiclesByUser(userId) {
  if (!userId) {
    throw new Error('userId est requis');
  }

  // Convertir userId en ObjectId si nécessaire
  const mongoose = require('mongoose');
  const userIdObjectId = typeof userId === 'string' && mongoose.Types.ObjectId.isValid(userId)
    ? new mongoose.Types.ObjectId(userId)
    : userId;

  // Utiliser une aggregation pour optimiser les requêtes
  // IMPORTANT: Ne compter que les véhicules actifs (active=true)
  const result = await Vehicle.aggregate([
    {
      $match: {
        ownerUserId: userIdObjectId,
        active: true
      }
    },
    {
      $group: {
        _id: '$type',
        count: { $sum: 1 },
        photosCount: {
          $sum: {
            $cond: [
              { $isArray: '$photos' },
              { $size: '$photos' },
              0
            ]
          }
        },
        // Compter aussi la photo principale (photoUrl) si elle existe
        hasMainPhoto: {
          $sum: {
            $cond: [
              {
                $and: [
                  { $ne: ['$photoUrl', null] },
                  { $ne: ['$photoUrl', ''] }
                ]
              },
              1,
              0
            ]
          }
        }
      }
    }
  ]);

  // Initialiser les compteurs
  let total = 0;
  const byType = {
    moto: 0,
    voiture: 0
  };
  let photosTotal = 0;

  // Traiter les résultats de l'aggregation
  for (const item of result) {
    const type = item._id;
    const count = item.count;
    const photosCount = item.photosCount || 0;
    const mainPhotoCount = item.hasMainPhoto || 0;

    total += count;
    
    if (type === 'moto' || type === 'voiture') {
      byType[type] = count;
    }

    // Photos de la galerie + photo principale
    photosTotal += photosCount + mainPhotoCount;
  }

  return {
    total,
    byType,
    photosTotal
  };
}

/**
 * Compte les groupes privés créés par un utilisateur
 * @param {string|ObjectId} userId - L'ID de l'utilisateur
 * @returns {Promise<number>} Le nombre de groupes privés créés
 */
async function countPrivateGroupsCreated(userId) {
  if (!userId) {
    throw new Error('userId est requis');
  }

  const count = await Group.countDocuments({
    createur: userId,
    visibilite: 'privee'
  });

  return count;
}

/**
 * Compte les balades privées créées par un utilisateur dans le mois courant
 * @param {string|ObjectId} userId - L'ID de l'utilisateur
 * @param {Date} nowDate - La date de référence (par défaut: maintenant)
 * @returns {Promise<number>} Le nombre de balades privées créées ce mois
 */
async function countPrivateRidesCreatedThisMonth(userId, nowDate = new Date()) {
  if (!userId) {
    throw new Error('userId est requis');
  }

  // Calculer le début du mois courant
  const startOfMonth = new Date(nowDate.getFullYear(), nowDate.getMonth(), 1);
  startOfMonth.setHours(0, 0, 0, 0);

  // Calculer le début du mois suivant
  const startOfNextMonth = new Date(nowDate.getFullYear(), nowDate.getMonth() + 1, 1);
  startOfNextMonth.setHours(0, 0, 0, 0);

  const count = await Ride.countDocuments({
    organisateur: userId,
    visibilite: 'privee',
    createdAt: {
      $gte: startOfMonth,
      $lt: startOfNextMonth
    }
  });

  return count;
}

module.exports = {
  countVehiclesByUser,
  countPrivateGroupsCreated,
  countPrivateRidesCreatedThisMonth,
};
