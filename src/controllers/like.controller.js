const Like = require('../models/Like');
const Ride = require('../models/Ride');

/**
 * @swagger
 * /api/likes:
 *   post:
 *     summary: Liker ou unliker une balade (toggle)
 *     tags: [Likes]
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
 *             properties:
 *               balade:
 *                 type: string
 *                 description: ID de la balade à liker/unliker
 *     responses:
 *       200:
 *         description: Like/unlike réussi
 *       400:
 *         description: Erreur de validation
 *       401:
 *         description: Non authentifié
 *       404:
 *         description: Balade non trouvée
 */
exports.toggleLike = async (req, res) => {
  try {
    const { balade } = req.body;
    const utilisateur = req.user._id;

    if (!balade) {
      return res.status(400).json({
        success: false,
        message: 'L\'ID de la balade est requis'
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

    // Vérifier si l'utilisateur a déjà liké cette balade
    const existingLike = await Like.findOne({
      utilisateur,
      balade
    });

    let isLiked;
    let like;

    if (existingLike) {
      // Unliker : supprimer le like
      await Like.findByIdAndDelete(existingLike._id);
      isLiked = false;
    } else {
      // Liker : créer un nouveau like
      like = new Like({
        utilisateur,
        balade,
        dateLike: new Date()
      });
      await like.save();
      isLiked = true;
    }

    // Compter le nombre total de likes
    const totalLikes = await Like.countLikesByRide(balade);

    res.status(200).json({
      success: true,
      message: isLiked ? 'Balade likée avec succès' : 'Like retiré avec succès',
      data: {
        isLiked,
        totalLikes,
        balade: {
          id: ride._id,
          titre: ride.titre
        }
      }
    });
  } catch (error) {
    // Gérer les erreurs de contrainte unique (doublon)
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'Vous avez déjà liké cette balade'
      });
    }

    console.error('Erreur lors du toggle like:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'opération de like',
      error: error.message
    });
  }
};

/**
 * @swagger
 * /api/likes/ride/{rideId}:
 *   get:
 *     summary: Récupérer le nombre total de likes d'une balade
 *     tags: [Likes]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: rideId
 *         required: true
 *         schema:
 *           type: string
 *         description: ID de la balade
 *     responses:
 *       200:
 *         description: Nombre de likes récupéré avec succès
 *       404:
 *         description: Balade non trouvée
 */
exports.getLikesByRide = async (req, res) => {
  try {
    const { rideId } = req.params;
    const utilisateur = req.user._id;

    // Vérifier que la balade existe
    const ride = await Ride.findById(rideId);
    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Compter le nombre total de likes
    const totalLikes = await Like.countLikesByRide(rideId);

    // Vérifier si l'utilisateur actuel a liké cette balade
    const hasUserLiked = await Like.hasUserLiked(rideId, utilisateur);

    res.status(200).json({
      success: true,
      data: {
        balade: {
          id: ride._id,
          titre: ride.titre
        },
        totalLikes,
        hasUserLiked
      }
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des likes:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des likes',
      error: error.message
    });
  }
};

/**
 * @swagger
 * /api/likes/user/{userId}:
 *   get:
 *     summary: Récupérer toutes les balades likées par un utilisateur
 *     tags: [Likes]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: ID de l'utilisateur
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
 *         description: Liste des balades likées récupérée avec succès
 */
exports.getLikesByUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const currentUserId = req.user._id.toString();
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 10, 50);
    const skip = (page - 1) * limit;

    // Vérifier que l'utilisateur peut voir ses propres likes ou est admin
    if (userId !== currentUserId && !req.user.roles?.includes('admin')) {
      return res.status(403).json({
        success: false,
        message: 'Vous n\'êtes pas autorisé à voir les likes de cet utilisateur'
      });
    }

    // Récupérer les likes avec pagination
    const likes = await Like.find({ utilisateur: userId })
      .populate('balade', 'titre date heure typeVehicule organisateur')
      .sort({ dateLike: -1 })
      .skip(skip)
      .limit(limit);

    // Compter le total
    const totalLikes = await Like.countDocuments({ utilisateur: userId });

    // Formater la réponse
    const formattedLikes = likes.map(like => ({
      id: like._id,
      balade: {
        id: like.balade._id,
        titre: like.balade.titre,
        date: like.balade.date,
        heure: like.balade.heure,
        typeVehicule: like.balade.typeVehicule
      },
      dateLike: like.dateLike
    }));

    res.status(200).json({
      success: true,
      data: {
        likes: formattedLikes,
        pagination: {
          page,
          limit,
          total: totalLikes,
          totalPages: Math.ceil(totalLikes / limit)
        }
      }
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des likes:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des likes',
      error: error.message
    });
  }
};



