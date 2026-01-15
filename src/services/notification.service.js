const cron = require('node-cron');
const Ride = require('../models/Ride');
const User = require('../models/User');
const NotificationSent = require('../models/NotificationSent');
const emailService = require('./email.service');
const maintenanceReminderService = require('./maintenanceReminder.service');
const checkInService = require('./checkIn.service');
const reputationService = require('./reputation.service');
const weatherService = require('./weather.service');
const rideNotificationService = require('./ride-notification.service');
const Notification = require('../models/Notification');

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
      .populate('participants.userId', 'firstName lastName email');

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
          ...ride.participants.map(p => p.userId ? p.userId._id || p.userId : null).filter(Boolean),
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

// Vérifier les rappels d'entretien échus
const checkMaintenanceReminders = async () => {
  try {
    const processed = await maintenanceReminderService.checkDueReminders();
    if (processed > 0) {
      console.log(`✅ ${processed} rappels d'entretien traités`);
    }
  } catch (error) {
    console.error('Erreur lors de la vérification des rappels d\'entretien:', error);
  }
};

// Vérifier l'inactivité des utilisateurs
const checkUserInactivity = async () => {
  try {
    const alertsSent = await checkInService.checkInactivity();
    if (alertsSent > 0) {
      console.log(`✅ ${alertsSent} alertes d'inactivité envoyées`);
    }
  } catch (error) {
    console.error('Erreur lors de la vérification d\'inactivité:', error);
  }
};

// Vérifier et envoyer les alertes météo 24h avant
const checkWeatherAlerts = async () => {
  try {
    const apiKey = process.env.WEATHER_API_KEY;
    if (!apiKey || apiKey === 'your-openweather-api-key' || apiKey.trim() === '') {
      // Ne pas logger à chaque exécution du cron, seulement la première fois
      if (!checkWeatherAlerts._warned) {
        console.warn('⚠️  WEATHER_API_KEY non configurée. Alertes météo désactivées.');
        checkWeatherAlerts._warned = true;
      }
      return;
    }

    const now = new Date();
    const hoursBefore = parseInt(process.env.WEATHER_ALERT_HOURS_BEFORE) || 24;
    const targetTime = new Date(now.getTime() + hoursBefore * 60 * 60 * 1000);
    const windowStart = new Date(targetTime.getTime() - 60 * 60 * 1000); // -1h
    const windowEnd = new Date(targetTime.getTime() + 60 * 60 * 1000); // +1h

    // Trouver les balades dans la fenêtre 24h ± 1h
    const rides = await Ride.find({
      status: { $in: ['scheduled', 'postponed'] },
      date: {
        $gte: windowStart,
        $lte: windowEnd
      }
    })
      .populate('organisateur', 'email firstName lastName preferences')
      .populate('participants.userId', 'email firstName lastName subscription preferences');

    let alertsSent = 0;

    for (const ride of rides) {
      try {
        // Construire la date/heure exacte de la balade
        const rideDateTime = new Date(ride.date);
        const [hours, minutes] = ride.heure.split(':').map(Number);
        rideDateTime.setHours(hours, minutes, 0, 0);

        // Vérifier si on est dans la fenêtre 24h ± 1h
        const timeDiff = rideDateTime.getTime() - now.getTime();
        const hoursUntilRide = timeDiff / (1000 * 60 * 60);

        if (hoursUntilRide < hoursBefore - 1 || hoursUntilRide > hoursBefore + 1) {
          continue; // Pas dans la fenêtre
        }

        // Récupérer la météo
        const weather = await weatherService.getRideWeather(ride);

        // Vérifier si conditions défavorables
        const hasBadWeather = weather.alerts && weather.alerts.length > 0;

        if (!hasBadWeather) {
          continue; // Pas de mauvais temps
        }

        // Notifier l'organisateur (toujours)
        const organizer = ride.organisateur;
        if (organizer && organizer.email) {
          // Vérifier si notification déjà envoyée
          const alreadySent = await Notification.findOne({
            userId: organizer._id,
            type: 'weather_alert',
            'relatedEntity.id': ride._id,
            'relatedEntity.type': 'Ride',
            createdAt: {
              $gte: new Date(now.getTime() - 2 * 60 * 60 * 1000) // Dans les 2 dernières heures
            }
          });

          if (!alreadySent) {
            const alertMessages = weather.alerts.map(a => a.message).join('; ');
            await rideNotificationService.sendInAppAndPushNotification(
              organizer._id,
              'weather_alert',
              `Alerte météo : ${ride.titre}`,
              `Conditions météo défavorables prévues pour votre balade "${ride.titre}" le ${ride.date.toLocaleDateString('fr-FR')} à ${ride.heure}. ${alertMessages}`,
              `/rides/${ride._id}`,
              { id: ride._id, type: 'Ride' },
              null
            );

            // Email fallback
            if (organizer.preferences?.notifications?.email !== false) {
              try {
                await emailService.sendWeatherAlertEmail(
                  organizer.email,
                  ride,
                  organizer.firstName || organizer.pseudo || 'Organisateur',
                  weather
                );
              } catch (emailError) {
                console.error(`Erreur envoi email alerte météo à ${organizer.email}:`, emailError);
              }
            }

            alertsSent++;
          }
        }

        // Notifier les participants PREMIUM avec opt-in
        if (ride.participants && Array.isArray(ride.participants)) {
          for (const participant of ride.participants) {
            const user = participant.userId;
            if (!user || !user._id) continue;

            // Vérifier premium + opt-in
            const isPremium = user.subscription?.isPremium === true && 
                              (!user.subscription?.premiumExpiresAt || 
                               new Date(user.subscription.premiumExpiresAt) > now);
            
            if (!isPremium) continue;
            if (user.preferences?.weatherAlertsEnabled !== true) continue;

            // Vérifier si notification déjà envoyée
            const alreadySent = await Notification.findOne({
              userId: user._id,
              type: 'weather_alert',
              'relatedEntity.id': ride._id,
              'relatedEntity.type': 'Ride',
              createdAt: {
                $gte: new Date(now.getTime() - 2 * 60 * 60 * 1000) // Dans les 2 dernières heures
              }
            });

            if (!alreadySent) {
              const alertMessages = weather.alerts.map(a => a.message).join('; ');
              await rideNotificationService.sendInAppAndPushNotification(
                user._id,
                'weather_alert',
                `Alerte météo : ${ride.titre}`,
                `Conditions météo défavorables prévues pour la balade "${ride.titre}" le ${ride.date.toLocaleDateString('fr-FR')} à ${ride.heure}. ${alertMessages}`,
                `/rides/${ride._id}`,
                { id: ride._id, type: 'Ride' },
                null
              );

              // Email fallback
              if (user.preferences?.notifications?.email !== false) {
                try {
                  await emailService.sendWeatherAlertEmail(
                    user.email,
                    ride,
                    user.firstName || user.pseudo || 'Participant',
                    weather
                  );
                } catch (emailError) {
                  console.error(`Erreur envoi email alerte météo à ${user.email}:`, emailError);
                }
              }

              alertsSent++;
            }
          }
        }
      } catch (error) {
        console.error(`Erreur lors de la vérification météo pour la balade ${ride._id}:`, error);
      }
    }

    if (alertsSent > 0) {
      console.log(`✅ ${alertsSent} alertes météo envoyées`);
    }
  } catch (error) {
    console.error('Erreur lors de la vérification des alertes météo:', error);
  }
};

// Mettre à jour les scores de réputation
const updateReputationScores = async () => {
  try {
    const users = await User.find({});
    let updated = 0;

    for (const user of users) {
      try {
        await reputationService.calculateReputationScore(user._id);
        updated++;
      } catch (error) {
        console.error(`Erreur lors de la mise à jour de la réputation pour ${user._id}:`, error);
      }
    }

    if (updated > 0) {
      console.log(`✅ ${updated} scores de réputation mis à jour`);
    }
  } catch (error) {
    console.error('Erreur lors de la mise à jour des scores de réputation:', error);
  }
};

// Démarrer tous les schedulers
const startNotificationScheduler = () => {
  // Notifications de balades (toutes les minutes)
  cron.schedule('* * * * *', () => {
    checkAndSendNotifications();
  });

  // Rappels d'entretien (tous les jours à 9h)
  cron.schedule('0 9 * * *', () => {
    checkMaintenanceReminders();
  });

  // Vérification d'inactivité (toutes les 5 minutes)
  cron.schedule('*/5 * * * *', () => {
    checkUserInactivity();
  });

  // Mise à jour des scores de réputation (tous les jours à 2h)
  cron.schedule('0 2 * * *', () => {
    updateReputationScores();
  });

  // Alertes météo 24h avant (toutes les heures)
  if (process.env.WEATHER_ALERT_ENABLED !== 'false') {
    cron.schedule('0 * * * *', () => {
      checkWeatherAlerts();
    });
    console.log('   - Alertes météo 24h avant: toutes les heures');
  }

  console.log('✅ Schedulers démarrés:');
  console.log('   - Notifications de balades: toutes les minutes');
  console.log('   - Rappels d\'entretien: tous les jours à 9h');
  console.log('   - Vérification d\'inactivité: toutes les 5 minutes');
  console.log('   - Mise à jour réputation: tous les jours à 2h');
  if (process.env.WEATHER_ALERT_ENABLED !== 'false') {
    console.log('   - Alertes météo 24h avant: toutes les heures');
  }
};

module.exports = {
  checkAndSendNotifications,
  checkMaintenanceReminders,
  checkUserInactivity,
  updateReputationScores,
  checkWeatherAlerts,
  startNotificationScheduler
};

