/**
 * Middleware d'upload sécurisé avec quotas et StorageProvider
 * Exemple d'utilisation pour remplacer progressivement les middlewares existants
 */

const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { fileTypeFromBuffer } = require('file-type');
const { createStorageProvider } = require('../services/storage.provider');
const { checkQuota, recordUpload } = require('../services/upload.quota.service');
const { BadRequestError } = require('../utils/errors');

// Initialiser le StorageProvider
const storageProvider = createStorageProvider();

// Configuration multer en mémoire (on utilisera StorageProvider pour sauvegarder)
const storage = multer.memoryStorage();

// Extensions interdites explicitement (sécurité)
const forbiddenExtensions = [
  '.html', '.htm', '.js', '.jsx', '.ts', '.tsx',
  '.svg', '.xml', '.exe', '.bat', '.cmd', '.ps1', '.sh', '.bash',
  '.php', '.asp', '.jsp', '.py', '.rb', '.pl',
  '.jar', '.war', '.ear', '.dll', '.so', '.dylib',
  '.deb', '.rpm', '.msi', '.app', '.apk', '.ipa'
];

/**
 * Crée un middleware d'upload sécurisé
 * @param {object} options - Options de configuration
 * @param {string} options.fieldName - Nom du champ dans le formulaire (ex: 'avatar', 'file')
 * @param {string} options.category - Catégorie pour le stockage (ex: 'avatars', 'messages')
 * @param {number} options.maxSizeMB - Taille max en MB
 * @param {string[]} options.allowedExtensions - Extensions autorisées
 * @param {string[]} options.allowedMimeTypes - MIME types autorisés
 * @param {object} options.customLimits - Limites de quota personnalisées (optionnel)
 * @returns {Function} Middleware Express
 */
function createSecureUploadMiddleware(options) {
  const {
    fieldName = 'file',
    category = 'uploads',
    maxSizeMB = 5,
    allowedExtensions = ['.jpeg', '.jpg', '.png', '.gif', '.webp'],
    allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'],
    customLimits = null
  } = options;

  // Filtre de fichier
  const fileFilter = (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';

    // Vérifier les extensions interdites en premier
    if (forbiddenExtensions.includes(ext)) {
      return cb(new Error(`Type de fichier interdit pour des raisons de sécurité: ${ext}`));
    }

    // Vérifier extension
    const hasValidExtension = allowedExtensions.includes(ext);

    // Vérifier mimetype
    const hasValidMimeType = allowedMimeTypes.includes(mimetype) ||
      (mimetype.startsWith('image/') && allowedExtensions.some(e => mimetype.includes(e.replace('.', ''))));

    // Accepter si extension valide OU mimetype valide (tolérance pour Flutter Web)
    const isOctetStream = mimetype === 'application/octet-stream';
    
    if (hasValidExtension && (hasValidMimeType || isOctetStream)) {
      return cb(null, true);
    }

    return cb(new Error(
      `Type de fichier non autorisé. Autorisés: ${allowedExtensions.join(', ')}. Reçu: ${mimetype || 'mimetype inconnu'}, extension: ${ext || 'aucune'}`
    ));
  };

  // Configuration multer
  const upload = multer({
    storage: storage,
    limits: {
      fileSize: maxSizeMB * 1024 * 1024
    },
    fileFilter: fileFilter
  });

  const uploadMiddleware = upload.single(fieldName);

  // Middleware final
  return async (req, res, next) => {
    uploadMiddleware(req, res, async (err) => {
      if (err) {
        return next(err);
      }

      if (!req.file) {
        return next(new BadRequestError('Aucun fichier fourni'));
      }

      try {
        const userId = req.user?._id;
        if (!userId) {
          return next(new BadRequestError('Utilisateur non authentifié'));
        }

        const fileBuffer = req.file.buffer;
        const fileSize = fileBuffer.length;
        const mimetype = req.file.mimetype || '';
        const extension = path.extname(req.file.originalname).toLowerCase();

        // 1. Vérifier les quotas AVANT de sauvegarder
        const { uploadType } = await checkQuota(userId, fileSize, mimetype, extension, customLimits);

        // 2. Vérifier la signature du fichier (magic bytes)
        const fileTypeResult = await fileTypeFromBuffer(fileBuffer);

        if (!fileTypeResult) {
          // Certains fichiers peuvent ne pas avoir de signature détectable
          const allowedImageExts = ['.jpeg', '.jpg', '.png', '.gif', '.webp'];
          if (!allowedImageExts.includes(extension)) {
            return next(new BadRequestError('Impossible de vérifier le type de fichier. Fichier suspect.'));
          }
        } else {
          // Vérifier que c'est bien une image
          if (!fileTypeResult.mime.startsWith('image/')) {
            return next(new BadRequestError(`Type de fichier détecté: ${fileTypeResult.mime}. Seules les images sont autorisées.`));
          }

          // Vérifier les types dangereux
          const dangerousMimes = [
            'text/html', 'application/javascript', 'text/javascript',
            'application/x-executable', 'application/x-msdownload'
          ];

          if (dangerousMimes.some(dm => fileTypeResult.mime.includes(dm))) {
            return next(new BadRequestError(`Type de fichier dangereux détecté: ${fileTypeResult.mime}. Upload refusé.`));
          }
        }

        // 3. Générer un chemin unique avec StorageProvider
        const filePath = storageProvider.generateFilePath(userId, category, req.file.originalname);

        // 4. Sauvegarder avec StorageProvider
        const savedPath = await storageProvider.saveFile(fileBuffer, filePath, {
          contentType: mimetype
        });

        // 5. Enregistrer l'upload dans les quotas
        await recordUpload(userId, fileSize, uploadType);

        // 6. Ajouter les infos du fichier à req.file
        req.file.path = savedPath;
        req.file.relativePath = filePath;
        req.file.url = process.env.STORAGE_TYPE === 's3' 
          ? savedPath // S3 retourne une URL
          : `/uploads/${filePath}`; // Local: chemin relatif pour servir via Express

        next();
      } catch (error) {
        // En cas d'erreur, ne pas laisser de fichier orphelin
        if (req.file && req.file.path && await storageProvider.fileExists(req.file.path)) {
          await storageProvider.deleteFile(req.file.path);
        }
        return next(error);
      }
    });
  };
}

// Exemple: Middleware pour upload d'avatar
const uploadAvatarSecure = createSecureUploadMiddleware({
  fieldName: 'avatar',
  category: 'avatars',
  maxSizeMB: parseInt(process.env.UPLOAD_MAX_SIZE_IMAGE || '5', 10),
  allowedExtensions: ['.jpeg', '.jpg', '.png', '.gif', '.webp'],
  allowedMimeTypes: ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
});

module.exports = {
  createSecureUploadMiddleware,
  uploadAvatarSecure
};

