/**
 * Service pour la gestion des annulations, reports et reprogrammations de balades
 */

const rideRepository = require('../repositories/ride.repository');
const { NotFoundError, ForbiddenError, BadRequestError } = require('../utils/errors');
const notificationService = require('./ride-notification.service');

/**
 * Annule une balade
 * @param {string} rideId - ID de la balade
 * @param {object} cancellationData - Données d'annulation
 * @param {object} user - Utilisateur (organisateur)
 * @returns {Promise<object>} La balade annulée
 */
async function cancelRide(rideId, cancellationData, user) {
  const ride = await rideRepository.findById(rideId);

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que l'utilisateur est l'organisateur
  if (ride.organisateur.toString() !== user._id.toString()) {
    throw new ForbiddenError('Seul l\'organisateur peut annuler la balade');
  }

  // Vérifier que la balade n'est pas déjà annulée ou terminée
  if (ride.status === 'cancelled') {
    throw new BadRequestError('Cette balade est déjà annulée');
  }

  if (ride.status === 'completed') {
    throw new BadRequestError('Impossible d\'annuler une balade terminée');
  }

  const { reasonCode, reasonText } = cancellationData;

  if (!reasonCode) {
    throw new BadRequestError('Le code de raison est requis');
  }

  // Valider le code de raison
  const validReasonCodes = ['WEATHER', 'MECHANICAL', 'ROAD_CLOSED', 'LOW_PARTICIPATION', 'OTHER'];
  if (!validReasonCodes.includes(reasonCode)) {
    throw new BadRequestError(`Code de raison invalide. Valeurs acceptées: ${validReasonCodes.join(', ')}`);
  }

  // Mettre à jour la balade
  ride.status = 'cancelled';
  ride.cancellation = {
    cancelledAt: new Date(),
    cancelledBy: user._id,
    cancelReasonCode: reasonCode,
    cancelReasonText: reasonText || null
  };

  await ride.save();

  // Envoyer les notifications aux participants
  await notificationService.notifyRideCancellation(ride, cancellationData);

  // Populate pour retour
  const populatedRide = await rideRepository.findById(rideId, {
    populate: [
      { path: 'organisateur', select: 'firstName lastName pseudo email' },
      { path: 'participants.userId', select: 'firstName lastName pseudo' },
      { path: 'cancellation.cancelledBy', select: 'firstName lastName pseudo' }
    ]
  });

  return populatedRide;
}

/**
 * Reporte une balade (sans créer de nouvelle balade)
 * @param {string} rideId - ID de la balade
 * @param {object} postponementData - Données de report
 * @param {object} user - Utilisateur (organisateur)
 * @returns {Promise<object>} La balade reportée
 */
async function postponeRide(rideId, postponementData, user) {
  const ride = await rideRepository.findById(rideId);

  if (!ride) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que l'utilisateur est l'organisateur
  if (ride.organisateur.toString() !== user._id.toString()) {
    throw new ForbiddenError('Seul l\'organisateur peut reporter la balade');
  }

  // Vérifier que la balade n'est pas annulée ou terminée
  if (ride.status === 'cancelled') {
    throw new BadRequestError('Impossible de reporter une balade annulée');
  }

  if (ride.status === 'completed') {
    throw new BadRequestError('Impossible de reporter une balade terminée');
  }

  // Si la balade est déjà reportée, on permet de modifier la date de report
  const isAlreadyPostponed = ride.status === 'postponed';

  const { reasonCode, reasonText, newDateTime } = postponementData;

  if (!reasonCode) {
    throw new BadRequestError('Le code de raison est requis');
  }

  // Valider le code de raison
  const validReasonCodes = ['WEATHER', 'MECHANICAL', 'ROAD_CLOSED', 'LOW_PARTICIPATION', 'OTHER'];
  if (!validReasonCodes.includes(reasonCode)) {
    throw new BadRequestError(`Code de raison invalide. Valeurs acceptées: ${validReasonCodes.join(', ')}`);
  }

  // Si une nouvelle date/heure est fournie, mettre à jour la date et l'heure de la balade
  if (newDateTime) {
    const newDate = new Date(newDateTime);
    if (newDate < new Date()) {
      throw new BadRequestError('La nouvelle date doit être dans le futur');
    }
    
    // Parser la date ISO string directement pour éviter les problèmes de fuseau horaire
    // Format attendu: "2026-01-19T10:30:00.000" ou "2026-01-19T10:30:00.000Z"
    let year, month, day, hours, minutes;
    
    if (typeof newDateTime === 'string') {
      // Extraire directement depuis la string ISO
      const isoMatch = newDateTime.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/);
      if (isoMatch) {
        year = parseInt(isoMatch[1], 10);
        month = parseInt(isoMatch[2], 10) - 1; // Les mois sont 0-indexés en JavaScript
        day = parseInt(isoMatch[3], 10);
        hours = parseInt(isoMatch[4], 10);
        minutes = parseInt(isoMatch[5], 10);
      } else {
        // Fallback: utiliser les méthodes UTC
        year = newDate.getUTCFullYear();
        month = newDate.getUTCMonth();
        day = newDate.getUTCDate();
        hours = newDate.getUTCHours();
        minutes = newDate.getUTCMinutes();
      }
    } else {
      // Si c'est déjà un objet Date, utiliser UTC
      year = newDate.getUTCFullYear();
      month = newDate.getUTCMonth();
      day = newDate.getUTCDate();
      hours = newDate.getUTCHours();
      minutes = newDate.getUTCMinutes();
    }
    
    // Créer la date sans heure (en UTC pour éviter les problèmes de timezone)
    const newDateOnly = new Date(Date.UTC(year, month, day));
    const newTimeString = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
    
    // Mettre à jour la date et l'heure de la balade
    ride.date = newDateOnly;
    ride.heure = newTimeString;
  } else if (isAlreadyPostponed && ride.postponement && ride.postponement.newDateTime) {
    // Si la balade est déjà reportée et qu'on ne fournit pas de nouvelle date,
    // conserver la date de report existante et mettre à jour la date de la balade
    const existingNewDate = new Date(ride.postponement.newDateTime);
    
    // Utiliser UTC pour éviter les problèmes de fuseau horaire
    const year = existingNewDate.getUTCFullYear();
    const month = existingNewDate.getUTCMonth();
    const day = existingNewDate.getUTCDate();
    const hours = existingNewDate.getUTCHours();
    const minutes = existingNewDate.getUTCMinutes();
    
    const newDateOnly = new Date(Date.UTC(year, month, day));
    const newTimeString = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
    
    ride.date = newDateOnly;
    ride.heure = newTimeString;
  }

  // Mettre à jour la balade (même si déjà reportée, on met à jour les informations)
  ride.status = 'postponed';
  ride.postponement = {
    postponedAt: isAlreadyPostponed && ride.postponement ? ride.postponement.postponedAt : new Date(),
    postponedBy: user._id,
    postponeReasonCode: reasonCode,
    postponeReasonText: reasonText || null,
    newDateTime: newDateTime ? new Date(newDateTime) : (isAlreadyPostponed && ride.postponement ? ride.postponement.newDateTime : null)
  };

  await ride.save();

  // Envoyer les notifications aux participants
  await notificationService.notifyRidePostponement(ride, postponementData);

  // Populate pour retour
  const populatedRide = await rideRepository.findById(rideId, {
    populate: [
      { path: 'organisateur', select: 'firstName lastName pseudo email' },
      { path: 'participants.userId', select: 'firstName lastName pseudo' },
      { path: 'postponement.postponedBy', select: 'firstName lastName pseudo' }
    ]
  });

  return populatedRide;
}

/**
 * Reprogramme une balade (crée une nouvelle balade avec les mêmes données)
 * @param {string} rideId - ID de la balade originale
 * @param {object} rescheduleData - Données de reprogrammation
 * @param {object} user - Utilisateur (organisateur)
 * @returns {Promise<object>} La nouvelle balade créée
 */
async function rescheduleRide(rideId, rescheduleData, user) {
  const originalRide = await rideRepository.findById(rideId);

  if (!originalRide) {
    throw new NotFoundError('Balade');
  }

  // Vérifier que l'utilisateur est l'organisateur
  if (originalRide.organisateur.toString() !== user._id.toString()) {
    throw new ForbiddenError('Seul l\'organisateur peut reprogrammer la balade');
  }

  // Vérifier que la balade n'est pas déjà terminée
  if (originalRide.status === 'completed') {
    throw new BadRequestError('Impossible de reprogrammer une balade terminée');
  }

  const { newDateTime, keepVisibility = true, keepParticipants = false } = rescheduleData;

  if (!newDateTime) {
    throw new BadRequestError('La nouvelle date/heure est requise');
  }

  const newDate = new Date(newDateTime);
  if (newDate < new Date()) {
    throw new BadRequestError('La nouvelle date doit être dans le futur');
  }

  // Extraire la date et l'heure
  const newDateOnly = new Date(newDate.getFullYear(), newDate.getMonth(), newDate.getDate());
  const newTimeString = `${newDate.getHours().toString().padStart(2, '0')}:${newDate.getMinutes().toString().padStart(2, '0')}`;

  // Créer la nouvelle balade en copiant les données de l'originale
  const newRideData = {
    titre: originalRide.titre,
    description: originalRide.description,
    typeVehicule: originalRide.typeVehicule,
    date: newDateOnly,
    heure: newTimeString,
    lieuDepart: originalRide.lieuDepart,
    lieuArrivee: originalRide.lieuArrivee,
    waypoints: originalRide.waypoints ? originalRide.waypoints.map(wp => ({
      type: wp.type,
      address: wp.address,
      coordinates: wp.coordinates,
      order: wp.order,
      waypointType: wp.waypointType || 'normal',
      isMandatoryStop: wp.isMandatoryStop || false,
      note: wp.note || null
    })) : [],
    rayon: originalRide.rayon || 0,
    organisateur: user._id,
    visibilite: keepVisibility ? originalRide.visibilite : 'publique',
    localisation: originalRide.localisation,
    status: 'scheduled',
    ridingStyle: originalRide.ridingStyle,
    originalRideId: originalRide._id,
    // Outils organisateur (copier les paramètres)
    requiresApproval: originalRide.requiresApproval || false,
    maxParticipants: originalRide.maxParticipants,
    enableWaitlist: originalRide.enableWaitlist || false,
    // Participants : seulement l'organisateur par défaut, ou tous si keepParticipants = true
    participants: keepParticipants 
      ? originalRide.participants.filter(p => p.userId && p.userId.toString() === user._id.toString())
      : [{ userId: user._id, vehicleId: null }]
  };

  // Créer la nouvelle balade
  const newRide = await rideRepository.create(newRideData, {
    populate: [
      { path: 'organisateur', select: 'firstName lastName pseudo email' },
      { path: 'participants.userId', select: 'firstName lastName pseudo' }
    ]
  });

  // Mettre à jour la balade originale
  originalRide.status = 'postponed';
  originalRide.reprogrammedToRideId = newRide._id;
  originalRide.postponement = {
    postponedAt: new Date(),
    postponedBy: user._id,
    postponeReasonCode: 'OTHER',
    postponeReasonText: 'Reprogrammée',
    newDateTime: newDate
  };
  await originalRide.save();

  // Envoyer les notifications aux participants
  await notificationService.notifyRideReschedule(originalRide, newRide, rescheduleData);

  return newRide;
}

module.exports = {
  cancelRide,
  postponeRide,
  rescheduleRide
};

