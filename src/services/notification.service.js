const cron = require('node-cron');
const Ride = require('../models/Ride');
const User = require('../models/User');
const NotificationSent = require('../models/NotificationSent');
const emailService = require('./email.service');

// Vérifier et envoyer les notifications pour les balades dans 1 heure
const checkAndSendNotifications = async () => {
  try {
    const now = new Date();
    const oneHourLater = new Date(now.getTime() + 60 * 60 * 1000); // +1 heure
    
    // Trouver les balades qui commencent dans environ 1 heure (fenêtre de 5 minutes)
    const rides = await Ride.find({
      date: {
        $gte: new Date(oneHourLater.getTime() - 5 * 60 * 1000), // -5 minutes
        $lte: new Date(oneHourLater.getTime() + 5 * 60 * 1000)  // +5 minutes
      }
    }).populate('organisateur', 'firstName lastName email')
      .populate('participants', 'firstName lastName email');

    for (const ride of rides) {
      // Vérifier l'heure exacte
      const rideDate = new Date(ride.date);
      const [hours, minutes] = ride.heure.split(':').map(Number);
      rideDate.setHours(hours, minutes, 0, 0);
      
      const timeDiff = rideDate.getTime() - now.getTime();
      const hoursUntilRide = timeDiff / (1000 * 60 * 60);
      
      // Envoyer la notification si la balade est dans 1 heure (±5 minutes)
      if (hoursUntilRide >= 0.9 && hoursUntilRide <= 1.1) {
        // Envoyer à tous les participants
        const allParticipants = [
          ...ride.participants.map(p => p._id),
          ride.organisateur._id
        ];

        for (const participantId of allParticipants) {
          // Vérifier si la notification a déjà été envoyée
          const alreadySent = await NotificationSent.findOne({
            rideId: ride._id,
            userId: participantId
          });

          if (!alreadySent) {
            const participant = await User.findById(participantId);
            
            if (participant && participant.email) {
              try {
                const userName = participant.firstName 
                  ? `${participant.firstName} ${participant.lastName || ''}`.trim()
                  : participant.email;
                
                await emailService.sendRideReminderEmail(
                  participant.email,
                  ride,
                  userName
                );

                // Enregistrer que la notification a été envoyée
                await NotificationSent.create({
                  rideId: ride._id,
                  userId: participantId,
                  sentAt: new Date()
                });

                console.log(`Notification envoyée à ${participant.email} pour la balade ${ride.titre}`);
              } catch (error) {
                console.error(`Erreur lors de l'envoi de la notification à ${participant.email}:`, error);
              }
            }
          }
        }
      }
    }
  } catch (error) {
    console.error('Erreur lors de la vérification des notifications:', error);
  }
};

// Démarrer le scheduler
const startNotificationScheduler = () => {
  // Exécuter toutes les minutes
  cron.schedule('* * * * *', () => {
    checkAndSendNotifications();
  });

  console.log('Scheduler de notifications démarré (vérification toutes les minutes)');
};

module.exports = {
  checkAndSendNotifications,
  startNotificationScheduler
};

