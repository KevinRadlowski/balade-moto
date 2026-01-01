const mongoose = require('mongoose');

const likeSchema = new mongoose.Schema({
  utilisateur: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'L\'utilisateur est requis']
    // index: true retiré car déjà couvert par l'index composé ci-dessous
  },
  balade: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    required: [true, 'La balade est requise']
    // index: true retiré car déjà couvert par l'index composé ci-dessous
  },
  dateLike: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index unique pour empêcher qu'un utilisateur like une balade plusieurs fois
likeSchema.index({ utilisateur: 1, balade: 1 }, { unique: true });

// Index pour améliorer les performances de recherche
likeSchema.index({ balade: 1, dateLike: -1 });
// Note: L'index sur utilisateur est déjà couvert par l'index composé unique ci-dessus

// Méthode statique pour compter les likes d'une balade
likeSchema.statics.countLikesByRide = async function(rideId) {
  return await this.countDocuments({ balade: rideId });
};

// Méthode statique pour vérifier si un utilisateur a liké une balade
likeSchema.statics.hasUserLiked = async function(rideId, userId) {
  const like = await this.findOne({
    balade: rideId,
    utilisateur: userId
  });
  return like !== null;
};

// Méthode pour formater la réponse
likeSchema.methods.toJSON = function() {
  const obj = this.toObject();
  obj.id = obj._id;
  delete obj._id;
  delete obj.__v;
  return obj;
};

module.exports = mongoose.model('Like', likeSchema);

