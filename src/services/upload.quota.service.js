/**
 * Service pour gérer les quotas d'upload
 */

const UploadUsage = require('../models/UploadUsage');
const { BadRequestError } = require('../utils/errors');

/**
 * Types d'upload et leurs limites par défaut
 */
const DEFAULT_LIMITS = {
  image: {
    maxFiles: parseInt(process.env.UPLOAD_QUOTA_IMAGES_PER_USER || '100', 10),
    maxSizeMB: parseInt(process.env.UPLOAD_QUOTA_IMAGES_MB_PER_MONTH || '500', 10)
  },
  document: {
    maxFiles: parseInt(process.env.UPLOAD_QUOTA_DOCUMENTS_PER_USER || '50', 10),
    maxSizeMB: parseInt(process.env.UPLOAD_QUOTA_DOCUMENTS_MB_PER_MONTH || '200', 10)
  },
  video: {
    maxFiles: parseInt(process.env.UPLOAD_QUOTA_VIDEOS_PER_USER || '20', 10),
    maxSizeMB: parseInt(process.env.UPLOAD_QUOTA_VIDEOS_MB_PER_MONTH || '1000', 10)
  },
  audio: {
    maxFiles: parseInt(process.env.UPLOAD_QUOTA_AUDIO_PER_USER || '30', 10),
    maxSizeMB: parseInt(process.env.UPLOAD_QUOTA_AUDIO_MB_PER_MONTH || '300', 10)
  },
  other: {
    maxFiles: parseInt(process.env.UPLOAD_QUOTA_OTHER_PER_USER || '50', 10),
    maxSizeMB: parseInt(process.env.UPLOAD_QUOTA_OTHER_MB_PER_MONTH || '200', 10)
  }
};

/**
 * Détermine le type d'upload à partir du mimetype ou de l'extension
 * @param {string} mimetype - MIME type du fichier
 * @param {string} extension - Extension du fichier
 * @returns {string} Type d'upload ('image', 'document', 'video', 'audio', 'other')
 */
function determineUploadType(mimetype, extension) {
  if (mimetype) {
    if (mimetype.startsWith('image/')) return 'image';
    if (mimetype.startsWith('video/')) return 'video';
    if (mimetype.startsWith('audio/')) return 'audio';
    if (mimetype.includes('pdf') || mimetype.includes('document') || mimetype.includes('msword') || mimetype.includes('spreadsheet')) {
      return 'document';
    }
  }
  
  if (extension) {
    const ext = extension.toLowerCase();
    const imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    const videoExts = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    const audioExts = ['.mp3', '.wav', '.ogg', '.m4a', '.aac'];
    const docExts = ['.pdf', '.txt', '.doc', '.docx', '.xls', '.xlsx'];
    
    if (imageExts.includes(ext)) return 'image';
    if (videoExts.includes(ext)) return 'video';
    if (audioExts.includes(ext)) return 'audio';
    if (docExts.includes(ext)) return 'document';
  }
  
  return 'other';
}

/**
 * Vérifie si un utilisateur peut uploader un fichier
 * @param {string} userId - ID de l'utilisateur
 * @param {number} fileSize - Taille du fichier en bytes
 * @param {string} mimetype - MIME type du fichier
 * @param {string} extension - Extension du fichier
 * @param {object} customLimits - Limites personnalisées (optionnel)
 * @returns {Promise<void>} Lance une erreur si quota dépassé
 */
async function checkQuota(userId, fileSize, mimetype, extension, customLimits = null) {
  const uploadType = determineUploadType(mimetype, extension);
  const limits = customLimits || DEFAULT_LIMITS[uploadType] || DEFAULT_LIMITS.other;
  
  const quotaCheck = await UploadUsage.checkQuota(userId, uploadType, fileSize, limits);
  
  if (!quotaCheck.allowed) {
    throw new BadRequestError(quotaCheck.reason || 'Quota d\'upload dépassé');
  }
  
  return { uploadType, limits };
}

/**
 * Enregistre un upload dans les statistiques
 * @param {string} userId - ID de l'utilisateur
 * @param {number} fileSize - Taille du fichier en bytes
 * @param {string} uploadType - Type d'upload
 * @returns {Promise<object>} Document UploadUsage mis à jour
 */
async function recordUpload(userId, fileSize, uploadType) {
  return await UploadUsage.incrementUsage(userId, uploadType, fileSize);
}

/**
 * Récupère l'utilisation actuelle d'un utilisateur
 * @param {string} userId - ID de l'utilisateur
 * @param {string} uploadType - Type d'upload (optionnel)
 * @returns {Promise<object>} Utilisation
 */
async function getUsage(userId, uploadType = null) {
  return await UploadUsage.getUsage(userId, uploadType);
}

/**
 * Réinitialise les quotas (pour tests ou admin)
 * @param {string} userId - ID de l'utilisateur
 * @param {string} uploadType - Type d'upload (optionnel)
 * @returns {Promise<void>}
 */
async function resetQuota(userId, uploadType = null) {
  const now = new Date();
  const period = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  
  const query = { userId, period };
  if (uploadType) {
    query.uploadType = uploadType;
  }
  
  await UploadUsage.deleteMany(query);
}

module.exports = {
  checkQuota,
  recordUpload,
  getUsage,
  resetQuota,
  determineUploadType,
  DEFAULT_LIMITS
};

