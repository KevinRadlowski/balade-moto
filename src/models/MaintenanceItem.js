const mongoose = require('mongoose');

const maintenanceItemSchema = new mongoose.Schema({
  vehicleId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Vehicle',
    required: [true, 'Le véhicule est requis'],
    index: true
  },
  label: {
    type: String,
    required: [true, 'Le libellé est requis'],
    trim: true,
    maxlength: [200, 'Le libellé ne peut pas dépasser 200 caractères']
  },
  category: {
    type: String,
    required: [true, 'La catégorie est requise'],
    enum: {
      values: [
        'vidange',
        'filtre_huile',
        'filtre_air',
        'filtre_essence',
        'bougies',
        'freins',
        'pneus',
        'batterie',
        'chaines',
        'liquide_refroidissement',
        'liquide_freins',
        'revision',
        'autre'
      ],
      message: 'Catégorie de maintenance invalide'
    },
    index: true
  },
  intervalKm: {
    type: Number,
    min: [0, 'L\'intervalle kilométrique ne peut pas être négatif']
  },
  intervalMonths: {
    type: Number,
    min: [0, 'L\'intervalle en mois ne peut pas être négatif']
  },
  lastDoneAtKm: {
    type: Number,
    min: [0, 'Le kilométrage ne peut pas être négatif']
  },
  lastDoneAtDate: {
    type: Date
  },
  dueAtKm: {
    type: Number,
    min: [0, 'Le kilométrage ne peut pas être négatif'],
    index: true
  },
  dueAtDate: {
    type: Date,
    index: true
  },
  status: {
    type: String,
    enum: {
      values: ['DUE', 'UPCOMING', 'DONE', 'SKIPPED'],
      message: 'Statut invalide'
    },
    default: 'UPCOMING',
    index: true
  },
  notes: {
    type: String,
    trim: true,
    maxlength: [1000, 'Les notes ne peuvent pas dépasser 1000 caractères']
  },
  active: {
    type: Boolean,
    default: true,
    index: true
  }
}, {
  timestamps: true
});

// Index composé pour les requêtes fréquentes
maintenanceItemSchema.index({ vehicleId: 1, active: 1 });
maintenanceItemSchema.index({ vehicleId: 1, status: 1 });
maintenanceItemSchema.index({ vehicleId: 1, dueAtKm: 1 });
maintenanceItemSchema.index({ vehicleId: 1, dueAtDate: 1 });
maintenanceItemSchema.index({ vehicleId: 1, category: 1 });

// Virtuals pour compatibilité avec l'ancien code
maintenanceItemSchema.virtual('vehicle').get(function() {
  return this.vehicleId;
});

maintenanceItemSchema.virtual('vehicle').set(function(value) {
  this.vehicleId = value;
});

maintenanceItemSchema.virtual('type').get(function() {
  return this.category;
});

maintenanceItemSchema.virtual('type').set(function(value) {
  this.category = value;
});

maintenanceItemSchema.virtual('name').get(function() {
  return this.label;
});

maintenanceItemSchema.virtual('name').set(function(value) {
  this.label = value;
});

maintenanceItemSchema.virtual('intervalDays').get(function() {
  return this.intervalMonths ? this.intervalMonths * 30 : null;
});

maintenanceItemSchema.virtual('intervalDays').set(function(value) {
  this.intervalMonths = value ? Math.round(value / 30) : null;
});

maintenanceItemSchema.set('toJSON', { virtuals: true });
maintenanceItemSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('MaintenanceItem', maintenanceItemSchema);
