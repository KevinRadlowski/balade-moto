const mongoose = require('mongoose');

const vehicleReminderSchema = new mongoose.Schema({
  vehicle: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Vehicle',
    required: [true, 'Le véhicule est requis'],
    index: true
  },
  owner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'Le propriétaire est requis'],
    index: true
  },
  maintenanceItem: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'MaintenanceItem',
    required: [true, 'L\'élément de maintenance est requis']
  },
  reminderKm: {
    type: Number,
    min: [0, 'Le kilométrage ne peut pas être négatif']
  },
  reminderDate: {
    type: Date
  },
  notified: {
    type: Boolean,
    default: false,
    index: true
  },
  notifiedAt: {
    type: Date
  }
}, {
  timestamps: true
});

// Index composé pour les requêtes fréquentes
vehicleReminderSchema.index({ vehicle: 1, notified: 1 });
vehicleReminderSchema.index({ owner: 1, notified: 1 });
vehicleReminderSchema.index({ vehicle: 1, owner: 1 });
vehicleReminderSchema.index({ maintenanceItem: 1 });

module.exports = mongoose.model('VehicleReminder', vehicleReminderSchema);

