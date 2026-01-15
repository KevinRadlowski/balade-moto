const mongoose = require('mongoose');

/**
 * Modèle pour suivre l'utilisation des uploads par utilisateur
 * Permet de gérer les quotas (nombre de fichiers, taille totale, etc.)
 */
const uploadUsageSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  // Mois/année pour le calcul mensuel (format: YYYY-MM)
  period: {
    type: String,
    required: true,
    index: true
  },
  // Type d'upload (image, document, video, etc.)
  uploadType: {
    type: String,
    required: true,
    enum: ['image', 'document', 'video', 'audio', 'other'],
    index: true
  },
  // Nombre de fichiers uploadés ce mois
  fileCount: {
    type: Number,
    default: 0,
    min: 0
  },
  // Taille totale en bytes
  totalSize: {
    type: Number,
    default: 0,
    min: 0
  },
  // Dernière mise à jour
  lastUploadAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index composé pour requêtes rapides
uploadUsageSchema.index({ userId: 1, period: 1, uploadType: 1 }, { unique: true });

/**
 * Incrémente l'utilisation pour un utilisateur
 * @param {string} userId - ID de l'utilisateur
 * @param {string} uploadType - Type d'upload
 * @param {number} fileSize - Taille du fichier en bytes
 * @returns {Promise<object>} Document UploadUsage mis à jour
 */
uploadUsageSchema.statics.incrementUsage = async function(userId, uploadType, fileSize) {
  const now = new Date();
  const period = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  
  return await this.findOneAndUpdate(
    { userId, period, uploadType },
    {
      $inc: {
        fileCount: 1,
        totalSize: fileSize
      },
      $set: {
        lastUploadAt: now
      }
    },
    {
      upsert: true,
      new: true
    }
  );
};

/**
 * Récupère l'utilisation actuelle pour un utilisateur
 * @param {string} userId - ID de l'utilisateur
 * @param {string} uploadType - Type d'upload (optionnel)
 * @returns {Promise<object>} Utilisation totale ou par type
 */
uploadUsageSchema.statics.getUsage = async function(userId, uploadType = null) {
  const now = new Date();
  const period = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  
  const query = { userId, period };
  if (uploadType) {
    query.uploadType = uploadType;
  }
  
  if (uploadType) {
    // Retourner un seul document
    return await this.findOne(query);
  } else {
    // Retourner tous les types pour cet utilisateur
    return await this.find(query);
  }
};

/**
 * Vérifie si un utilisateur peut uploader (quota non dépassé)
 * @param {string} userId - ID de l'utilisateur
 * @param {string} uploadType - Type d'upload
 * @param {number} fileSize - Taille du fichier en bytes
 * @param {object} limits - Limites { maxFiles, maxSizeMB }
 * @returns {Promise<{allowed: boolean, reason?: string, current?: object}>}
 */
uploadUsageSchema.statics.checkQuota = async function(userId, uploadType, fileSize, limits) {
  const usage = await this.getUsage(userId, uploadType);
  
  // Si pas d'utilisation, autoriser
  if (!usage) {
    return { allowed: true };
  }
  
  // Vérifier nombre de fichiers
  if (limits.maxFiles && usage.fileCount >= limits.maxFiles) {
    return {
      allowed: false,
      reason: `Quota de fichiers atteint: ${usage.fileCount}/${limits.maxFiles}`,
      current: {
        fileCount: usage.fileCount,
        totalSizeMB: (usage.totalSize / (1024 * 1024)).toFixed(2)
      }
    };
  }
  
  // Vérifier taille totale
  const maxSizeBytes = limits.maxSizeMB ? limits.maxSizeMB * 1024 * 1024 : null;
  if (maxSizeBytes && usage.totalSize >= maxSizeBytes) {
    return {
      allowed: false,
      reason: `Quota de taille atteint: ${(usage.totalSize / (1024 * 1024)).toFixed(2)}MB/${limits.maxSizeMB}MB`,
      current: {
        fileCount: usage.fileCount,
        totalSizeMB: (usage.totalSize / (1024 * 1024)).toFixed(2)
      }
    };
  }
  
  // Vérifier si le nouveau fichier dépasserait la limite
  if (maxSizeBytes && (usage.totalSize + fileSize) > maxSizeBytes) {
    return {
      allowed: false,
      reason: `Upload refusé: dépasserait la limite de ${limits.maxSizeMB}MB`,
      current: {
        fileCount: usage.fileCount,
        totalSizeMB: (usage.totalSize / (1024 * 1024)).toFixed(2)
      }
    };
  }
  
  return { allowed: true, current: usage };
};

module.exports = mongoose.model('UploadUsage', uploadUsageSchema);

