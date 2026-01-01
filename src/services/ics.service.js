const ics = require('ics');
const Ride = require('../models/Ride');

// Générer un fichier ICS pour une balade
exports.generateICS = async (rideId) => {
  try {
    const ride = await Ride.findById(rideId)
      .populate('organisateur', 'firstName lastName email');

    if (!ride) {
      throw new Error('Balade non trouvée');
    }

    // Parser la date et l'heure
    const rideDate = new Date(ride.date);
    const [hours, minutes] = ride.heure.split(':').map(Number);
    rideDate.setHours(hours, minutes, 0, 0);

    // Date de fin (1h après le début par défaut)
    const endDate = new Date(rideDate);
    endDate.setHours(endDate.getHours() + 1);

    // Formater les dates pour ICS (format: [YYYY, M, D, H, m])
    const start = [
      rideDate.getFullYear(),
      rideDate.getMonth() + 1,
      rideDate.getDate(),
      rideDate.getHours(),
      rideDate.getMinutes()
    ];

    const end = [
      endDate.getFullYear(),
      endDate.getMonth() + 1,
      endDate.getDate(),
      endDate.getHours(),
      endDate.getMinutes()
    ];

    // Créer l'événement ICS
    const event = {
      start: start,
      end: end,
      title: ride.titre,
      description: ride.description || '',
      location: typeof ride.lieuDepart === 'string' 
        ? `${ride.lieuDepart} → ${ride.lieuArrivee}`
        : `${JSON.stringify(ride.lieuDepart)} → ${JSON.stringify(ride.lieuArrivee)}`,
      url: `${process.env.FRONTEND_URL || 'http://localhost:3000'}/rides/${rideId}`,
      status: 'CONFIRMED',
      busyStatus: 'BUSY',
      organizer: {
        name: ride.organisateur.firstName && ride.organisateur.lastName
          ? `${ride.organisateur.firstName} ${ride.organisateur.lastName}`
          : ride.organisateur.email,
        email: ride.organisateur.email
      },
      categories: [ride.typeVehicule === 'moto' ? 'Moto' : 'Voiture'],
      alarms: [
        {
          action: 'DISPLAY',
          description: 'Rappel: Balade dans 1 heure',
          trigger: { hours: 1, minutes: 0, before: true }
        }
      ]
    };

    // Générer le fichier ICS
    const { error, value } = ics.createEvent(event);

    if (error) {
      throw new Error(`Erreur lors de la génération du fichier ICS: ${error.message}`);
    }

    return value;
  } catch (error) {
    throw error;
  }
};

// Générer un fichier ICS pour plusieurs balades
exports.generateMultipleICS = async (rideIds) => {
  try {
    const rides = await Ride.find({ _id: { $in: rideIds } })
      .populate('organisateur', 'firstName lastName email');

    const events = rides.map(ride => {
      const rideDate = new Date(ride.date);
      const [hours, minutes] = ride.heure.split(':').map(Number);
      rideDate.setHours(hours, minutes, 0, 0);

      const endDate = new Date(rideDate);
      endDate.setHours(endDate.getHours() + 1);

      return {
        start: [
          rideDate.getFullYear(),
          rideDate.getMonth() + 1,
          rideDate.getDate(),
          rideDate.getHours(),
          rideDate.getMinutes()
        ],
        end: [
          endDate.getFullYear(),
          endDate.getMonth() + 1,
          endDate.getDate(),
          endDate.getHours(),
          endDate.getMinutes()
        ],
        title: ride.titre,
        description: ride.description || '',
        location: typeof ride.lieuDepart === 'string' 
          ? `${ride.lieuDepart} → ${ride.lieuArrivee}`
          : `${JSON.stringify(ride.lieuDepart)} → ${JSON.stringify(ride.lieuArrivee)}`,
        url: `${process.env.FRONTEND_URL || 'http://localhost:3000'}/rides/${ride._id}`,
        status: 'CONFIRMED',
        busyStatus: 'BUSY',
        organizer: {
          name: ride.organisateur.firstName && ride.organisateur.lastName
            ? `${ride.organisateur.firstName} ${ride.organisateur.lastName}`
            : ride.organisateur.email,
          email: ride.organisateur.email
        },
        categories: [ride.typeVehicule === 'moto' ? 'Moto' : 'Voiture']
      };
    });

    const { error, value } = ics.createEvents(events);

    if (error) {
      throw new Error(`Erreur lors de la génération du fichier ICS: ${error.message}`);
    }

    return value;
  } catch (error) {
    throw error;
  }
};



