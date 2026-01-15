const Message = require('../models/Message');
const Group = require('../models/Group');
const Ride = require('../models/Ride');
const mentionService = require('../services/mention.service');
const Notification = require('../models/Notification');
const User = require('../models/User');
const { NotFoundError, ForbiddenError } = require('../utils/errors');

// Obtenir les messages d'une conversation (pagination)
exports.getMessages = async (req, res) => {
  try {
    const { conversationId, type } = req.params; // type: 'group' ou 'ride'
    const { cursor, parentMessageId } = req.query; // parentMessageId: null pour messages principaux, ou ID pour réponses d'un thread
    
    // Standardiser la pagination avec limites strictes
    const pagination = require('../utils/pagination');
    const maxLimit = parseInt(process.env.PAGINATION_MAX_LIMIT) || 50;
    const defaultLimit = parseInt(process.env.PAGINATION_DEFAULT_LIMIT) || 20;
    
    const limit = Math.min(
      Math.max(parseInt(req.query.limit) || defaultLimit, 1),
      maxLimit
    );

    let filter = {};
    if (type === 'group') {
      filter.idGroupe = conversationId;
    } else if (type === 'ride') {
      filter.idBalade = conversationId;
    } else {
      return res.status(400).json({
        success: false,
        message: 'Type de conversation invalide (group ou ride)'
      });
    }

    // Vérifier les permissions
    if (type === 'group') {
      const group = await Group.findById(conversationId);
      if (!group) {
        return res.status(404).json({
          success: false,
          message: 'Groupe non trouvé'
        });
      }
      // Pour les groupes privés, vérifier si l'utilisateur est membre OU créateur
      // Le createur peut être un ObjectId ou un objet peuplé, donc on vérifie les deux cas
      const createurId = group.createur._id ? group.createur._id.toString() : group.createur.toString();
      const userId = req.user._id.toString();
      const isCreator = createurId === userId;
      const isMember = group.isMember(req.user._id);
      if (group.visibilite === 'privee' && !isMember && !isCreator) {
        return res.status(403).json({
          success: false,
          message: 'Vous n\'avez pas accès à ce groupe privé'
        });
      }
    } else if (type === 'ride') {
      const ride = await Ride.findById(conversationId);
      if (!ride) {
        return res.status(404).json({
          success: false,
          message: 'Balade non trouvée'
        });
      }
      const isParticipant = ride.participants.some(p => p.userId && p.userId.toString() === req.user._id.toString());
      const isOrganizer = ride.organisateur.toString() === req.user._id.toString();
      if (!isParticipant && !isOrganizer) {
        return res.status(403).json({
          success: false,
          message: 'Vous n\'êtes pas autorisé à accéder à cette discussion'
        });
      }
    }

    // Filtrer par thread : si parentMessageId est fourni, récupérer les réponses du thread
    // Sinon, récupérer uniquement les messages principaux (parentMessageId = null)
    if (parentMessageId !== undefined) {
      if (parentMessageId === null || parentMessageId === 'null') {
        filter.parentMessageId = null; // Messages principaux uniquement
      } else {
        filter.parentMessageId = parentMessageId; // Réponses d'un thread spécifique
      }
    } else {
      // Par défaut, afficher uniquement les messages principaux (pas les réponses de threads)
      filter.parentMessageId = null;
    }

    // Filtrer les messages supprimés pour cet utilisateur
    filter.$or = [
      { deletedForAll: false },
      { deletedForUserIds: { $ne: req.user._id } }
    ];

    // Pagination avec cursor
    if (cursor) {
      filter.date = { $lt: new Date(cursor) };
    }

    const messages = await Message.find(filter)
      .populate('auteur', 'pseudo email avatarUrl')
      .populate('replyToMessageId', 'contenu auteur')
      .populate('pinnedBy', 'pseudo email avatarUrl')
      .sort({ pinned: -1, date: -1 }) // Les messages épinglés en premier, puis par date
      .limit(parseInt(limit) + 1) // +1 pour savoir s'il y a plus de messages
      .lean();
    
    // Construire les URLs complètes des avatars
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    messages.forEach(msg => {
      if (msg.auteur && msg.auteur.avatarUrl && !msg.auteur.avatarUrl.startsWith('http')) {
        msg.auteur.avatarUrl = `${baseUrl}${msg.auteur.avatarUrl}`;
      }
    });

    const hasMore = messages.length > limit;
    const resultMessages = hasMore ? messages.slice(0, limit) : messages;
    const nextCursor = resultMessages.length > 0 ? resultMessages[resultMessages.length - 1].date : null;

    // Inverser pour avoir les plus anciens en premier
    resultMessages.reverse();

    // Encoder le cursor si nécessaire
    const encodedCursor = nextCursor ? pagination.encodeCursor({ createdAt: nextCursor }) : null;

    res.status(200).json({
      success: true,
      data: {
        messages: resultMessages,
        pagination: {
          hasMore,
          nextCursor: encodedCursor || nextCursor, // Supporte les deux formats pour compatibilité
          limit
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des messages',
      error: error.message
    });
  }
};

// Envoyer un message
exports.sendMessage = async (req, res) => {
  try {
    const { conversationId, type, content, replyToMessageId, parentMessageId, messageType } = req.body;

    // Si c'est un fichier, le contenu peut être vide
    const hasFile = req.file != null;
    // Utiliser messageType du body pour déterminer le type de fichier
    const fileType = hasFile ? (messageType || 'file') : (messageType || 'text');
    
    // Pour les messages de type 'poll' ou 'ride', le contenu peut être optionnel
    const isPollOrRide = messageType === 'poll' || messageType === 'ride';
    
    // Vérifier si le contenu est valide (y compris les emojis)
    // Les emojis sont des caractères Unicode valides, donc on vérifie juste que le texte trimmé n'est pas vide
    if (!hasFile && !isPollOrRide) {
      const trimmedContent = content ? content.trim() : '';
      if (trimmedContent.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Le contenu du message est requis'
        });
      }
    }

    let filter = {};
    if (type === 'group') {
      filter.idGroupe = conversationId;
      const group = await Group.findById(conversationId);
      if (!group) {
        return res.status(404).json({
          success: false,
          message: 'Groupe non trouvé'
        });
      }
      if (!group.isMember(req.user._id)) {
        return res.status(403).json({
          success: false,
          message: 'Vous n\'êtes pas membre de ce groupe'
        });
      }

      // Vérifier si l'utilisateur est muté dans ce groupe
      const GroupMute = require('../models/GroupMute');
      const activeMute = await GroupMute.findOne({
        groupId: conversationId,
        userId: req.user._id,
        mutedUntil: { $gt: new Date() }
      });

      if (activeMute) {
        return res.status(403).json({
          success: false,
          message: `Vous êtes muet dans ce groupe jusqu'au ${new Date(activeMute.mutedUntil).toLocaleString('fr-FR')}`
        });
      }
    } else if (type === 'ride') {
      filter.idBalade = conversationId;
      const ride = await Ride.findById(conversationId);
      if (!ride) {
        return res.status(404).json({
          success: false,
          message: 'Balade non trouvée'
        });
      }
      const isParticipant = ride.participants.some(p => p.userId && p.userId.toString() === req.user._id.toString());
      const isOrganizer = ride.organisateur.toString() === req.user._id.toString();
      if (!isParticipant && !isOrganizer) {
        return res.status(403).json({
          success: false,
          message: 'Vous n\'êtes pas autorisé à envoyer des messages'
        });
      }
    }

    // Préparer replyPreview si replyToMessageId existe
    let replyPreview = null;
    if (replyToMessageId) {
      const replyToMessage = await Message.findById(replyToMessageId)
        .populate('auteur', 'pseudo');
      if (replyToMessage) {
        replyPreview = {
          senderPseudo: replyToMessage.auteur?.pseudo || 'Utilisateur',
          content: replyToMessage.deletedForAll 
            ? 'Message supprimé' 
            : (replyToMessage.contenu.substring(0, 50) + (replyToMessage.contenu.length > 50 ? '...' : '')),
          type: replyToMessage.type || 'text'
        };
      }
    }

    // Préparer les métadonnées si un fichier est présent
    let metadata = null;
    if (req.file) {
      const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
      // Utiliser messageType du body (envoyé depuis le frontend)
      const fileType = req.body.messageType || 'file';
      
      // Utiliser le chemin réel du fichier sauvegardé par multer
      // req.file.path contient le chemin complet depuis la racine du projet
      const path = require('path');
      let filePath = '';
      
      // Extraire le chemin relatif depuis le dossier uploads
      if (req.file.path) {
        // req.file.path est quelque chose comme: /absolute/path/to/src/uploads/messages/images/filename.png
        // On veut extraire: /uploads/messages/images/filename.png
        const uploadsIndex = req.file.path.indexOf('uploads');
        if (uploadsIndex !== -1) {
          filePath = '/' + req.file.path.substring(uploadsIndex).replace(/\\/g, '/');
        } else {
          // Fallback: construire le chemin selon le type
          if (fileType === 'image') {
            filePath = `/uploads/messages/images/${req.file.filename}`;
          } else if (fileType === 'video') {
            filePath = `/uploads/messages/videos/${req.file.filename}`;
          } else if (fileType === 'audio') {
            filePath = `/uploads/messages/audio/${req.file.filename}`;
          } else {
            filePath = `/uploads/messages/files/${req.file.filename}`;
          }
        }
      } else {
        // Fallback si req.file.path n'existe pas
        if (fileType === 'image') {
          filePath = `/uploads/messages/images/${req.file.filename}`;
        } else if (fileType === 'video') {
          filePath = `/uploads/messages/videos/${req.file.filename}`;
        } else if (fileType === 'audio') {
          filePath = `/uploads/messages/audio/${req.file.filename}`;
        } else {
          filePath = `/uploads/messages/files/${req.file.filename}`;
        }
      }
      
      // Le nom de fichier a déjà été corrigé par le middleware message-upload
      // Mais on peut faire une vérification supplémentaire
      let fileName = req.file.originalname || 'Fichier';
      
      // Vérification supplémentaire si le middleware n'a pas corrigé
      if (fileName.includes('Ã')) {
        try {
          const buffer = Buffer.from(fileName, 'latin1');
          fileName = buffer.toString('utf8');
          console.log('🔤 Correction encodage dans controller:', { original: req.file.originalname, corrected: fileName });
        } catch (e) {
          console.warn('Erreur lors de la correction de l\'encodage:', e);
        }
      }
      
      metadata = {
        url: `${baseUrl}${filePath}`,
        mimeType: req.file.mimetype,
        size: req.file.size,
        fileName: fileName
      };
      
      console.log('📁 Fichier sauvegardé:', {
        filename: req.file.filename,
        path: req.file.path,
        fileType: fileType,
        filePath: filePath,
        url: metadata.url
      });
    }

    // Préparer pollData si c'est un sondage
    let pollData = null;
    let proposedRideId = null;
    
    if (messageType === 'poll' && req.body.pollData) {
      pollData = {
        question: req.body.pollData.question || 'Sondage',
        options: (req.body.pollData.options || []).map(opt => ({
          text: opt.text || opt,
          votes: []
        })),
        multipleChoice: req.body.pollData.multipleChoice || false,
        expiresAt: req.body.pollData.expiresAt ? new Date(req.body.pollData.expiresAt) : null
      };
    }
    
    // Si c'est un message de type 'ride', récupérer proposedRideId
    if (messageType === 'ride' && req.body.proposedRideId) {
      proposedRideId = req.body.proposedRideId;
      
      // Si c'est une balade proposée, créer automatiquement un sondage
      if (!pollData) {
        pollData = {
          question: 'Participez-vous à cette balade ?',
          options: [
            { text: 'Je participe', votes: [] },
            { text: 'Je ne participe pas', votes: [] }
          ],
          multipleChoice: false,
          expiresAt: null
        };
      }
    }

    // Parser et résoudre les mentions si le message a du contenu texte
    let mentions = [];
    if (content && typeof content === 'string' && content.trim().length > 0) {
      try {
        const groupIdForMentions = type === 'group' ? conversationId : null;
        const resolvedMentions = await mentionService.parseAndResolveMentions(content, groupIdForMentions);
        mentions = resolvedMentions.map(m => m.userId);
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

    const message = new Message({
      auteur: req.user._id,
      contenu: hasFile ? (content?.trim() || req.file.originalname || 'Fichier') : (content?.trim() || ''),
      type: hasFile ? fileType : (messageType || 'text'),
      metadata: metadata,
      [type === 'group' ? 'idGroupe' : 'idBalade']: conversationId,
      replyToMessageId: replyToMessageId || null,
      parentMessageId: parentMessageId || null, // Pour les threads
      threadRootId: threadRootId, // ID du message racine du fil
      replyPreview: replyPreview,
      pollData: pollData,
      proposedRideId: proposedRideId,
      mentions: mentions // Ajouter les mentions résolues
    });

    await message.save();

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

    // Créer des notifications pour les utilisateurs mentionnés (en arrière-plan, ne pas bloquer)
    if (mentions.length > 0) {
      try {
        const resolvedMentions = await mentionService.parseAndResolveMentions(content, type === 'group' ? conversationId : null);
        const group = type === 'group' ? await Group.findById(conversationId).select('nom').lean() : null;
        const groupName = group ? group.nom : null;
        
        for (const mention of resolvedMentions) {
          // Ne pas notifier si l'utilisateur s'est mentionné lui-même
          if (mention.userId.toString() === req.user._id.toString()) {
            continue;
          }

          // Créer la notification
          await Notification.create({
            user: mention.userId,
            type: 'mention',
            title: `${req.user.pseudo || 'Quelqu\'un'} vous a mentionné${groupName ? ` dans ${groupName}` : ''}`,
            message: content.length > 100 ? content.substring(0, 100) + '...' : content,
            metadata: {
              messageId: message._id,
              groupId: type === 'group' ? conversationId : null,
              rideId: type === 'ride' ? conversationId : null,
              mentionedBy: req.user._id,
              mentionedByPseudo: req.user.pseudo || req.user.email
            }
          });
        }
      } catch (notifError) {
        console.error('Erreur lors de la création des notifications de mention:', notifError);
        // Ne pas bloquer si les notifications échouent
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

    // Construire l'URL complète du fichier dans metadata si présent
    if (message.metadata && message.metadata.url && !message.metadata.url.startsWith('http')) {
      const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
      message.metadata.url = `${baseUrl}${message.metadata.url}`;
    }

    // Émettre l'événement Socket.io pour mettre à jour les clients en temps réel
    try {
      const socketService = require('../services/socket.service');
      const io = socketService.getIoInstance ? socketService.getIoInstance() : null;
      if (io) {
        const roomName = type === 'group' ? `group-${conversationId}` : `ride-${conversationId}`;
        const messageObj = message.toObject ? message.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(message));
        io.to(roomName).emit('new-message', { message: messageObj });
      }
    } catch (socketError) {
      console.error('Erreur lors de l\'émission Socket:', socketError);
      // Ne pas bloquer la réponse HTTP si Socket.io échoue
    }

    res.status(201).json({
      success: true,
      data: { message }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'envoi du message',
      error: error.message
    });
  }
};

// Modifier un message
exports.editMessage = async (req, res) => {
  try {
    const { id } = req.params;
    const { content } = req.body;

    if (!content || content.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Le contenu du message est requis'
      });
    }

    const message = await Message.findById(id);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Vérifier que l'utilisateur est l'auteur
    if (message.auteur.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez modifier que vos propres messages'
      });
    }

    // Vérifier que le message n'est pas supprimé
    if (message.deletedForAll) {
      return res.status(400).json({
        success: false,
        message: 'Impossible de modifier un message supprimé'
      });
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

    res.status(200).json({
      success: true,
      data: { message }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la modification du message',
      error: error.message
    });
  }
};

// Supprimer un message
exports.deleteMessage = async (req, res) => {
  try {
    const { id } = req.params;
    const { scope = 'me' } = req.query; // 'me' ou 'all'

    const message = await Message.findById(id);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Vérifier que l'utilisateur est l'auteur
    if (message.auteur.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez supprimer que vos propres messages'
      });
    }

    if (scope === 'all') {
      // Supprimer pour tout le monde (sans restriction de temps)
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
      // Supprimer pour moi uniquement
      if (!message.deletedForUserIds.includes(req.user._id)) {
        message.deletedForUserIds.push(req.user._id);
      }
    }

    await message.save();
    await message.populate('auteur', 'pseudo email avatarUrl');

    // Construire l'URL complète de l'avatar si nécessaire
    if (message.auteur && message.auteur.avatarUrl && !message.auteur.avatarUrl.startsWith('http')) {
      const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
      message.auteur.avatarUrl = `${baseUrl}${message.auteur.avatarUrl}`;
    }

    // Émettre l'événement Socket pour mettre à jour les clients en temps réel
    try {
      const socketService = require('../services/socket.service');
      const io = socketService.getIoInstance ? socketService.getIoInstance() : null;
      if (io) {
        const roomName = message.idGroupe ? `group-${message.idGroupe}` : `ride-${message.idBalade}`;
        const messageObj = message.toObject ? message.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(message));
        io.to(roomName).emit('message-deleted', { 
          messageId: message._id.toString(), 
          scope: scope,
          message: messageObj
        });
      }
    } catch (socketError) {
      console.error('Erreur lors de l\'émission Socket:', socketError);
      // Ne pas bloquer la réponse HTTP si Socket échoue
    }

    res.status(200).json({
      success: true,
      message: 'Message supprimé avec succès',
      data: { message }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la suppression du message',
      error: error.message
    });
  }
};

// Restaurer un message supprimé "pour moi"
exports.restoreMessage = async (req, res) => {
  try {
    const { id } = req.params;

    const message = await Message.findById(id);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Retirer l'utilisateur de deletedForUserIds
    const userId = req.user._id;
    message.deletedForUserIds = message.deletedForUserIds.filter(
      (id) => id.toString() !== userId.toString()
    );

    await message.save();
    await message.populate('auteur', 'pseudo email avatarUrl');

    // Construire l'URL complète de l'avatar si nécessaire
    if (message.auteur && message.auteur.avatarUrl && !message.auteur.avatarUrl.startsWith('http')) {
      const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
      message.auteur.avatarUrl = `${baseUrl}${message.auteur.avatarUrl}`;
    }

    // Émettre l'événement Socket pour mettre à jour les clients en temps réel
    try {
      const socketService = require('../services/socket.service');
      const io = socketService.getIoInstance ? socketService.getIoInstance() : null;
      if (io) {
        const roomName = message.idGroupe ? `group-${message.idGroupe}` : `ride-${message.idBalade}`;
        const messageObj = message.toObject ? message.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(message));
        io.to(roomName).emit('message-restored', { 
          messageId: message._id.toString(),
          message: messageObj
        });
      }
    } catch (socketError) {
      console.error('Erreur lors de l\'émission Socket:', socketError);
      // Ne pas bloquer la réponse HTTP si Socket échoue
    }

    res.status(200).json({
      success: true,
      message: 'Message restauré avec succès',
      data: { message }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la restauration du message',
      error: error.message
    });
  }
};

// Ajouter/Retirer une réaction
exports.toggleReaction = async (req, res) => {
  try {
    const { id } = req.params;
    const { emoji } = req.body;

    if (!emoji || emoji.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'L\'emoji est requis'
      });
    }

    const message = await Message.findById(id);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Vérifier que le message n'est pas supprimé pour cet utilisateur
    if (message.deletedForAll || message.deletedForUserIds.includes(req.user._id)) {
      return res.status(400).json({
        success: false,
        message: 'Impossible de réagir à un message supprimé'
      });
    }

    // Récupérer le pseudo de l'utilisateur
    const user = await User.findById(req.user._id);
    const userPseudo = user?.pseudo || 'Utilisateur';

    // Chercher si l'utilisateur a déjà réagi avec cet emoji
    const existingReactionIndex = message.reactions.findIndex(
      r => r.userId.toString() === req.user._id.toString() && r.emoji === emoji.trim()
    );

    if (existingReactionIndex >= 0) {
      // Retirer la réaction
      message.reactions.splice(existingReactionIndex, 1);
    } else {
      // Retirer toutes les réactions de cet utilisateur pour ce message (un seul emoji par utilisateur)
      message.reactions = message.reactions.filter(
        r => r.userId.toString() !== req.user._id.toString()
      );
      // Ajouter la nouvelle réaction
      message.reactions.push({
        emoji: emoji.trim(),
        userId: req.user._id,
        userPseudo: userPseudo,
        createdAt: new Date()
      });
    }

    await message.save();
    await message.populate('auteur', 'pseudo email avatarUrl');

    // Construire l'URL complète de l'avatar si nécessaire
    if (message.auteur && message.auteur.avatarUrl && !message.auteur.avatarUrl.startsWith('http')) {
      const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
      message.auteur.avatarUrl = `${baseUrl}${message.auteur.avatarUrl}`;
    }

    res.status(200).json({
      success: true,
      data: { message }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la réaction',
      error: error.message
    });
  }
};

// Épingler/Désépingler un message
exports.togglePin = async (req, res) => {
  try {
    const { id } = req.params;
    const message = await Message.findById(id);
    
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Vérifier que le message appartient à un groupe
    if (!message.idGroupe) {
      return res.status(400).json({
        success: false,
        message: 'Seuls les messages de groupe peuvent être épinglés'
      });
    }

    // Vérifier que l'utilisateur est le créateur du groupe
    const group = await Group.findById(message.idGroupe);
    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier que l'utilisateur est owner/admin/mod
    if (!group.isModerator(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Seuls le créateur, les administrateurs et les modérateurs peuvent épingler des messages'
      });
    }

    // Toggle l'état d'épinglage
    message.pinned = !message.pinned;
    if (message.pinned) {
      message.pinnedAt = new Date();
      message.pinnedBy = req.user._id;
    } else {
      message.pinnedAt = null;
      message.pinnedBy = null;
    }

    await message.save();
    await message.populate('auteur', 'pseudo email avatarUrl');
    await message.populate('pinnedBy', 'pseudo email avatarUrl');

    // Construire l'URL complète de l'avatar si nécessaire
    if (message.auteur && message.auteur.avatarUrl && !message.auteur.avatarUrl.startsWith('http')) {
      const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
      message.auteur.avatarUrl = `${baseUrl}${message.auteur.avatarUrl}`;
    }

    // Émettre l'événement Socket.io pour mettre à jour les clients en temps réel
    try {
      const socketService = require('../services/socket.service');
      const io = socketService.getIoInstance ? socketService.getIoInstance() : null;
      if (io) {
        const roomName = `group-${message.idGroupe}`;
        const messageObj = message.toObject ? message.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(message));
        io.to(roomName).emit('message-pinned', {
          messageId: message._id.toString(),
          pinned: message.pinned,
          message: messageObj
        });
      }
    } catch (socketError) {
      console.error('Erreur lors de l\'émission Socket:', socketError);
    }

    res.status(200).json({
      success: true,
      data: {
        message,
        pinned: message.pinned
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'épinglage du message',
      error: error.message
    });
  }
};

/**
 * Obtenir la liste des messages épinglés d'un groupe
 * GET /api/groups/:groupId/messages/pins
 */
exports.getPinnedMessages = async (req, res, next) => {
  try {
    const { groupId } = req.params;

    // Vérifier que le groupe existe
    const group = await Group.findById(groupId);
    if (!group) {
      return next(new NotFoundError('Groupe'));
    }

    // Vérifier les permissions (membre du groupe)
    if (group.visibilite === 'privee' && !group.isMember(req.user._id) && !group.isCreator(req.user._id)) {
      return next(new ForbiddenError('Vous n\'avez pas accès à ce groupe privé'));
    }

    // Récupérer les messages épinglés
    const pinnedMessages = await Message.find({
      idGroupe: groupId,
      pinned: true,
      $or: [
        { deletedForAll: false },
        { deletedForUserIds: { $ne: req.user._id } }
      ]
    })
      .populate('auteur', 'pseudo email avatarUrl')
      .populate('pinnedBy', 'pseudo email avatarUrl')
      .populate('replyToMessageId', 'contenu auteur')
      .sort({ pinnedAt: -1 }) // Plus récemment épinglés en premier
      .lean();

    // Construire les URLs complètes des avatars
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    pinnedMessages.forEach(msg => {
      if (msg.auteur && msg.auteur.avatarUrl && !msg.auteur.avatarUrl.startsWith('http')) {
        msg.auteur.avatarUrl = `${baseUrl}${msg.auteur.avatarUrl}`;
      }
      if (msg.pinnedBy && msg.pinnedBy.avatarUrl && !msg.pinnedBy.avatarUrl.startsWith('http')) {
        msg.pinnedBy.avatarUrl = `${baseUrl}${msg.pinnedBy.avatarUrl}`;
      }
    });

    res.status(200).json({
      success: true,
      data: {
        messages: pinnedMessages
      }
    });
  } catch (error) {
    next(error);
  }
};

// Marquer les messages comme lus
exports.markAsRead = async (req, res) => {
  try {
    const { conversationId, type } = req.params;

    if (type === 'group') {
      // Pour les groupes, enregistrer la date de dernière lecture
      const GroupRead = require('../models/GroupRead');
      const group = await Group.findById(conversationId);
      
      if (!group) {
        return res.status(404).json({
          success: false,
          message: 'Groupe non trouvé'
        });
      }

      // Vérifier que l'utilisateur est membre
      if (!group.isMember(req.user._id) && !group.isCreator(req.user._id)) {
        return res.status(403).json({
          success: false,
          message: 'Vous n\'êtes pas membre de ce groupe'
        });
      }

      // Mettre à jour ou créer l'entrée GroupRead
      await GroupRead.findOneAndUpdate(
        {
          groupId: conversationId,
          userId: req.user._id
        },
        {
          groupId: conversationId,
          userId: req.user._id,
          lastReadAt: new Date()
        },
        {
          upsert: true,
          new: true
        }
      );

      res.status(200).json({
        success: true,
        message: 'Messages marqués comme lus'
      });
    } else {
      // Pour les balades, on peut implémenter plus tard si nécessaire
      res.status(200).json({
        success: true,
        message: 'Messages marqués comme lus'
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors du marquage comme lu',
      error: error.message
    });
  }
};

// Voter sur un sondage
exports.votePoll = async (req, res) => {
  try {
    const { id } = req.params; // Message ID
    const { optionIndex } = req.body; // Index de l'option choisie

    const message = await Message.findById(id);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    if (!message.pollData || !message.pollData.options) {
      return res.status(400).json({
        success: false,
        message: 'Ce message n\'est pas un sondage'
      });
    }

    // Vérifier si le sondage a expiré
    if (message.pollData.expiresAt && new Date() > message.pollData.expiresAt) {
      return res.status(400).json({
        success: false,
        message: 'Ce sondage a expiré'
      });
    }

    // Vérifier que l'index est valide
    if (optionIndex < 0 || optionIndex >= message.pollData.options.length) {
      return res.status(400).json({
        success: false,
        message: 'Option invalide'
      });
    }

    const userId = req.user._id.toString();
    const userPseudo = req.user.pseudo || req.user.email;

    // Si multipleChoice est false, retirer le vote précédent de l'utilisateur
    if (!message.pollData.multipleChoice) {
      for (const option of message.pollData.options) {
        option.votes = option.votes.filter(
          vote => vote.userId.toString() !== userId
        );
      }
    } else {
      // Si multipleChoice est true, vérifier si l'utilisateur a déjà voté pour cette option
      const selectedOption = message.pollData.options[optionIndex];
      const hasVoted = selectedOption.votes.some(
        vote => vote.userId.toString() === userId
      );
      if (hasVoted) {
        // Retirer le vote
        selectedOption.votes = selectedOption.votes.filter(
          vote => vote.userId.toString() !== userId
        );
        await message.save();
        await message.populate('auteur', 'pseudo email avatarUrl');
        
        // Émettre l'événement Socket.io
        try {
          const socketService = require('../services/socket.service');
          const io = socketService.getIoInstance ? socketService.getIoInstance() : null;
          if (io) {
            const roomName = message.idGroupe ? `group-${message.idGroupe}` : `ride-${message.idBalade}`;
            const messageObj = message.toObject ? message.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(message));
            io.to(roomName).emit('poll-updated', { message: messageObj });
          }
        } catch (socketError) {
          console.error('Erreur lors de l\'émission Socket:', socketError);
        }

        return res.status(200).json({
          success: true,
          message: 'Vote retiré',
          data: { message }
        });
      }
    }

    // Ajouter le vote
    message.pollData.options[optionIndex].votes.push({
      userId: req.user._id,
      userPseudo: userPseudo,
      votedAt: new Date()
    });

    await message.save();
    await message.populate('auteur', 'pseudo email avatarUrl');

    // Émettre l'événement Socket.io
    try {
      const socketService = require('../services/socket.service');
      const io = socketService.getIoInstance ? socketService.getIoInstance() : null;
      if (io) {
        const roomName = message.idGroupe ? `group-${message.idGroupe}` : `ride-${message.idBalade}`;
        const messageObj = message.toObject ? message.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(message));
        io.to(roomName).emit('poll-updated', { message: messageObj });
      }
    } catch (socketError) {
      console.error('Erreur lors de l\'émission Socket:', socketError);
    }

    res.status(200).json({
      success: true,
      message: 'Vote enregistré',
      data: { message }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors du vote',
      error: error.message
    });
  }
};

/**
 * Obtenir un thread complet (message racine + toutes ses réponses)
 * GET /api/messages/:messageId/thread
 */
exports.getThread = async (req, res, next) => {
  try {
    const { messageId } = req.params;

    // Récupérer le message racine
    const rootMessage = await Message.findById(messageId)
      .populate('auteur', 'pseudo email avatarUrl')
      .populate('replyToMessageId', 'contenu auteur')
      .populate('pinnedBy', 'pseudo email avatarUrl')
      .lean();

    if (!rootMessage) {
      return next(new NotFoundError('Message'));
    }

    // Vérifier les permissions selon le type (group ou ride)
    if (rootMessage.idGroupe) {
      const group = await Group.findById(rootMessage.idGroupe);
      if (!group) {
        return next(new NotFoundError('Groupe'));
      }
      if (!group.isMember(req.user._id) && group.createur.toString() !== req.user._id.toString()) {
        return next(new ForbiddenError('Vous n\'avez pas accès à ce groupe'));
      }
    } else if (rootMessage.idBalade) {
      const ride = await Ride.findById(rootMessage.idBalade);
      if (!ride) {
        return next(new NotFoundError('Balade'));
      }
      const isParticipant = ride.participants.some(p => p.userId && p.userId.toString() === req.user._id.toString());
      const isOrganizer = ride.organisateur.toString() === req.user._id.toString();
      if (!isParticipant && !isOrganizer) {
        return next(new ForbiddenError('Vous n\'avez pas accès à cette discussion'));
      }
    }

    // Déterminer le threadRootId (le message racine du fil)
    const threadRootId = rootMessage.threadRootId || rootMessage._id;

    // Récupérer toutes les réponses du thread
    const replies = await Message.find({
      $or: [
        { parentMessageId: threadRootId },
        { threadRootId: threadRootId }
      ],
      $and: [
        {
          $or: [
            { deletedForAll: false },
            { deletedForUserIds: { $ne: req.user._id } }
          ]
        }
      ]
    })
      .populate('auteur', 'pseudo email avatarUrl')
      .populate('parentMessageId', 'contenu auteur')
      .sort({ date: 1 }) // Ordre chronologique pour les réponses
      .lean();

    // Construire les URLs complètes des avatars
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    [rootMessage, ...replies].forEach(msg => {
      if (msg.auteur && msg.auteur.avatarUrl && !msg.auteur.avatarUrl.startsWith('http')) {
        msg.auteur.avatarUrl = `${baseUrl}${msg.auteur.avatarUrl}`;
      }
      if (msg.pinnedBy && msg.pinnedBy.avatarUrl && !msg.pinnedBy.avatarUrl.startsWith('http')) {
        msg.pinnedBy.avatarUrl = `${baseUrl}${msg.pinnedBy.avatarUrl}`;
      }
    });

    res.status(200).json({
      success: true,
      data: {
        root: rootMessage,
        replies: replies
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Recherche avancée de messages dans un groupe
 * GET /api/groups/:groupId/messages/search
 * Query params:
 *   - q: texte à rechercher (optionnel)
 *   - media: true/false pour filtrer les messages avec média (optionnel)
 *   - poll: true/false pour filtrer les sondages (optionnel)
 *   - from: date de début (ISO string, optionnel)
 *   - to: date de fin (ISO string, optionnel)
 *   - cursor: pour pagination (optionnel)
 *   - limit: nombre de résultats (défaut: 20, max: 50)
 */
exports.searchMessages = async (req, res, next) => {
  try {
    const { groupId } = req.params;
    const { q, media, poll, from, to, cursor, limit = 20 } = req.query;

    // Vérifier que le groupe existe
    const group = await Group.findById(groupId);
    if (!group) {
      return next(new NotFoundError('Groupe'));
    }

    // Vérifier les permissions (membre du groupe)
    if (group.visibilite === 'privee' && !group.isMember(req.user._id) && !group.isCreator(req.user._id)) {
      return next(new ForbiddenError('Vous n\'avez pas accès à ce groupe privé'));
    }

    // Construire le filtre de base
    const filter = {
      idGroupe: groupId,
      parentMessageId: null, // Seulement les messages principaux (pas les réponses de threads)
      $and: [
        {
          $or: [
            { deletedForAll: false },
            { deletedForUserIds: { $ne: req.user._id } }
          ]
        }
      ]
    };

    // Recherche textuelle
    if (q && q.trim().length > 0) {
      filter.$text = { $search: q.trim() };
    }

    // Filtrer par média
    if (media === 'true') {
      filter.$and.push({
        $or: [
          { type: { $in: ['image', 'video', 'audio', 'file'] } },
          { 'metadata.url': { $exists: true, $ne: null } }
        ]
      });
    } else if (media === 'false') {
      filter.$and.push({
        $and: [
          { type: { $nin: ['image', 'video', 'audio', 'file'] } },
          { $or: [
            { 'metadata.url': { $exists: false } },
            { 'metadata.url': null }
          ]}
        ]
      });
    }

    // Filtrer par sondage
    if (poll === 'true') {
      filter.type = 'poll';
      filter['pollData.question'] = { $exists: true, $ne: null };
    } else if (poll === 'false') {
      filter.type = { $ne: 'poll' };
    }

    // Filtrer par période
    if (from || to) {
      filter.date = {};
      if (from) {
        filter.date.$gte = new Date(from);
      }
      if (to) {
        filter.date.$lte = new Date(to);
      }
    }

    // Pagination avec cursor
    const maxLimit = Math.min(parseInt(limit) || 20, 50);
    if (cursor) {
      filter.date = filter.date || {};
      filter.date.$lt = new Date(cursor);
    }

    // Construire la requête avec tri
    let query = Message.find(filter);
    
    // Si recherche textuelle, utiliser le score de texte pour le tri
    if (q && q.trim().length > 0) {
      query = query.select({ score: { $meta: 'textScore' } });
      query = query.sort({ score: { $meta: 'textScore' }, date: -1 });
    } else {
      query = query.sort({ date: -1 });
    }

    query = query
      .populate('auteur', 'pseudo email avatarUrl')
      .populate('pinnedBy', 'pseudo email avatarUrl')
      .populate('replyToMessageId', 'contenu auteur')
      .limit(maxLimit + 1) // +1 pour savoir s'il y a plus de résultats
      .lean();

    const messages = await query;

    // Construire les URLs complètes des avatars
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    messages.forEach(msg => {
      if (msg.auteur && msg.auteur.avatarUrl && !msg.auteur.avatarUrl.startsWith('http')) {
        msg.auteur.avatarUrl = `${baseUrl}${msg.auteur.avatarUrl}`;
      }
      if (msg.pinnedBy && msg.pinnedBy.avatarUrl && !msg.pinnedBy.avatarUrl.startsWith('http')) {
        msg.pinnedBy.avatarUrl = `${baseUrl}${msg.pinnedBy.avatarUrl}`;
      }
    });

    // Déterminer s'il y a plus de résultats
    const hasMore = messages.length > maxLimit;
    const results = hasMore ? messages.slice(0, maxLimit) : messages;
    const nextCursor = hasMore && results.length > 0 
      ? results[results.length - 1].date.toISOString() 
      : null;

    res.status(200).json({
      success: true,
      data: {
        messages: results,
        pageInfo: {
          hasNextPage: hasMore,
          nextCursor: nextCursor
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Signaler un message
 * POST /api/groups/:groupId/messages/:messageId/report
 */
exports.reportMessage = async (req, res, next) => {
  try {
    const { groupId, messageId } = req.params;
    const { reasonCode, reasonText } = req.body;

    // Vérifier que le groupe existe
    const group = await Group.findById(groupId);
    if (!group) {
      return next(new NotFoundError('Groupe'));
    }

    // Vérifier que l'utilisateur est membre du groupe
    if (!group.isMember(req.user._id) && !group.isCreator(req.user._id)) {
      return next(new ForbiddenError('Vous n\'êtes pas membre de ce groupe'));
    }

    // Vérifier que le message existe
    const message = await Message.findById(messageId);
    if (!message) {
      return next(new NotFoundError('Message'));
    }

    // Vérifier que le message appartient au groupe
    if (message.idGroupe?.toString() !== groupId) {
      return next(new ForbiddenError('Ce message n\'appartient pas à ce groupe'));
    }

    // Vérifier que l'utilisateur ne signale pas son propre message
    if (message.auteur.toString() === req.user._id.toString()) {
      return res.status(400).json({
        success: false,
        message: 'Vous ne pouvez pas signaler votre propre message'
      });
    }

    // Vérifier les codes de raison valides
    const validReasonCodes = ['SPAM', 'HARASSMENT', 'HATE', 'NUDITY', 'OTHER'];
    if (!reasonCode || !validReasonCodes.includes(reasonCode)) {
      return res.status(400).json({
        success: false,
        message: 'Code de raison invalide. Valeurs acceptées: ' + validReasonCodes.join(', ')
      });
    }

    // Vérifier qu'il n'y a pas déjà un report ouvert pour ce message par cet utilisateur
    const MessageReport = require('../models/MessageReport');
    const existingReport = await MessageReport.findOne({
      messageId: messageId,
      reporterId: req.user._id,
      status: { $in: ['open', 'reviewing'] }
    });

    if (existingReport) {
      return res.status(400).json({
        success: false,
        message: 'Vous avez déjà signalé ce message'
      });
    }

    // Créer le report
    const report = await MessageReport.create({
      groupId: groupId,
      messageId: messageId,
      reporterId: req.user._id,
      reasonCode: reasonCode,
      reasonText: reasonText?.trim() || null,
      status: 'open'
    });

    // Notifier les modérateurs/admins du groupe
    const Notification = require('../models/Notification');
    const modsAndAdmins = group.membres
      .filter(m => m.role === 'admin' || m.role === 'moderateur')
      .map(m => m.userId);
    
    // Ajouter le créateur s'il n'est pas déjà dans la liste
    if (!modsAndAdmins.some(id => id.toString() === group.createur.toString())) {
      modsAndAdmins.push(group.createur);
    }

    // Créer des notifications pour les mods/admins
    for (const modId of modsAndAdmins) {
      if (modId.toString() !== req.user._id.toString()) {
        await Notification.create({
          user: modId,
          type: 'message_reported',
          title: 'Message signalé',
          message: `Un message a été signalé dans le groupe ${group.nom}`,
          metadata: {
            groupId: groupId,
            messageId: messageId,
            reportId: report._id,
            reasonCode: reasonCode
          }
        });
      }
    }

    // Logger l'action
    const GroupModerationLog = require('../models/GroupModerationLog');
    await GroupModerationLog.create({
      groupId: groupId,
      action: 'report',
      messageId: messageId,
      performedBy: req.user._id,
      meta: {
        reasonCode: reasonCode,
        reasonText: reasonText
      }
    });

    res.status(201).json({
      success: true,
      message: 'Message signalé avec succès',
      data: { report }
    });
  } catch (error) {
    next(error);
  }
};

