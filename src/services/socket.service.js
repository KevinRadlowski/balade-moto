const { Server } = require('socket.io');
const Message = require('../models/Message');
const Ride = require('../models/Ride');
const Group = require('../models/Group');
const User = require('../models/User');

// Initialiser Socket.io
const initializeSocket = (server) => {
  const { getAllowedOrigins } = require('../config/cors');
  const allowedOrigins = getAllowedOrigins();

  const io = new Server(server, {
    cors: {
      origin: (origin, callback) => {
        const isDevelopment = process.env.NODE_ENV === 'development' || !process.env.NODE_ENV;
        
        // Autoriser les requêtes sans origin (mobile apps natifs, Postman, curl, etc.)
        if (!origin) {
          if (isDevelopment) {
            console.log('✅ Socket.io CORS: Requête sans origin autorisée (app native/Postman)');
          }
          return callback(null, true);
        }
        
        // En développement, autoriser tous les ports localhost (pour Flutter Web qui change de port)
        if (isDevelopment) {
          // Autoriser localhost avec n'importe quel port
          if (origin.startsWith('http://localhost:') || 
              origin.startsWith('http://127.0.0.1:') ||
              origin.startsWith('http://192.168.')) {
            return callback(null, true);
          }
        }
        
        // Si allowedOrigins est null, autoriser toutes les origines (CORS_ORIGINS="*")
        if (allowedOrigins === null) {
          if (isDevelopment) {
            console.log(`✅ Socket.io CORS: Origin autorisée (mode "*"): ${origin}`);
          }
          return callback(null, true);
        }
        
        // Production sans config : refuser toutes les origines
        if (allowedOrigins && allowedOrigins.length === 0) {
          const errorMsg = `Socket.io CORS: Origin ${origin} is not allowed. Aucune origine configurée en production.`;
          if (process.env.DEBUG_CORS === 'true') {
            console.error(`🚫 ${errorMsg}`);
            console.error(`   Configurez CORS_ORIGINS ou FRONTEND_URL dans votre .env`);
          }
          return callback(new Error(errorMsg));
        }
        
        // Vérifier si l'origine est dans la liste autorisée
        if (allowedOrigins && allowedOrigins.includes(origin)) {
          if (isDevelopment) {
            console.log(`✅ Socket.io CORS: Origin dans whitelist: ${origin}`);
          }
          callback(null, true);
        } else {
          // Origine non autorisée
          const errorMsg = `Socket.io CORS: Origin ${origin} is not allowed`;
          if (isDevelopment || process.env.DEBUG_CORS === 'true') {
            console.warn(`⚠️  ${errorMsg}`);
            console.warn(`   Origines autorisées:`, allowedOrigins || 'Toutes (*)');
          }
          callback(new Error(errorMsg));
        }
      },
      methods: ["GET", "POST"],
      credentials: true
    }
  });

  // Middleware d'authentification
  const socketAuth = require('../middlewares/socket.auth.middleware');
  io.use(socketAuth);

  io.on('connection', (socket) => {
    console.log(`Utilisateur connecté: ${socket.user.email} (${socket.userId})`);

    // Rejoindre une room de balade
    socket.on('join-ride-room', async (rideId) => {
      try {
        // Vérifier que la balade existe
        const ride = await Ride.findById(rideId);
        if (!ride) {
          return socket.emit('error', { message: 'Balade non trouvée' });
        }

        // Vérifier que l'utilisateur est participant ou organisateur
        const isParticipant = ride.participants.some(
          p => p.userId && p.userId.toString() === socket.userId
        );
        const isOrganizer = ride.organisateur.toString() === socket.userId;

        if (!isParticipant && !isOrganizer) {
          return socket.emit('error', { message: 'Vous n\'êtes pas autorisé à accéder à cette discussion' });
        }

        const roomName = `ride-${rideId}`;
        socket.join(roomName);
        socket.emit('joined-room', { room: roomName, type: 'ride', rideId });

        // Envoyer les derniers messages
        const messages = await Message.find({ 
          idBalade: rideId,
          $or: [
            { deletedForAll: false },
            { deletedForUserIds: { $ne: socket.userId } }
          ]
        })
          .populate('auteur', 'pseudo email avatarUrl')
          .populate('replyToMessageId', 'contenu auteur')
          .sort({ date: -1 })
          .limit(50)
          .lean();
        
        // Construire les URLs complètes des avatars
        const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
        messages.forEach(msg => {
          if (msg.auteur && msg.auteur.avatarUrl && !msg.auteur.avatarUrl.startsWith('http')) {
            msg.auteur.avatarUrl = `${baseUrl}${msg.auteur.avatarUrl}`;
          }
        });

        socket.emit('previous-messages', { messages: messages.reverse() });
      } catch (error) {
        socket.emit('error', { message: 'Erreur lors de la connexion à la room' });
      }
    });

    // Quitter une room de balade
    socket.on('leave-ride-room', (rideId) => {
      const roomName = `ride-${rideId}`;
      socket.leave(roomName);
      socket.emit('left-room', { room: roomName });
    });

    // Rejoindre une room de groupe
    socket.on('join-group-room', async (groupId) => {
      try {
        // Vérifier que le groupe existe
        const group = await Group.findById(groupId);
        if (!group) {
          return socket.emit('error', { message: 'Groupe non trouvé' });
        }

        // Vérifier que l'utilisateur est membre
        if (!group.isMember(socket.userId)) {
          // Si le groupe est public, permettre l'accès en lecture seule
          if (group.visibilite === 'publique') {
            const roomName = `group-${groupId}`;
            socket.join(roomName);
            socket.emit('joined-room', { room: roomName, type: 'group', groupId, readOnly: true });
            
            const messages = await Message.find({ idGroupe: groupId })
              .populate('auteur', 'firstName lastName pseudo email avatarUrl')
              .populate('replyToMessageId', 'contenu auteur deletedForAll type')
              .sort({ date: -1 })
              .limit(50)
              .lean();
            
            // Construire les URLs complètes des avatars et les replyPreview
            const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
            for (const msg of messages) {
              if (msg.auteur && msg.auteur.avatarUrl && !msg.auteur.avatarUrl.startsWith('http')) {
                msg.auteur.avatarUrl = `${baseUrl}${msg.auteur.avatarUrl}`;
              }
              
              // Construire replyPreview si replyToMessageId existe
              if (msg.replyToMessageId && !msg.replyPreview) {
                const replyToMsg = msg.replyToMessageId;
                if (replyToMsg && replyToMsg.auteur) {
                  msg.replyPreview = {
                    senderPseudo: replyToMsg.auteur.pseudo || replyToMsg.auteur.email || 'Utilisateur',
                    content: replyToMsg.deletedForAll 
                      ? 'Message supprimé' 
                      : (replyToMsg.contenu && replyToMsg.contenu.length > 50
                          ? replyToMsg.contenu.substring(0, 50) + '...'
                          : (replyToMsg.contenu || '')),
                    type: replyToMsg.type || 'text'
                  };
                }
              }
            }

            socket.emit('previous-messages', { messages: messages.reverse() });
            return;
          }
          return socket.emit('error', { message: 'Vous n\'êtes pas membre de ce groupe' });
        }

        const roomName = `group-${groupId}`;
        socket.join(roomName);
        socket.emit('joined-room', { room: roomName, type: 'group', groupId });

        // Envoyer les derniers messages
        const messages = await Message.find({ idGroupe: groupId })
          .populate('auteur', 'firstName lastName pseudo email avatarUrl')
          .populate('replyToMessageId', 'contenu auteur deletedForAll type')
          .sort({ date: -1 })
          .limit(50)
          .lean();
        
        // Construire les URLs complètes des avatars et les replyPreview
        const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
        for (const msg of messages) {
          if (msg.auteur && msg.auteur.avatarUrl && !msg.auteur.avatarUrl.startsWith('http')) {
            msg.auteur.avatarUrl = `${baseUrl}${msg.auteur.avatarUrl}`;
          }
          
          // Construire replyPreview si replyToMessageId existe et replyPreview n'existe pas
          if (msg.replyToMessageId && !msg.replyPreview) {
            const replyToMsg = msg.replyToMessageId;
            if (replyToMsg && replyToMsg.auteur) {
              msg.replyPreview = {
                senderPseudo: replyToMsg.auteur.pseudo || replyToMsg.auteur.email || 'Utilisateur',
                content: replyToMsg.deletedForAll 
                  ? 'Message supprimé' 
                  : (replyToMsg.contenu && replyToMsg.contenu.length > 50
                      ? replyToMsg.contenu.substring(0, 50) + '...'
                      : (replyToMsg.contenu || '')),
                type: replyToMsg.type || 'text'
              };
            }
          }
        }

        socket.emit('previous-messages', { messages: messages.reverse() });
      } catch (error) {
        socket.emit('error', { message: 'Erreur lors de la connexion à la room' });
      }
    });

    // Quitter une room de groupe
    socket.on('leave-group-room', (groupId) => {
      const roomName = `group-${groupId}`;
      socket.leave(roomName);
      socket.emit('left-room', { room: roomName });
    });

    // Envoyer un message dans une balade
    socket.on('send-ride-message', async (data) => {
      try {
        const { rideId, contenu } = data;

        if (!contenu || contenu.trim().length === 0) {
          return socket.emit('error', { message: 'Le message ne peut pas être vide' });
        }

        // Vérifier que la balade existe
        const ride = await Ride.findById(rideId);
        if (!ride) {
          return socket.emit('error', { message: 'Balade non trouvée' });
        }

        // Vérifier que l'utilisateur est participant ou organisateur
        const isParticipant = ride.participants.some(
          p => p.userId && p.userId.toString() === socket.userId
        );
        const isOrganizer = ride.organisateur.toString() === socket.userId;

        if (!isParticipant && !isOrganizer) {
          return socket.emit('error', { message: 'Vous n\'êtes pas autorisé à envoyer des messages' });
        }

        // Créer le message
        const message = new Message({
          auteur: socket.userId,
          contenu: contenu.trim(),
          idBalade: rideId,
          date: new Date()
        });

        await message.save();
        await message.populate('auteur', 'firstName lastName pseudo email avatarUrl');
        
        // Construire l'URL complète de l'avatar si nécessaire
        if (message.auteur && message.auteur.avatarUrl && !message.auteur.avatarUrl.startsWith('http')) {
          const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
          message.auteur.avatarUrl = `${baseUrl}${message.auteur.avatarUrl}`;
        }

        // Convertir le message en objet JSON pour l'envoi (avec l'auteur peuplé)
        const messageObj = message.toObject ? message.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(message));

        // Nettoyer pollData s'il est vide ou invalide
        if (messageObj.pollData) {
          const pollData = messageObj.pollData;
          const hasQuestion = pollData.question && pollData.question.trim().length > 0;
          const hasOptions = pollData.options && Array.isArray(pollData.options) && pollData.options.length > 0;
          if (!hasQuestion || !hasOptions) {
            delete messageObj.pollData;
          }
        }
        
        // Envoyer le message à tous les utilisateurs de la room
        const roomName = `ride-${rideId}`;
        io.to(roomName).emit('new-message', { message: messageObj });

        socket.emit('message-sent', { messageId: message._id });
      } catch (error) {
        socket.emit('error', { message: 'Erreur lors de l\'envoi du message' });
      }
    });

    // Envoyer un message dans un groupe
    socket.on('send-group-message', async (data) => {
      try {
        console.log('📨 Données reçues pour send-group-message:', JSON.stringify(data, null, 2));
        const { groupId, contenu, replyToMessageId, parentMessageId, type = 'text' } = data;

        if (!groupId) {
          console.error('❌ groupId manquant');
          return socket.emit('error', { message: 'ID du groupe manquant' });
        }

        if (!contenu || contenu.trim().length === 0) {
          return socket.emit('error', { message: 'Le message ne peut pas être vide' });
        }

        // Vérifier que le groupe existe
        const group = await Group.findById(groupId);
        if (!group) {
          return socket.emit('error', { message: 'Groupe non trouvé' });
        }

        // Vérifier que l'utilisateur est membre
        if (!group.isMember(socket.userId)) {
          return socket.emit('error', { message: 'Vous n\'êtes pas membre de ce groupe' });
        }

        // Vérifier si l'utilisateur est muté dans ce groupe
        const GroupMute = require('../models/GroupMute');
        const activeMute = await GroupMute.findOne({
          groupId: groupId,
          userId: socket.userId,
          mutedUntil: { $gt: new Date() }
        });

        if (activeMute) {
          return socket.emit('error', { 
            message: `Vous êtes muet dans ce groupe jusqu'au ${new Date(activeMute.mutedUntil).toLocaleString('fr-FR')}`,
            code: 'MUTED'
          });
        }

        // Préparer replyPreview si replyToMessageId existe
        let replyPreview = null;
        if (replyToMessageId) {
          try {
            const replyToMessage = await Message.findById(replyToMessageId)
              .populate('auteur', 'pseudo');
            if (replyToMessage) {
              replyPreview = {
                senderPseudo: replyToMessage.auteur?.pseudo || replyToMessage.auteur?.email || 'Utilisateur',
                content: replyToMessage.deletedForAll 
                  ? 'Message supprimé' 
                  : (replyToMessage.contenu && replyToMessage.contenu.length > 50
                      ? replyToMessage.contenu.substring(0, 50) + '...'
                      : (replyToMessage.contenu || '')),
                type: replyToMessage.type || 'text'
              };
            }
          } catch (err) {
            console.error('Erreur lors de la récupération du message de réponse:', err);
            // Continuer sans replyPreview si le message n'existe pas
          }
        }

        // Parser et résoudre les mentions
        let mentions = [];
        if (contenu && typeof contenu === 'string' && contenu.trim().length > 0) {
          try {
            const mentionService = require('../services/mention.service');
            const Notification = require('../models/Notification');
            const User = require('../models/User');
            
            const resolvedMentions = await mentionService.parseAndResolveMentions(contenu, groupId);
            mentions = resolvedMentions.map(m => m.userId);

            // Créer des notifications pour les utilisateurs mentionnés (en arrière-plan)
            if (resolvedMentions.length > 0) {
              const user = await User.findById(socket.userId).select('pseudo email').lean();
              const group = await Group.findById(groupId).select('nom').lean();
              
              for (const mention of resolvedMentions) {
                // Ne pas notifier si l'utilisateur s'est mentionné lui-même
                if (mention.userId.toString() === socket.userId.toString()) {
                  continue;
                }

                await Notification.create({
                  user: mention.userId,
                  type: 'mention',
                  title: `${user?.pseudo || 'Quelqu\'un'} vous a mentionné${group?.nom ? ` dans ${group.nom}` : ''}`,
                  message: contenu.length > 100 ? contenu.substring(0, 100) + '...' : contenu,
                  metadata: {
                    groupId: groupId,
                    mentionedBy: socket.userId,
                    mentionedByPseudo: user?.pseudo || user?.email
                  }
                });
              }
            }
          } catch (mentionError) {
            console.error('Erreur lors du parsing des mentions:', mentionError);
            // Continuer sans mentions si le parsing échoue
          }
        }

        // Gérer les threads : si parentMessageId est fourni, c'est une réponse dans un thread
        let threadRootId = null;
        if (parentMessageId) {
          // Trouver le message parent pour déterminer le threadRootId
          const parentMessage = await Message.findById(parentMessageId);
          if (parentMessage) {
            // Si le parent a déjà un threadRootId, l'utiliser, sinon le parent est la racine
            threadRootId = parentMessage.threadRootId || parentMessage._id;
          }
        }

        // Créer le message
        const messageData = {
          auteur: socket.userId,
          contenu: contenu.trim(),
          type: type,
          idGroupe: groupId,
          parentMessageId: parentMessageId || null, // Pour les threads
          threadRootId: threadRootId, // ID du message racine du fil
          mentions: mentions // Ajouter les mentions résolues
        };

        // Ajouter replyToMessageId seulement s'il existe
        if (replyToMessageId) {
          messageData.replyToMessageId = replyToMessageId;
          console.log('📎 ReplyToMessageId:', replyToMessageId);
        }

        // Ajouter replyPreview seulement s'il existe
        if (replyPreview) {
          messageData.replyPreview = replyPreview;
          console.log('📎 ReplyPreview:', replyPreview);
        }

        console.log('💾 Données du message à créer:', JSON.stringify(messageData, null, 2));

        const message = new Message(messageData);

        // Valider avant de sauvegarder
        try {
          const validationError = message.validateSync();
          if (validationError) {
            console.error('❌ Erreur de validation:', validationError);
            return socket.emit('error', { 
              message: 'Erreur de validation: ' + Object.values(validationError.errors).map(e => e.message).join(', ')
            });
          }
        } catch (validationErr) {
          console.error('❌ Erreur lors de la validation:', validationErr);
          return socket.emit('error', { 
            message: 'Erreur de validation: ' + validationErr.message
          });
        }

        console.log('💾 Sauvegarde du message...');
        await message.save();
        console.log('✅ Message sauvegardé avec succès, ID:', message._id);

        // Si c'est une réponse dans un thread, incrémenter le compteur du message racine
        if (parentMessageId && threadRootId) {
          try {
            await Message.updateOne(
              { _id: threadRootId },
              { $inc: { threadReplyCount: 1 } }
            );
          } catch (countError) {
            console.error('Erreur lors de la mise à jour du compteur de thread:', countError);
            // Ne pas bloquer si le compteur échoue
          }
        }
        await message.populate('auteur', 'pseudo email avatarUrl');
        if (message.replyToMessageId) {
          await message.populate('replyToMessageId', 'contenu auteur');
        }

        // Construire l'URL complète de l'avatar si nécessaire
        if (message.auteur && message.auteur.avatarUrl && !message.auteur.avatarUrl.startsWith('http')) {
          const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
          message.auteur.avatarUrl = `${baseUrl}${message.auteur.avatarUrl}`;
        }

        // Convertir le message en objet JSON pour l'envoi (avec l'auteur peuplé)
        const messageObj = message.toObject ? message.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(message));

        // Nettoyer pollData s'il est vide ou invalide
        if (messageObj.pollData) {
          const pollData = messageObj.pollData;
          const hasQuestion = pollData.question && pollData.question.trim().length > 0;
          const hasOptions = pollData.options && Array.isArray(pollData.options) && pollData.options.length > 0;
          if (!hasQuestion || !hasOptions) {
            delete messageObj.pollData;
          }
        }

        // Envoyer le message à tous les utilisateurs de la room
        const roomName = `group-${groupId}`;
        io.to(roomName).emit('new-message', { message: messageObj });

        socket.emit('message-sent', { messageId: message._id });
      } catch (error) {
        console.error('Erreur lors de l\'envoi du message:', error);
        console.error('Stack:', error.stack);
        socket.emit('error', { 
          message: 'Erreur lors de l\'envoi du message: ' + (error.message || error.toString())
        });
      }
    });

    // Modifier un message
    socket.on('edit-message', async (data) => {
      try {
        const { messageId, content } = data;

        const message = await Message.findById(messageId);
        if (!message) {
          return socket.emit('error', { message: 'Message non trouvé' });
        }

        if (message.auteur.toString() !== socket.userId) {
          return socket.emit('error', { message: 'Vous ne pouvez modifier que vos propres messages' });
        }

        if (message.deletedForAll) {
          return socket.emit('error', { message: 'Impossible de modifier un message supprimé' });
        }

        message.contenu = content.trim();
        message.edited = true;
        await message.save();
        await message.populate('auteur', 'pseudo email avatarUrl');
        if (message.replyToMessageId) {
          await message.populate('replyToMessageId', 'contenu auteur');
        }

        // Construire l'URL complète de l'avatar si nécessaire
        if (message.auteur && message.auteur.avatarUrl && !message.auteur.avatarUrl.startsWith('http')) {
          const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
          message.auteur.avatarUrl = `${baseUrl}${message.auteur.avatarUrl}`;
        }

        // Convertir le message en objet JSON pour l'envoi
        const messageObj = message.toObject ? message.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(message));

        // Nettoyer pollData s'il est vide ou invalide
        if (messageObj.pollData) {
          const pollData = messageObj.pollData;
          const hasQuestion = pollData.question && pollData.question.trim().length > 0;
          const hasOptions = pollData.options && Array.isArray(pollData.options) && pollData.options.length > 0;
          if (!hasQuestion || !hasOptions) {
            delete messageObj.pollData;
          }
        }

        // Déterminer la room
        const roomName = message.idGroupe ? `group-${message.idGroupe}` : `ride-${message.idBalade}`;
        io.to(roomName).emit('message-updated', { message: messageObj });
      } catch (error) {
        socket.emit('error', { message: 'Erreur lors de la modification du message' });
      }
    });

    // Supprimer un message
    socket.on('delete-message', async (data) => {
      try {
        const { messageId, scope = 'me' } = data;

        const message = await Message.findById(messageId);
        if (!message) {
          return socket.emit('error', { message: 'Message non trouvé' });
        }

        if (message.auteur.toString() !== socket.userId) {
          return socket.emit('error', { message: 'Vous ne pouvez supprimer que vos propres messages' });
        }

        if (scope === 'all') {
          const messageAge = Date.now() - message.date.getTime();
          const fifteenMinutes = 15 * 60 * 1000;
          if (messageAge > fifteenMinutes) {
            return socket.emit('error', { message: 'Impossible de supprimer un message de plus de 15 minutes pour tout le monde' });
          }
          message.deletedForAll = true;
          message.contenu = 'Ce message a été supprimé';
          
          // Si c'est un message de type 'ride' avec un proposedRideId et un idGroupe,
          // retirer le groupId de la balade pour qu'elle disparaisse du calendrier
          if (message.type === 'ride' && message.proposedRideId && message.idGroupe) {
            try {
              const Ride = require('../models/Ride');
              const ride = await Ride.findById(message.proposedRideId);
              if (ride && ride.groupId && ride.groupId.toString() === message.idGroupe.toString()) {
                ride.groupId = null;
                await ride.save();
                console.log(`✅ Balade ${ride._id} retirée du groupe ${message.idGroupe} après suppression du message`);
              }
            } catch (rideError) {
              console.error('Erreur lors de la suppression du groupId de la balade:', rideError);
              // Ne pas bloquer la suppression du message si la mise à jour de la balade échoue
            }
          }
        } else {
          if (!message.deletedForUserIds.includes(socket.userId)) {
            message.deletedForUserIds.push(socket.userId);
          }
        }

        await message.save();

        const roomName = message.idGroupe ? `group-${message.idGroupe}` : `ride-${message.idBalade}`;
        io.to(roomName).emit('message-deleted', { messageId, scope, message });
      } catch (error) {
        socket.emit('error', { message: 'Erreur lors de la suppression du message' });
      }
    });

    // Restaurer un message supprimé "pour moi"
    socket.on('restore-message', async (data) => {
      try {
        const { messageId } = data;

        const message = await Message.findById(messageId);
        if (!message) {
          return socket.emit('error', { message: 'Message non trouvé' });
        }

        // Retirer l'utilisateur de deletedForUserIds
        const userId = socket.userId;
        message.deletedForUserIds = message.deletedForUserIds.filter(
          (id) => id.toString() !== userId.toString()
        );

        await message.save();
        await message.populate('auteur', 'pseudo email avatarUrl');

        const roomName = message.idGroupe ? `group-${message.idGroupe}` : `ride-${message.idBalade}`;
        io.to(roomName).emit('message-restored', { messageId, message });
      } catch (error) {
        socket.emit('error', { message: 'Erreur lors de la restauration du message' });
      }
    });

    // Réagir à un message
    socket.on('toggle-reaction', async (data) => {
      try {
        console.log('😀 Données reçues pour toggle-reaction:', JSON.stringify(data, null, 2));
        const { messageId, emoji } = data;

        if (!messageId) {
          console.error('❌ messageId manquant');
          return socket.emit('error', { message: 'ID du message manquant' });
        }

        if (!emoji) {
          console.error('❌ emoji manquant');
          return socket.emit('error', { message: 'Emoji manquant' });
        }

        const message = await Message.findById(messageId);
        if (!message) {
          console.error('❌ Message non trouvé avec ID:', messageId);
          return socket.emit('error', { message: 'Message non trouvé' });
        }

        console.log('✅ Message trouvé, ID:', message._id);

        // Vérifier si le message est supprimé pour cet utilisateur
        const isDeletedForUser = message.deletedForUserIds && Array.isArray(message.deletedForUserIds)
          ? message.deletedForUserIds.some(
              id => id && id.toString() === socket.userId.toString()
            )
          : false;
        
        if (message.deletedForAll || isDeletedForUser) {
          return socket.emit('error', { message: 'Impossible de réagir à un message supprimé' });
        }

        console.log('👤 Récupération de l\'utilisateur, userId:', socket.userId);
        const user = await User.findById(socket.userId);
        if (!user) {
          console.error('❌ Utilisateur non trouvé avec ID:', socket.userId);
          return socket.emit('error', { message: 'Utilisateur non trouvé' });
        }
        const userPseudo = user.pseudo || 'Utilisateur';
        console.log('✅ Utilisateur trouvé, pseudo:', userPseudo);

        // S'assurer que reactions est un array
        if (!Array.isArray(message.reactions)) {
          message.reactions = [];
        }

        const emojiTrimmed = emoji ? emoji.trim() : '';
        if (!emojiTrimmed || emojiTrimmed.length === 0) {
          return socket.emit('error', { message: 'L\'emoji ne peut pas être vide' });
        }

        if (emojiTrimmed.length > 10) {
          return socket.emit('error', { message: 'L\'emoji ne peut pas dépasser 10 caractères' });
        }

        const existingReactionIndex = message.reactions.findIndex(
          r => r && r.userId && r.userId.toString() === socket.userId.toString() && r.emoji === emojiTrimmed
        );

        if (existingReactionIndex >= 0) {
          // Retirer la réaction existante
          message.reactions.splice(existingReactionIndex, 1);
        } else {
          // Retirer toutes les réactions de cet utilisateur pour ce message
          message.reactions = message.reactions.filter(
            r => !r || !r.userId || r.userId.toString() !== socket.userId.toString()
          );
          // Ajouter la nouvelle réaction
          message.reactions.push({
            emoji: emojiTrimmed,
            userId: socket.userId,
            userPseudo: userPseudo,
            createdAt: new Date()
          });
        }

        // Marquer le champ reactions comme modifié (important pour Mongoose)
        message.markModified('reactions');

        console.log('💾 Réactions avant sauvegarde:', JSON.stringify(message.reactions, null, 2));

        // Valider avant de sauvegarder
        try {
          const validationError = message.validateSync();
          if (validationError) {
            console.error('❌ Erreur de validation:', validationError);
            return socket.emit('error', { 
              message: 'Erreur de validation: ' + Object.values(validationError.errors).map(e => e.message).join(', ')
            });
          }
        } catch (validationErr) {
          console.error('❌ Erreur lors de la validation:', validationErr);
          return socket.emit('error', { 
            message: 'Erreur de validation: ' + validationErr.message
          });
        }

        console.log('💾 Sauvegarde de la réaction...');
        await message.save();
        console.log('✅ Réaction sauvegardée avec succès');

        await message.populate('auteur', 'pseudo email avatarUrl');

        // Construire l'URL complète de l'avatar si nécessaire
        if (message.auteur && message.auteur.avatarUrl && !message.auteur.avatarUrl.startsWith('http')) {
          const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
          message.auteur.avatarUrl = `${baseUrl}${message.auteur.avatarUrl}`;
        }

        // Vérifier que le message a bien un idGroupe ou idBalade
        if (!message.idGroupe && !message.idBalade) {
          console.error('❌ Message sans idGroupe ni idBalade:', message._id);
          return socket.emit('error', { message: 'Message invalide: pas de groupe ou balade associé' });
        }

        const roomName = message.idGroupe ? `group-${message.idGroupe}` : `ride-${message.idBalade}`;
        console.log('📤 Envoi de reaction-updated à la room:', roomName);
        console.log('📤 Message ID:', message._id);
        console.log('📤 Message idGroupe:', message.idGroupe);
        console.log('📤 Message idBalade:', message.idBalade);
        io.to(roomName).emit('reaction-updated', { message });
        console.log('✅ Réaction mise à jour et diffusée avec succès');
      } catch (error) {
        console.error('❌ Erreur lors de la réaction:', error);
        console.error('❌ Stack:', error.stack);
        socket.emit('error', { 
          message: 'Erreur lors de la réaction: ' + (error.message || error.toString())
        });
      }
    });

    // Typing indicator
    const typingUsers = new Map(); // Map<roomName, Set<userId>>

    socket.on('typing-start', (data) => {
      const { conversationId, type } = data;
      const roomName = type === 'group' ? `group-${conversationId}` : `ride-${conversationId}`;
      
      if (!typingUsers.has(roomName)) {
        typingUsers.set(roomName, new Set());
      }
      typingUsers.get(roomName).add(socket.userId);

      socket.to(roomName).emit('typing', {
        userId: socket.userId,
        userPseudo: socket.user.pseudo || socket.user.email,
        isTyping: true
      });
    });

    socket.on('typing-stop', (data) => {
      const { conversationId, type } = data;
      const roomName = type === 'group' ? `group-${conversationId}` : `ride-${conversationId}`;
      
      if (typingUsers.has(roomName)) {
        typingUsers.get(roomName).delete(socket.userId);
      }

      socket.to(roomName).emit('typing', {
        userId: socket.userId,
        userPseudo: socket.user.pseudo || socket.user.email,
        isTyping: false
      });
    });

    // Déconnexion
    socket.on('disconnect', () => {
      console.log(`Utilisateur déconnecté: ${socket.user.email}`);
      
      // Nettoyer les typing indicators
      typingUsers.forEach((userSet, roomName) => {
        userSet.delete(socket.userId);
        if (userSet.size === 0) {
          typingUsers.delete(roomName);
        } else {
          socket.to(roomName).emit('typing', {
            userId: socket.userId,
            userPseudo: socket.user.pseudo || socket.user.email,
            isTyping: false
          });
        }
      });
    });
  });

  return io;
};

// Exporter une fonction pour obtenir l'instance io (pour les contrôleurs HTTP)
let ioInstance = null;
const setIoInstance = (io) => {
  ioInstance = io;
};

const getIoInstance = () => {
  return ioInstance;
};

module.exports = initializeSocket;
module.exports.setIoInstance = setIoInstance;
module.exports.getIoInstance = getIoInstance;

