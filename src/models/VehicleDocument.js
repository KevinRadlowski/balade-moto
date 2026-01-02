const mongoose = require('mongoose');

const vehicleDocumentSchema = new mongoose.Schema({
  vehicleId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Vehicle',
    required: [true, 'Le véhicule est requis'],
    index: true
  },
  ownerUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'Le propriétaire est requis'],
    index: true
  },
  type: {
    type: String,
    required: [true, 'Le type de document est requis'],
    enum: {
      values: ['ASSURANCE', 'CT', 'FACTURE', 'AUTRE'],
      message: 'Le type doit être ASSURANCE, CT, FACTURE ou AUTRE'
    },
    index: true
  },
  label: {
    type: String,
    required: [true, 'Le libellé est requis'],
    trim: true,
    maxlength: [200, 'Le libellé ne peut pas dépasser 200 caractères']
  },
  fileUrl: {
    type: String,
    required: [true, 'L\'URL du fichier est requise'],
    trim: true,
    maxlength: [500, 'L\'URL ne peut pas dépasser 500 caractères']
  },
  date: {
    type: Date,
    required: [true, 'La date est requise'],
    default: Date.now
  },
  notes: {
    type: String,
    trim: true,
    maxlength: [500, 'Les notes ne peuvent pas dépasser 500 caractères']
  }
}, {
  timestamps: true
});

vehicleDocumentSchema.index({ vehicleId: 1, type: 1 });
vehicleDocumentSchema.index({ ownerUserId: 1 });
vehicleDocumentSchema.index({ vehicleId: 1, date: -1 });

module.exports = mongoose.model('VehicleDocument', vehicleDocumentSchema);

