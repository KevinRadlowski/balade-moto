const mongoose = require('mongoose');

const odometerEntrySchema = new mongoose.Schema({
  vehicleId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Vehicle',
    required: [true, 'Le véhicule est requis'],
    index: true
  },
  date: {
    type: Date,
    required: [true, 'La date est requise'],
    default: Date.now,
    index: true
  },
  km: {
    type: Number,
    required: [true, 'Le kilométrage est requis'],
    min: [0, 'Le kilométrage ne peut pas être négatif']
  },
  note: {
    type: String,
    trim: true,
    maxlength: [500, 'La note ne peut pas dépasser 500 caractères']
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'Le créateur est requis'],
    index: true
  }
}, {
  timestamps: true
});

// Index composé pour les requêtes fréquentes
odometerEntrySchema.index({ vehicleId: 1, date: -1 });
odometerEntrySchema.index({ createdBy: 1, date: -1 });
odometerEntrySchema.index({ vehicleId: 1, createdBy: 1 });

// Virtuals pour compatibilité avec l'ancien code
odometerEntrySchema.virtual('vehicle').get(function() {
  return this.vehicleId;
});

odometerEntrySchema.virtual('vehicle').set(function(value) {
  this.vehicleId = value;
});

odometerEntrySchema.virtual('owner').get(function() {
  return this.createdBy;
});

odometerEntrySchema.virtual('owner').set(function(value) {
  this.createdBy = value;
});

odometerEntrySchema.virtual('notes').get(function() {
  return this.note;
});

odometerEntrySchema.virtual('notes').set(function(value) {
  this.note = value;
});

odometerEntrySchema.set('toJSON', { virtuals: true });
odometerEntrySchema.set('toObject', { virtuals: true });

// Validation : le kilométrage doit être supérieur ou égal au précédent
odometerEntrySchema.pre('save', async function(next) {
  if (this.isNew) {
    const Vehicle = mongoose.model('Vehicle');
    const vehicle = await Vehicle.findById(this.vehicleId);
    
    if (!vehicle) {
      return next(new Error('Véhicule non trouvé'));
    }
    
    // Vérifier que le nouveau kilométrage est >= au kilométrage actuel du véhicule
    if (this.km < vehicle.odometerCurrentKm) {
      return next(new Error('Le kilométrage ne peut pas être inférieur au kilométrage actuel du véhicule'));
    }
    
    // Mettre à jour le kilométrage actuel du véhicule
    await Vehicle.findByIdAndUpdate(this.vehicleId, {
      odometerCurrentKm: this.km
    });
  }
  
  next();
});

module.exports = mongoose.model('OdometerEntry', odometerEntrySchema);
