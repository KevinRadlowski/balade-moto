/**
 * Service pour la gestion des signalements de dangers (crowdsourcing)
 */

const DangerReport = require('../models/DangerReport');
const Ride = require('../models/Ride');
const { NotFoundError, ForbiddenError, BadRequestError } = require('../utils/errors');
const mongoose = require('mongoose');

/**
 * Signale un danger sur la route d'une balade
 * @param {string} rideId - ID de la balade
 * @param {object} reportData - Données du signalement
 * @param {object} user - Utilisateur qui signale
 * @returns {Promise<object>} Le signalement créé
 */
async function reportDanger(rideId, reportData, user) {
  const ride = await Ride.findById(rideId);

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que la balade n'est pas passée
  const rideDate = new Date(ride.date);
  if (rideDate < new Date()) {
    throw new BadRequestError('Impossible de signaler un danger sur une balade passée');
  }

  const { location, description } = reportData;

  if (!location || !location.coordinates || location.coordinates.length !== 2) {
    throw new BadRequestError('Coordonnées de localisation invalides');
  }

  if (!description || description.trim().length === 0) {
    throw new BadRequestError('La description du danger est requise');
  }

  // Vérifier le rate limit : max 5 signalements par heure par utilisateur
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const recentReports = await DangerReport.countDocuments({
    rideId: ride._id,
    reportedBy: user._id,
    createdAt: { $gte: oneHourAgo }
  });

  if (recentReports >= 5) {
    throw new BadRequestError('Trop de signalements. Limite de 5 signalements par heure.');
  }

  // Vérifier la duplication : même zone (rayon 100m) dans la dernière heure
  const duplicateReport = await DangerReport.findOne({
    rideId: ride._id,
    reportedBy: user._id,
    location: {
      $near: {
        $geometry: {
          type: 'Point',
          coordinates: location.coordinates
        },
        $maxDistance: 100 // 100 mètres
      }
    },
    createdAt: { $gte: oneHourAgo }
  });

  if (duplicateReport) {
    throw new BadRequestError('Un signalement similaire a déjà été effectué dans cette zone récemment');
  }

  // Créer le signalement
  const report = new DangerReport({
    rideId: ride._id,
    reportedBy: user._id,
    location: {
      type: 'Point',
      coordinates: location.coordinates
    },
    description: description.trim(),
    status: 'pending'
  });

  await report.save();

  // Populate pour la réponse
  await report.populate('reportedBy', 'firstName lastName pseudo');

  return report;
}

/**
 * Approuve un signalement de danger (organisateur uniquement)
 * @param {string} reportId - ID du signalement
 * @param {object} user - Utilisateur (organisateur)
 * @returns {Promise<object>} Le signalement approuvé
 */
async function approveDangerReport(reportId, user) {
  const report = await DangerReport.findById(reportId).populate('rideId');

  if (!report) {
    throw new NotFoundError('Signalement');
  }

  const ride = report.rideId;
  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que l'utilisateur est l'organisateur
  if (ride.organisateur.toString() !== user._id.toString()) {
    throw new ForbiddenError('Seul l\'organisateur peut approuver un signalement');
  }

  if (report.status !== 'pending') {
    throw new BadRequestError('Ce signalement a déjà été traité');
  }

  report.status = 'approved';
  report.approvedBy = user._id;
  report.approvedAt = new Date();

  await report.save();

  await report.populate('reportedBy', 'firstName lastName pseudo');
  await report.populate('approvedBy', 'firstName lastName pseudo');

  return report;
}

/**
 * Rejette un signalement de danger (organisateur uniquement)
 * @param {string} reportId - ID du signalement
 * @param {object} user - Utilisateur (organisateur)
 * @returns {Promise<object>} Le signalement rejeté
 */
async function rejectDangerReport(reportId, user) {
  const report = await DangerReport.findById(reportId).populate('rideId');

  if (!report) {
    throw new NotFoundError('Signalement');
  }

  const ride = report.rideId;
  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que l'utilisateur est l'organisateur
  if (ride.organisateur.toString() !== user._id.toString()) {
    throw new ForbiddenError('Seul l\'organisateur peut rejeter un signalement');
  }

  if (report.status !== 'pending') {
    throw new BadRequestError('Ce signalement a déjà été traité');
  }

  report.status = 'rejected';
  report.approvedBy = user._id;
  report.approvedAt = new Date();

  await report.save();

  return report;
}

/**
 * Promouvoit un signalement en waypoint DANGER (organisateur uniquement)
 * @param {string} reportId - ID du signalement
 * @param {object} user - Utilisateur (organisateur)
 * @returns {Promise<object>} La balade avec le nouveau waypoint
 */
async function promoteDangerReportToWaypoint(reportId, user) {
  const report = await DangerReport.findById(reportId).populate('rideId');

  if (!report) {
    throw new NotFoundError('Signalement');
  }

  const ride = report.rideId;
  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que l'utilisateur est l'organisateur
  if (ride.organisateur.toString() !== user._id.toString()) {
    throw new ForbiddenError('Seul l\'organisateur peut promouvoir un signalement en waypoint');
  }

  if (report.status !== 'approved') {
    throw new BadRequestError('Le signalement doit être approuvé avant d\'être promu en waypoint');
  }

  // Créer un waypoint DANGER
  const newWaypoint = {
    type: 'checkpoint',
    waypointType: 'danger',
    address: report.description.substring(0, 100), // Utiliser la description comme adresse
    coordinates: {
      type: 'Point',
      coordinates: report.location.coordinates
    },
    order: ride.waypoints.length, // Ajouter à la fin
    isMandatoryStop: false,
    note: report.description,
    createdBy: user._id,
    createdAt: new Date()
  };

  ride.waypoints.push(newWaypoint);
  await ride.save();

  // Mettre à jour le signalement
  report.status = 'promoted';
  report.promotedToWaypointId = ride.waypoints[ride.waypoints.length - 1]._id;
  await report.save();

  const populatedRide = await Ride.findById(ride._id).populate('organisateur', 'firstName lastName pseudo email');

  return populatedRide;
}

/**
 * Liste les signalements d'une balade
 * @param {string} rideId - ID de la balade
 * @param {object} user - Utilisateur (organisateur ou participant)
 * @returns {Promise<Array>} Liste des signalements
 */
async function getDangerReports(rideId, user) {
  const ride = await Ride.findById(rideId);

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier l'accès : organisateur ou participant
  const isOrganizer = ride.organisateur.toString() === user._id.toString();
  const isParticipant = ride.participants.some(
    p => p.userId && p.userId.toString() === user._id.toString()
  );

  if (!isOrganizer && !isParticipant) {
    throw new ForbiddenError('Vous n\'avez pas accès aux signalements de cette balade');
  }

  const reports = await DangerReport.find({ rideId: ride._id })
    .populate('reportedBy', 'firstName lastName pseudo')
    .populate('approvedBy', 'firstName lastName pseudo')
    .sort({ createdAt: -1 });

  return reports;
}

module.exports = {
  reportDanger,
  approveDangerReport,
  rejectDangerReport,
  promoteDangerReportToWaypoint,
  getDangerReports
};

