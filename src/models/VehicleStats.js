const mongoose = require('mongoose');

const monthlyStatSchema = new mongoose.Schema({
  month: {
    type: String,
    required: true,
    match: [/^\d{4}-\d{2}$/, 'Le format du mois doit être YYYY-MM']
  },
  km: {
    type: Number,
    default: 0,
    min: [0, 'Le kilométrage ne peut pas être négatif']
  },
  cost: {
    type: Number,
    default: 0,
    min: [0, 'Le coût ne peut pas être négatif']
  },
  rides: {
    type: Number,
    default: 0,
    min: [0, 'Le nombre de balades ne peut pas être négatif']
  }
}, { _id: false });

const vehicleStatsSchema = new mongoose.Schema({
  vehicleId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Vehicle',
    required: [true, 'Le véhicule est requis'],
    unique: true,
    index: true
  },
  totalKm: {
    type: Number,
    default: 0,
    min: [0, 'Le kilométrage total ne peut pas être négatif']
  },
  totalCost: {
    type: Number,
    default: 0,
    min: [0, 'Le coût total ne peut pas être négatif']
  },
  rideCount: {
    type: Number,
    default: 0,
    min: [0, 'Le nombre de balades ne peut pas être négatif']
  },
  maintenanceCount: {
    type: Number,
    default: 0,
    min: [0, 'Le nombre d\'entretiens ne peut pas être négatif']
  },
  fuelConsumption: {
    averageLitersPer100km: {
      type: Number,
      default: null,
      min: [0, 'La consommation ne peut pas être négative']
    },
    lastUpdated: {
      type: Date,
      default: null
    }
  },
  monthlyStats: {
    type: [monthlyStatSchema],
    default: []
  }
}, {
  timestamps: true
});

// Index pour améliorer les performances
vehicleStatsSchema.index({ vehicleId: 1 });
vehicleStatsSchema.index({ totalKm: -1 });
vehicleStatsSchema.index({ rideCount: -1 });

module.exports = mongoose.model('VehicleStats', vehicleStatsSchema);


