const Rating = require('../models/Rating');
const Ride = require('../models/Ride');
const User = require('../models/User');

/**
 * @swagger
 * /api/ratings:
 *   post:
 *     summary: Créer une note pour une balade
 *     tags: [Ratings]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - balade
 *               - note
 *             properties:
 *               balade:
 *                 type: string
 *                 description: ID de la balade à noter
 *               note:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 5
 *                 description: Note entre 1 et 5
 *               commentaire:
 *                 type: string
 *                 maxLength: 1000
 *                 description: Commentaire optionnel
 *     responses:
 *       201:
 *         description: Note créée avec succès
 *       400:
 *         description: Erreur de validation
 *       401:
 *         description: Non authentifié
 *       403:
 *         description: Non autorisé (balade non passée ou non participant)
 *       409:
 *         description: Note déjà existante
 */
exports.createRating = async (req, res) => {
  try {
    const { balade, note, commentaire } = req.body;
    const utilisateur = req.user._id;

    // Validation des champs requis
    if (!balade || !note) {
      return res.status(400).json({
        success: false,
        message: 'La balade et la note sont requises'
      });
    }

    // Validation de la note
    if (!Number.isInteger(note) || note < 1 || note > 5) {
      return res.status(400).json({
        success: false,
        message: 'La note doit être un nombre entier entre 1 et 5'
      });
    }

    // Validation du commentaire
    if (commentaire && commentaire.length > 1000) {
      return res.status(400).json({
        success: false,
        message: 'Le commentaire ne peut pas dépasser 1000 caractères'
      });
    }

    // Vérifier que la balade existe
    const ride = await Ride.findById(balade);
    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier que l'utilisateur a participé à la balade
    const isParticipant = ride.participants.some(
      participant => participant.toString() === utilisateur.toString()
    );

    if (!isParticipant) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez avoir participé à cette balade pour la noter'
      });
    }

    // Vérifier que la balade est passée
    const rideDate = new Date(ride.date);
    const [hours, minutes] = ride.heure.split(':').map(Number);
    rideDate.setHours(hours, minutes, 0, 0);

    if (rideDate > new Date()) {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez noter une balade qu\'après qu\'elle ait eu lieu'
      });
    }

    // Vérifier si l'utilisateur a déjà noté cette balade
    const existingRating = await Rating.findOne({
      utilisateur,
      balade
    });

    if (existingRating) {
      return res.status(409).json({
        success: false,
        message: 'Vous avez déjà noté cette balade. Vous ne pouvez la noter qu\'une seule fois.'
      });
    }

    // Créer la note
    const rating = new Rating({
      note,
      commentaire: commentaire || null,
      utilisateur,
      balade,
      dateNote: new Date()
    });

    await rating.save();

    // Populate pour la réponse
    await rating.populate('utilisateur', 'firstName lastName pseudo email');
    await rating.populate('balade', 'titre date');

    // Calculer la nouvelle moyenne et mettre à jour la balade
    const { moyenne, nombre } = await Rating.calculateAverageRating(balade);
    ride.noteMoyenne = moyenne;
    await ride.save();

    res.status(201).json({
      success: true,
      message: 'Note créée avec succès',
      data: {
        rating: {
          id: rating._id,
          note: rating.note,
          commentaire: rating.commentaire,
          utilisateur: {
            id: rating.utilisateur._id,
            nom: rating.utilisateur.firstName && rating.utilisateur.lastName
              ? `${rating.utilisateur.firstName} ${rating.utilisateur.lastName}`
              : rating.utilisateur.pseudo || rating.utilisateur.email,
            pseudo: rating.utilisateur.pseudo
          },
          balade: {
            id: rating.balade._id,
            titre: rating.balade.titre
          },
          dateNote: rating.dateNote
        },
        moyenneBalade: moyenne,
        nombreNotes: nombre
      }
    });
  } catch (error) {
    // Gérer les erreurs de contrainte unique (doublon)
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'Vous avez déjà noté cette balade. Vous ne pouvez la noter qu\'une seule fois.'
      });
    }

    console.error('Erreur lors de la création de la note:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la création de la note',
      error: error.message
    });
  }
};

/**
 * @swagger
 * /api/ratings/ride/{rideId}:
 *   get:
 *     summary: Récupérer toutes les notes d'une balade
 *     tags: [Ratings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: rideId
 *         required: true
 *         schema:
 *           type: string
 *         description: ID de la balade
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Numéro de page
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *           maximum: 50
 *         description: Nombre d'éléments par page
 *     responses:
 *       200:
 *         description: Liste des notes récupérée avec succès
 *       404:
 *         description: Balade non trouvée
 */
exports.getRatingsByRide = async (req, res) => {
  try {
    const { rideId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 10, 50);
    const skip = (page - 1) * limit;

    // Vérifier que la balade existe
    const ride = await Ride.findById(rideId);
    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Récupérer les notes avec pagination
    const ratings = await Rating.find({ balade: rideId })
      .populate('utilisateur', 'firstName lastName pseudo email')
      .sort({ dateNote: -1 })
      .skip(skip)
      .limit(limit);

    // Compter le total de notes
    const totalRatings = await Rating.countDocuments({ balade: rideId });

    // Calculer la moyenne
    const { moyenne, nombre } = await Rating.calculateAverageRating(rideId);

    // Formater la réponse
    const formattedRatings = ratings.map(rating => ({
      id: rating._id,
      note: rating.note,
      commentaire: rating.commentaire,
      utilisateur: {
        id: rating.utilisateur._id,
        nom: rating.utilisateur.firstName && rating.utilisateur.lastName
          ? `${rating.utilisateur.firstName} ${rating.utilisateur.lastName}`
          : rating.utilisateur.pseudo || rating.utilisateur.email,
        pseudo: rating.utilisateur.pseudo,
        email: rating.utilisateur.email
      },
      dateNote: rating.dateNote,
      createdAt: rating.createdAt
    }));

    res.status(200).json({
      success: true,
      data: {
        ratings: formattedRatings,
        pagination: {
          page,
          limit,
          total: totalRatings,
          totalPages: Math.ceil(totalRatings / limit)
        },
        moyenne: moyenne,
        nombreNotes: nombre
      }
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des notes:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des notes',
      error: error.message
    });
  }
};

/**
 * @swagger
 * /api/ratings/user/{userId}:
 *   get:
 *     summary: Récupérer toutes les notes d'un utilisateur
 *     tags: [Ratings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: ID de l'utilisateur
 *     responses:
 *       200:
 *         description: Liste des notes récupérée avec succès
 */
exports.getRatingsByUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const currentUserId = req.user._id.toString();

    // Vérifier que l'utilisateur peut voir ses propres notes ou est admin
    if (userId !== currentUserId && !req.user.roles?.includes('admin')) {
      return res.status(403).json({
        success: false,
        message: 'Vous n\'êtes pas autorisé à voir les notes de cet utilisateur'
      });
    }

    const ratings = await Rating.find({ utilisateur: userId })
      .populate('balade', 'titre date heure typeVehicule')
      .sort({ dateNote: -1 });

    const formattedRatings = ratings.map(rating => ({
      id: rating._id,
      note: rating.note,
      commentaire: rating.commentaire,
      balade: {
        id: rating.balade._id,
        titre: rating.balade.titre,
        date: rating.balade.date,
        heure: rating.balade.heure,
        typeVehicule: rating.balade.typeVehicule
      },
      dateNote: rating.dateNote
    }));

    res.status(200).json({
      success: true,
      data: {
        ratings: formattedRatings,
        total: ratings.length
      }
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des notes:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des notes',
      error: error.message
    });
  }
};

/**
 * @swagger
 * /api/ratings/{ratingId}:
 *   get:
 *     summary: Récupérer une note spécifique
 *     tags: [Ratings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: ratingId
 *         required: true
 *         schema:
 *           type: string
 *         description: ID de la note
 *     responses:
 *       200:
 *         description: Note récupérée avec succès
 *       404:
 *         description: Note non trouvée
 */
exports.getRatingById = async (req, res) => {
  try {
    const { ratingId } = req.params;

    const rating = await Rating.findById(ratingId)
      .populate('utilisateur', 'firstName lastName pseudo email')
      .populate('balade', 'titre date heure typeVehicule');

    if (!rating) {
      return res.status(404).json({
        success: false,
        message: 'Note non trouvée'
      });
    }

    res.status(200).json({
      success: true,
      data: {
        rating: {
          id: rating._id,
          note: rating.note,
          commentaire: rating.commentaire,
          utilisateur: {
            id: rating.utilisateur._id,
            nom: rating.utilisateur.firstName && rating.utilisateur.lastName
              ? `${rating.utilisateur.firstName} ${rating.utilisateur.lastName}`
              : rating.utilisateur.pseudo || rating.utilisateur.email,
            pseudo: rating.utilisateur.pseudo
          },
          balade: {
            id: rating.balade._id,
            titre: rating.balade.titre,
            date: rating.balade.date,
            heure: rating.balade.heure,
            typeVehicule: rating.balade.typeVehicule
          },
          dateNote: rating.dateNote,
          createdAt: rating.createdAt
        }
      }
    });
  } catch (error) {
    console.error('Erreur lors de la récupération de la note:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération de la note',
      error: error.message
    });
  }
};



