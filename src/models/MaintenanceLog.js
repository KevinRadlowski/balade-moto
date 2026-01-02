const mongoose = require('mongoose');

const maintenanceLogSchema = new mongoose.Schema({
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
  date: {
    type: Date,
    required: [true, 'La date est requise'],
    default: Date.now,
    index: true
  },
  kmAtService: {
    type: Number,
    required: [true, 'Le kilométrage au moment du service est requis'],
    min: [0, 'Le kilométrage ne peut pas être négatif']
  },
  cost: {
    type: Number,
    min: [0, 'Le coût ne peut pas être négatif'],
    default: 0
  },
  garageName: {
    type: String,
    trim: true,
    maxlength: [100, 'Le nom du garage ne peut pas dépasser 100 caractères']
  },
  invoiceFileUrl: {
    type: String,
    trim: true,
    maxlength: [500, 'L\'URL du fichier ne peut pas dépasser 500 caractères']
  },
  notes: {
    type: String,
    trim: true,
    maxlength: [1000, 'Les notes ne peuvent pas dépasser 1000 caractères']
  }
}, {
  timestamps: true
});

// Index composé pour les requêtes fréquentes
maintenanceLogSchema.index({ vehicleId: 1, date: -1 });
maintenanceLogSchema.index({ vehicleId: 1, category: 1 });
maintenanceLogSchema.index({ vehicleId: 1, date: -1, category: 1 });

// Virtuals pour compatibilité avec l'ancien code
maintenanceLogSchema.virtual('vehicle').get(function() {
  return this.vehicleId;
});

maintenanceLogSchema.virtual('vehicle').set(function(value) {
  this.vehicleId = value;
});

maintenanceLogSchema.virtual('type').get(function() {
  return this.category;
});

maintenanceLogSchema.virtual('type').set(function(value) {
  this.category = value;
});

maintenanceLogSchema.virtual('description').get(function() {
  return this.label;
});

maintenanceLogSchema.virtual('description').set(function(value) {
  this.label = value;
});

maintenanceLogSchema.virtual('km').get(function() {
  return this.kmAtService;
});

maintenanceLogSchema.virtual('km').set(function(value) {
  this.kmAtService = value;
});

maintenanceLogSchema.set('toJSON', { virtuals: true });
maintenanceLogSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('MaintenanceLog', maintenanceLogSchema);
