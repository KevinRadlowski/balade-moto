const mongoose = require('mongoose');

const reviewSchema = new mongoose.Schema({
  ride: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    required: [true, 'La balade est requise'],
    index: true
  },
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'L\'utilisateur est requis'],
    index: true
  },
  rating: {
    type: Number,
    required: [true, 'La note est requise'],
    min: [1, 'La note doit être au moins 1'],
    max: [5, 'La note ne peut pas dépasser 5']
  },
  comment: {
    type: String,
    trim: true,
    maxlength: [1000, 'Le commentaire ne peut pas dépasser 1000 caractères']
  }
}, {
  timestamps: true
});

// Index composé pour éviter les doublons (un utilisateur ne peut noter qu'une fois par balade)
reviewSchema.index({ ride: 1, user: 1 }, { unique: true });

// Méthode statique pour calculer la note moyenne d'une balade
reviewSchema.statics.getAverageRating = async function(rideId) {
  const result = await this.aggregate([
    { $match: { ride: new mongoose.Types.ObjectId(rideId) } },
    { $group: { _id: null, average: { $avg: '$rating' }, count: { $sum: 1 } } }
  ]);
  
  if (result.length === 0) {
    return { average: 0, count: 0 };
  }
  
  return {
    average: Math.round(result[0].average * 10) / 10, // Arrondir à 1 décimale
    count: result[0].count
  };
};

// Méthode statique pour vérifier si un utilisateur a déjà noté une balade
reviewSchema.statics.hasUserReviewed = async function(rideId, userId) {
  const review = await this.findOne({ ride: rideId, user: userId });
  return !!review;
};

module.exports = mongoose.model('Review', reviewSchema);

