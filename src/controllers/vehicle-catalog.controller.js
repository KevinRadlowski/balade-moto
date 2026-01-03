const fs = require('fs');
const path = require('path');
const { BadRequestError } = require('../utils/errors');

// Charger le dataset depuis le fichier JSON
let vehicleCatalogData = null;

function loadVehicleCatalogData() {
  if (vehicleCatalogData === null) {
    try {
      const dataPath = path.join(__dirname, '../data/vehicle_catalog.seed.json');
      const rawData = fs.readFileSync(dataPath, 'utf8');
      vehicleCatalogData = JSON.parse(rawData);
    } catch (error) {
      console.error('Erreur lors du chargement du catalogue véhicules:', error);
      vehicleCatalogData = { voiture: { makes: [], models: {} }, moto: { makes: [], models: {} } };
    }
  }
  return vehicleCatalogData;
}

/**
 * GET /api/vehicle-catalog/makes
 * Récupère les marques pour un type de véhicule
 * Query params: type (voiture|moto), year (optionnel, ignoré pour l'instant)
 */
exports.getMakes = async (req, res, next) => {
  try {
    const { type, year } = req.query;

    if (!type || !['voiture', 'moto'].includes(type)) {
      return next(new BadRequestError('Le paramètre type est requis et doit être "voiture" ou "moto"'));
    }

    const catalog = loadVehicleCatalogData();
    const makes = catalog[type]?.makes || [];

    res.status(200).json({
      success: true,
      data: {
        items: makes,
        total: makes.length,
        type: type,
        year: year || null,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des marques:', error);
    next(error);
  }
};

/**
 * GET /api/vehicle-catalog/models
 * Récupère les modèles pour une marque et un type
 * Query params: type (voiture|moto), make (ID de la marque), year (optionnel, ignoré pour l'instant)
 */
exports.getModels = async (req, res, next) => {
  try {
    const { type, make, year } = req.query;

    if (!type || !['voiture', 'moto'].includes(type)) {
      return next(new BadRequestError('Le paramètre type est requis et doit être "voiture" ou "moto"'));
    }

    if (!make) {
      return next(new BadRequestError('Le paramètre make (ID de la marque) est requis'));
    }

    const catalog = loadVehicleCatalogData();
    const models = catalog[type]?.models?.[make] || [];

    res.status(200).json({
      success: true,
      data: {
        items: models,
        total: models.length,
        type: type,
        make: make,
        year: year || null,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des modèles:', error);
    next(error);
  }
};

