const mongoose = require('mongoose');

const ratingSchema = new mongoose.Schema({
  note: {
    type: Number,
    required: [true, 'La note est requise'],
    min: [1, 'La note doit être entre 1 et 5'],
    max: [5, 'La note doit être entre 1 et 5'],
    validate: {
      validator: Number.isInteger,
      message: 'La note doit être un nombre entier'
    }
  },
  commentaire: {
    type: String,
    trim: true,
    maxlength: [1000, 'Le commentaire ne peut pas dépasser 1000 caractères'],
    default: null
  },
  utilisateur: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'L\'utilisateur est requis']
  },
  balade: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    required: [true, 'La balade est requise']
  },
  dateNote: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index unique pour empêcher qu'un utilisateur note une balade plusieurs fois
ratingSchema.index({ utilisateur: 1, balade: 1 }, { unique: true });

// Index pour améliorer les performances de recherche
ratingSchema.index({ balade: 1, dateNote: -1 });
// Note: L'index sur utilisateur est déjà couvert par l'index composé unique ci-dessus

// Méthode statique pour calculer la moyenne des notes d'une balade
ratingSchema.statics.calculateAverageRating = async function(rideId) {
  const result = await this.aggregate([
    { $match: { balade: new mongoose.Types.ObjectId(rideId) } },
    {
      $group: {
        _id: null,
        moyenne: { $avg: '$note' },
        nombre: { $sum: 1 }
      }
    }
  ]);

  if (result.length === 0) {
    return { moyenne: 0, nombre: 0 };
  }

  return {
    moyenne: Math.round(result[0].moyenne * 10) / 10, // Arrondi à 1 décimale
    nombre: result[0].nombre
  };
};

// Méthode pour formater la réponse
ratingSchema.methods.toJSON = function() {
  const obj = this.toObject();
  obj.id = obj._id;
  delete obj._id;
  delete obj.__v;
  return obj;
};

module.exports = mongoose.model('Rating', ratingSchema);

