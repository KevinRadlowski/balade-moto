const CatalogProposal = require('../models/CatalogProposal');
const CatalogApprovedEntry = require('../models/CatalogApprovedEntry');
const { normalizeMake, normalizeModel, validateYear, validateMake, validateModel } = require('../utils/catalog.utils');
const { BadRequestError, ConflictError, NotFoundError } = require('../utils/errors');

/**
 * Crée une proposition de catalogue
 */
async function createProposal(type, year, make, model, userId) {
  // Normaliser
  const normalizedMake = normalizeMake(make);
  const normalizedModel = normalizeModel(model);
  
  // Valider
  if (!validateYear(year)) {
    throw new BadRequestError('Année invalide. Doit être entre 1900 et ' + (new Date().getFullYear() + 1));
  }
  
  if (!validateMake(normalizedMake)) {
    throw new BadRequestError('Marque invalide. Doit contenir entre 2 et 40 caractères (A-Z, 0-9, espaces, tirets, apostrophes, points, slashes, parenthèses, plus)');
  }
  
  if (!validateModel(normalizedModel)) {
    throw new BadRequestError('Modèle invalide. Doit contenir entre 1 et 80 caractères (A-Z, 0-9, espaces, tirets, apostrophes, points, slashes, parenthèses, plus)');
  }
  
  // Vérifier si déjà approuvé
  const existingApproved = await CatalogApprovedEntry.findOne({
    type,
    year,
    make: normalizedMake,
    model: normalizedModel
  });
  
  if (existingApproved) {
    return {
      status: 'ALREADY_APPROVED',
      id: existingApproved._id
    };
  }
  
  // Vérifier si déjà en attente
  const existingPending = await CatalogProposal.findOne({
    type,
    year,
    make: normalizedMake,
    model: normalizedModel,
    status: 'PENDING'
  });
  
  if (existingPending) {
    return {
      status: 'ALREADY_PENDING',
      id: existingPending._id
    };
  }
  
  // Créer la proposition
  const proposal = new CatalogProposal({
    type,
    year,
    make: normalizedMake,
    model: normalizedModel,
    status: 'PENDING',
    createdByUserId: userId
  });
  
  await proposal.save();
  
  return {
    status: 'PENDING',
    id: proposal._id
  };
}

/**
 * Récupère les entrées approuvées pour un type et une année
 */
async function getApprovedEntries(type, year) {
  const entries = await CatalogApprovedEntry.find({
    type,
    year
  }).sort({ make: 1, model: 1 });
  
  return entries;
}

/**
 * Récupère toutes les marques approuvées pour un type (toutes années confondues)
 * Utilisé pour fetchMakes où les marques doivent être disponibles pour toutes les années
 */
async function getApprovedMakes(type) {
  const makes = await CatalogApprovedEntry.distinct('make', { type }).then(makes => {
    return makes.sort();
  });
  
  return makes;
}

module.exports = {
  createProposal,
  getApprovedEntries,
  getApprovedMakes
};

