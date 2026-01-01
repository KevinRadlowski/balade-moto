const Review = require('../models/Review');
const Ride = require('../models/Ride');

// Créer ou mettre à jour une review
exports.createOrUpdateReview = async (req, res) => {
  try {
    const { rideId } = req.params;
    const { rating, comment } = req.body;

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'La note doit être entre 1 et 5'
      });
    }

    const ride = await Ride.findById(rideId);
    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier que la balade est passée
    const rideDate = new Date(ride.date);
    const rideDateTime = new Date(rideDate);
    const [hours, minutes] = ride.heure.split(':');
    rideDateTime.setHours(parseInt(hours), parseInt(minutes), 0, 0);
    
    if (rideDateTime > new Date()) {
      return res.status(400).json({
        success: false,
        message: 'Vous ne pouvez noter que les balades passées'
      });
    }

    // Vérifier que l'utilisateur a participé à la balade
    const isParticipant = ride.participants.some(
      p => p.toString() === req.user._id.toString()
    );
    const isOrganizer = ride.organisateur.toString() === req.user._id.toString();

    if (!isParticipant && !isOrganizer) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez avoir participé à cette balade pour la noter'
      });
    }

    // Chercher une review existante
    let review = await Review.findOne({ ride: rideId, user: req.user._id });

    if (review) {
      // Mettre à jour la review existante
      review.rating = rating;
      review.comment = comment || '';
      await review.save();
    } else {
      // Créer une nouvelle review
      review = new Review({
        ride: rideId,
        user: req.user._id,
        rating: rating,
        comment: comment || ''
      });
      await review.save();
    }

    await review.populate('user', 'pseudo email avatarUrl');

    res.status(200).json({
      success: true,
      message: 'Review enregistrée avec succès',
      data: { review }
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({
        success: false,
        message: 'Vous avez déjà noté cette balade'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'enregistrement de la review',
      error: error.message
    });
  }
};

// Récupérer les reviews d'une balade
exports.getRideReviews = async (req, res) => {
  try {
    const { rideId } = req.params;

    const reviews = await Review.find({ ride: rideId })
      .populate('user', 'pseudo email avatarUrl')
      .sort({ createdAt: -1 });

    const ratingStats = await Review.getAverageRating(rideId);

    res.status(200).json({
      success: true,
      data: {
        reviews,
        ratingStats
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des reviews',
      error: error.message
    });
  }
};

// Vérifier si l'utilisateur a déjà noté une balade
exports.hasUserReviewed = async (req, res) => {
  try {
    const { rideId } = req.params;

    const hasReviewed = await Review.hasUserReviewed(rideId, req.user._id);
    let review = null;

    if (hasReviewed) {
      review = await Review.findOne({ ride: rideId, user: req.user._id })
        .populate('user', 'pseudo email avatarUrl');
    }

    res.status(200).json({
      success: true,
      data: {
        hasReviewed,
        review
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la vérification',
      error: error.message
    });
  }
};

