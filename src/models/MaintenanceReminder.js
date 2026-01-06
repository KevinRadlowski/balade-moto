const mongoose = require('mongoose');

const reminderNotificationSchema = new mongoose.Schema({
  sentAt: {
    type: Date,
    default: Date.now
  },
  type: {
    type: String,
    enum: ['email', 'push', 'sms'],
    default: 'email'
  },
  status: {
    type: String,
    enum: ['sent', 'failed', 'pending'],
    default: 'sent'
  }
}, { _id: false });

const maintenanceReminderSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'L\'utilisateur est requis'],
    index: true
  },
  vehicleId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Vehicle',
    required: [true, 'Le véhicule est requis'],
    index: true
  },
  type: {
    type: String,
    required: [true, 'Le type d\'entretien est requis'],
    enum: ['oil', 'tire', 'brake', 'inspection', 'filter', 'battery', 'coolant', 'other'],
    index: true
  },
  description: {
    type: String,
    trim: true,
    maxlength: [500, 'La description ne peut pas dépasser 500 caractères']
  },
  intervalKm: {
    type: Number,
    min: [0, 'L\'intervalle en km ne peut pas être négatif']
  },
  intervalMonths: {
    type: Number,
    min: [0, 'L\'intervalle en mois ne peut pas être négatif']
  },
  lastDoneKm: {
    type: Number,
    default: null,
    min: [0, 'Le kilométrage ne peut pas être négatif']
  },
  lastDoneDate: {
    type: Date,
    default: null
  },
  nextDueKm: {
    type: Number,
    default: null,
    min: [0, 'Le kilométrage ne peut pas être négatif']
  },
  nextDueDate: {
    type: Date,
    default: null,
    index: true
  },
  status: {
    type: String,
    enum: ['active', 'snoozed', 'completed', 'cancelled'],
    default: 'active',
    index: true
  },
  snoozedUntil: {
    type: Date,
    default: null
  },
  notifications: {
    type: [reminderNotificationSchema],
    default: []
  }
}, {
  timestamps: true
});

// Index pour améliorer les performances
maintenanceReminderSchema.index({ userId: 1, vehicleId: 1 });
maintenanceReminderSchema.index({ status: 1, nextDueDate: 1 });
maintenanceReminderSchema.index({ nextDueDate: 1 }); // Pour les jobs cron

module.exports = mongoose.model('MaintenanceReminder', maintenanceReminderSchema);





