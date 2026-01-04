const CatalogProposal = require('../models/CatalogProposal');
const CatalogApprovedEntry = require('../models/CatalogApprovedEntry');
const CatalogMeta = require('../models/CatalogMeta');
const { normalizeMake, normalizeModel } = require('../utils/catalog.utils');
const { NotFoundError, BadRequestError, ConflictError } = require('../utils/errors');

/**
 * Met à jour la version du catalogue (pour invalidation de cache)
 */
async function updateCatalogVersion() {
  try {
    await CatalogMeta.findOneAndUpdate(
      { key: 'catalog_version' },
      {
        version: new Date().toISOString(),
        updatedAt: new Date()
      },
      { upsert: true, new: true }
    );
  } catch (error) {
    console.error('[CatalogMeta] Erreur lors de la mise à jour de la version:', error);
    // Ne pas bloquer si la mise à jour de version échoue
  }
}

/**
 * Récupère les propositions avec pagination
 */
async function getProposals(status, page = 1, limit = 50) {
  const skip = (page - 1) * limit;
  
  const query = {};
  if (status) {
    query.status = status;
  }
  
  const proposals = await CatalogProposal.find(query)
    .populate('createdByUserId', 'pseudo email')
    .populate('reviewedByUserId', 'pseudo email')
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit);
  
  const total = await CatalogProposal.countDocuments(query);
  
  return {
    proposals,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit)
    }
  };
}

/**
 * Approuve une proposition
 */
async function approveProposal(proposalId, adminId) {
  const proposal = await CatalogProposal.findById(proposalId);
  
  if (!proposal) {
    throw new NotFoundError('Proposition non trouvée');
  }
  
  if (proposal.status === 'APPROVED') {
    throw new BadRequestError('Cette proposition est déjà approuvée');
  }
  
  if (proposal.status === 'REJECTED') {
    throw new BadRequestError('Cette proposition a été rejetée et ne peut pas être approuvée');
  }
  
  // Normaliser make et model (s'assurer du collapse spaces)
  const normalizedMake = normalizeMake(proposal.make);
  const normalizedModel = normalizeModel(proposal.model);
  
  // Vérifier si l'entrée approuvée existe déjà
  const existingApproved = await CatalogApprovedEntry.findOne({
    type: proposal.type,
    year: proposal.year,
    make: normalizedMake,
    model: normalizedModel
  });
  
  if (existingApproved) {
    // Mettre à jour la proposition même si l'entrée existe déjà
    proposal.status = 'APPROVED';
    proposal.reviewedByUserId = adminId;
    proposal.reviewedAt = new Date();
    await proposal.save();
    
    return {
      proposal,
      entry: existingApproved,
      alreadyExists: true
    };
  }
  
  // Créer l'entrée approuvée avec valeurs normalisées
  const approvedEntry = new CatalogApprovedEntry({
    type: proposal.type,
    year: proposal.year,
    make: normalizedMake,
    model: normalizedModel,
    createdByAdminId: adminId
  });
  
  await approvedEntry.save();
  
  // Mettre à jour la proposition
  proposal.status = 'APPROVED';
  proposal.reviewedByUserId = adminId;
  proposal.reviewedAt = new Date();
  await proposal.save();
  
  // Mettre à jour la version du catalogue pour invalidation de cache
  await updateCatalogVersion();
  
  return {
    proposal,
    entry: approvedEntry,
    alreadyExists: false
  };
}

/**
 * Rejette une proposition
 */
async function rejectProposal(proposalId, adminId, reason) {
  const proposal = await CatalogProposal.findById(proposalId);
  
  if (!proposal) {
    throw new NotFoundError('Proposition non trouvée');
  }
  
  if (proposal.status === 'REJECTED') {
    throw new BadRequestError('Cette proposition est déjà rejetée');
  }
  
  if (proposal.status === 'APPROVED') {
    throw new BadRequestError('Cette proposition a été approuvée et ne peut pas être rejetée');
  }
  
  proposal.status = 'REJECTED';
  proposal.reviewedByUserId = adminId;
  proposal.reviewedAt = new Date();
  proposal.reason = reason || null;
  
  await proposal.save();
  
  // Mettre à jour la version du catalogue (même pour reject, au cas où)
  await updateCatalogVersion();
  
  return proposal;
}

module.exports = {
  getProposals,
  approveProposal,
  rejectProposal
};

