const mongoose = require('mongoose');

const achievementSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'L\'utilisateur est requis'],
    index: true
  },
  type: {
    type: String,
    required: [true, 'Le type de badge est requis'],
    enum: [
      'first_ride',
      'five_rides',
      'ten_rides',
      'twenty_five_rides',
      'fifty_rides',
      'hundred_rides',
      'organizer',
      'five_organizer',
      'regular_organizer',
      'punctual',
      'social',
      'social_butterfly',
      'explorer',
      'city_explorer',
      'early_adopter',
      'trusted_rider',
      'first_maintenance',
      'maintenance_master',
      'maintenance_expert',
      'first_document',
      'document_collector',
      'first_photo',
      'photo_enthusiast',
      'photo_gallery',
      'reliable_rider',
      'highly_trusted',
      'profile_complete'
    ],
    index: true
  },
  name: {
    type: String,
    required: [true, 'Le nom du badge est requis'],
    trim: true,
    maxlength: [100, 'Le nom ne peut pas dépasser 100 caractères']
  },
  description: {
    type: String,
    trim: true,
    maxlength: [500, 'La description ne peut pas dépasser 500 caractères']
  },
  earnedAt: {
    type: Date,
    default: Date.now,
    index: true
  },
  progress: {
    type: Number,
    default: 0,
    min: [0, 'La progression ne peut pas être négative']
  },
  target: {
    type: Number,
    default: 100,
    min: [0, 'La cible ne peut pas être négative']
  }
}, {
  timestamps: true
});

// Index composé pour éviter les doublons (un utilisateur ne peut avoir qu'un badge de chaque type)
achievementSchema.index({ userId: 1, type: 1 }, { unique: true });

// Index pour améliorer les performances
achievementSchema.index({ userId: 1, earnedAt: -1 });

module.exports = mongoose.model('Achievement', achievementSchema);

