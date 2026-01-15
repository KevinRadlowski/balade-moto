const mongoose = require('mongoose');

const dangerReportSchema = new mongoose.Schema({
  rideId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
    required: [true, 'L\'ID de la balade est requis'],
    index: true
  },
  reportedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'L\'utilisateur qui signale est requis'],
    index: true
  },
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point'
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: true,
      validate: {
        validator: function(coords) {
          return coords.length === 2 && 
                 coords[0] >= -180 && coords[0] <= 180 && 
                 coords[1] >= -90 && coords[1] <= 90;
        },
        message: 'Les coordonnées doivent être [longitude, latitude]'
      }
    }
  },
  description: {
    type: String,
    required: [true, 'La description du danger est requise'],
    maxlength: [500, 'La description ne peut pas dépasser 500 caractères'],
    trim: true
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected', 'promoted'],
    default: 'pending',
    index: true
  },
  approvedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  approvedAt: {
    type: Date,
    default: null
  },
  promotedToWaypointId: {
    type: mongoose.Schema.Types.ObjectId,
    default: null
  }
}, {
  timestamps: true
});

// Index pour éviter doublons (même user, même zone)
// Note: On utilise un index géospatial pour détecter les rapports proches
dangerReportSchema.index({ rideId: 1, status: 1 });
dangerReportSchema.index({ rideId: 1, reportedBy: 1 });
dangerReportSchema.index({ location: '2dsphere' });

// Index pour les requêtes fréquentes
dangerReportSchema.index({ status: 1, createdAt: -1 });

const DangerReport = mongoose.model('DangerReport', dangerReportSchema);

module.exports = DangerReport;

