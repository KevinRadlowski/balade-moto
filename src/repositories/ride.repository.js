/**
 * Repository pour l'accès aux données des balades (Rides)
 * Encapsule toutes les requêtes MongoDB
 */

const Ride = require('../models/Ride');

/**
 * Trouve des balades avec filtres et pagination
 * @param {object} filter - Filtres MongoDB
 * @param {object} options - Options { skip, limit, sort, populate }
 * @returns {Promise<Array>} Liste de balades
 */
async function find(filter = {}, options = {}) {
  const {
    skip = 0,
    limit = 20,
    sort = { date: 1 },
    populate = [],
    lean = false
  } = options;

  let query = Ride.find(filter);

  // Populate
  if (populate.length > 0) {
    populate.forEach(pop => {
      if (typeof pop === 'string') {
        query = query.populate(pop);
      } else {
        query = query.populate(pop.path, pop.select);
      }
    });
  }

  // Sort
  if (sort) {
    query = query.sort(sort);
  }

  // Pagination
  query = query.skip(skip).limit(limit);

  // Lean (objets JavaScript simples)
  if (lean) {
    query = query.lean();
  }

  return await query.exec();
}

/**
 * Trouve une balade par ID
 * @param {string} rideId - ID de la balade
 * @param {object} options - Options { populate, lean }
 * @returns {Promise<object|null>} Balade ou null
 */
async function findById(rideId, options = {}) {
  const {
    populate = [],
    lean = false
  } = options;

  let query = Ride.findById(rideId);

  // Populate
  if (populate.length > 0) {
    populate.forEach(pop => {
      if (typeof pop === 'string') {
        query = query.populate(pop);
      } else {
        query = query.populate(pop.path, pop.select);
      }
    });
  }

  // Lean
  if (lean) {
    query = query.lean();
  }

  return await query.exec();
}

/**
 * Compte le nombre de balades correspondant aux filtres
 * @param {object} filter - Filtres MongoDB
 * @returns {Promise<number>} Nombre de balades
 */
async function count(filter = {}) {
  return await Ride.countDocuments(filter);
}

/**
 * Crée une nouvelle balade
 * @param {object} rideData - Données de la balade
 * @param {object} options - Options { populate }
 * @returns {Promise<object>} Balade créée
 */
async function create(rideData, options = {}) {
  const { populate = [] } = options;

  const ride = new Ride(rideData);
  await ride.save();

  // Populate après sauvegarde
  if (populate.length > 0) {
    for (const pop of populate) {
      if (typeof pop === 'string') {
        await ride.populate(pop);
      } else {
        await ride.populate(pop.path, pop.select);
      }
    }
  }

  return ride;
}

/**
 * Met à jour une balade
 * @param {string} rideId - ID de la balade
 * @param {object} updateData - Données à mettre à jour
 * @param {object} options - Options { populate, new }
 * @returns {Promise<object|null>} Balade mise à jour ou null
 */
async function updateById(rideId, updateData, options = {}) {
  const {
    populate = [],
    new: returnNew = true
  } = options;

  const ride = await Ride.findByIdAndUpdate(
    rideId,
    updateData,
    { new: returnNew, runValidators: true }
  );

  if (!ride) {
    return null;
  }

  // Populate après mise à jour
  if (populate.length > 0) {
    for (const pop of populate) {
      if (typeof pop === 'string') {
        await ride.populate(pop);
      } else {
        await ride.populate(pop.path, pop.select);
      }
    }
  }

  return ride;
}

/**
 * Supprime une balade
 * @param {string} rideId - ID de la balade
 * @returns {Promise<object|null>} Balade supprimée ou null
 */
async function deleteById(rideId) {
  return await Ride.findByIdAndDelete(rideId);
}

/**
 * Recherche géospatiale de balades proches
 * @param {number} latitude - Latitude
 * @param {number} longitude - Longitude
 * @param {number} radiusKm - Rayon en km
 * @param {object} filter - Filtres additionnels
 * @param {object} options - Options { limit, populate, lean }
 * @returns {Promise<Array>} Liste de balades avec distance
 */
async function findNearby(latitude, longitude, radiusKm, filter = {}, options = {}) {
  const {
    limit = 50,
    populate = [],
    lean = false
  } = options;

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
      $limit: limit
    }
  ];

  // Ajouter populate via $lookup si nécessaire
  if (populate.length > 0) {
    populate.forEach(pop => {
      const field = typeof pop === 'string' ? pop : pop.path;
      const select = typeof pop === 'object' ? pop.select : null;

      pipeline.push({
        $lookup: {
          from: 'users',
          localField: field,
          foreignField: '_id',
          as: field
        }
      });

      if (select) {
        pipeline.push({
          $project: {
            [field]: {
              $map: {
                input: `$${field}`,
                as: 'user',
                in: {
                  // Projection des champs sélectionnés
                  _id: '$$user._id',
                  ...(select.split(' ').reduce((acc, field) => {
                    if (field.startsWith('-')) return acc;
                    acc[field] = `$$user.${field}`;
                    return acc;
                  }, {}))
                }
              }
            }
          }
        });
      }
    });
  }

  return await Ride.aggregate(pipeline);
}

/**
 * Trouve des balades avec aggregation pipeline
 * @param {Array} pipeline - Pipeline d'aggregation MongoDB
 * @returns {Promise<Array>} Résultats de l'aggregation
 */
async function aggregate(pipeline) {
  return await Ride.aggregate(pipeline);
}

/**
 * Trouve une balade par lien secret
 * @param {string} secretLink - Lien secret
 * @param {object} options - Options { populate, lean }
 * @returns {Promise<object|null>} Balade ou null
 */
async function findBySecretLink(secretLink, options = {}) {
  const {
    populate = [],
    lean = false
  } = options;

  let query = Ride.findOne({ secretLink });

  // Populate
  if (populate.length > 0) {
    populate.forEach(pop => {
      if (typeof pop === 'string') {
        query = query.populate(pop);
      } else {
        query = query.populate(pop.path, pop.select);
      }
    });
  }

  // Lean
  if (lean) {
    query = query.lean();
  }

  return await query.exec();
}

module.exports = {
  find,
  findById,
  count,
  create,
  updateById,
  deleteById,
  findNearby,
  aggregate,
  findBySecretLink
};

