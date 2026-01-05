const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { fileTypeFromBuffer } = require('file-type');

// Créer le dossier uploads/maintenance-logs s'il n'existe pas
const documentsDir = path.join(__dirname, '../uploads/maintenance-logs');
if (!fs.existsSync(documentsDir)) {
  fs.mkdirSync(documentsDir, { recursive: true });
}

// Fonction utilitaire pour nettoyer le nom de fichier
const sanitizeFilename = (name) => {
  // Supprimer les caractères spéciaux, remplacer les espaces par des tirets
  let cleaned = name.normalize("NFD").replace(/[\u0300-\u036f]/g, "") // Supprimer les accents
                        .replace(/[^a-zA-Z0-9\s-.]/g, '') // Garder lettres, chiffres, espaces, tirets, points
                        .replace(/\s+/g, '-') // Remplacer les espaces par des tirets
                        .replace(/--+/g, '-') // Remplacer les multiples tirets par un seul
                        .trim();
  // Limiter la longueur pour éviter les problèmes de système de fichiers
  if (cleaned.length > 100) {
    cleaned = cleaned.substring(0, 100);
  }
  return cleaned || 'document'; // Nom par défaut si vide
};

// Configuration du stockage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, documentsDir);
  },
  filename: (req, file, cb) => {
    // Utiliser le libellé de l'entretien si disponible, sinon le nom original du fichier
    const label = req.body.label || file.originalname.split('.')[0];
    const sanitizedLabel = sanitizeFilename(label);
    const vehicleId = req.params.id || 'unknown';
    const timestamp = Date.now();
    const ext = path.extname(file.originalname).toLowerCase();
    const filename = `maintenance-${vehicleId}-${sanitizedLabel}-${timestamp}${ext}`;
    cb(null, filename);
  }
});

// Extensions interdites explicitement (sécurité)
const forbiddenExtensions = [
  '.html', '.htm', '.js', '.jsx', '.ts', '.tsx',
  '.svg', '.xml', '.exe', '.bat', '.cmd', '.ps1', '.sh', '.bash',
  '.php', '.asp', '.jsp', '.py', '.rb', '.pl',
  '.jar', '.war', '.ear', '.dll', '.so', '.dylib',
  '.deb', '.rpm', '.msi', '.app', '.apk', '.ipa'
];

// Extensions autorisées pour les documents
const allowedExtensions = [
  '.pdf', '.jpg', '.jpeg', '.png', '.gif', '.webp', // Images
  '.doc', '.docx', '.xls', '.xlsx', '.txt' // Documents
];

// Mime types autorisés
const allowedMimeTypes = [
  'application/pdf',
  'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp',
  'application/msword', // .doc
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // .docx
  'application/vnd.ms-excel', // .xls
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // .xlsx
  'text/plain' // .txt
];

// Filtre pour accepter les documents
const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';

  console.log('[MaintenanceLogDocumentUpload] File received:', {
    originalname: file.originalname,
    extension: ext,
    mimetype: mimetype,
    fieldname: file.fieldname
  });

  // Vérifier les extensions interdites en premier
  if (forbiddenExtensions.includes(ext)) {
    return cb(new Error(`Type de fichier interdit pour des raisons de sécurité: ${ext}`));
  }

  // Vérifier l'extension
  const hasValidExtension = allowedExtensions.includes(ext);

  // Vérifier le mimetype (si présent)
  // Si le mimetype est vide ou non fourni, on accepte si l'extension est valide
  // Si le mimetype est fourni, on vérifie qu'il est dans la liste autorisée
  const hasValidMimeType = mimetype === '' || allowedMimeTypes.includes(mimetype);

  // Accepter si l'extension est valide
  // Le mimetype est vérifié mais n'est pas bloquant s'il est vide (certains clients ne l'envoient pas)
  if (hasValidExtension) {
    if (!hasValidMimeType && mimetype !== '') {
      // Si un mimetype est fourni mais invalide, on log mais on accepte quand même si l'extension est bonne
      console.warn('[MaintenanceLogDocumentUpload] Warning: Extension valide mais mimetype suspect:', { ext, mimetype });
    }
    console.log('[MaintenanceLogDocumentUpload] File accepted:', { ext, mimetype });
    cb(null, true);
  } else {
    console.log('[MaintenanceLogDocumentUpload] File rejected:', {
      hasValidExtension,
      hasValidMimeType,
      ext,
      mimetype
    });
    cb(new Error(`Type de fichier non autorisé. Extensions autorisées: ${allowedExtensions.join(', ')}`));
  }
};

// Configuration de multer
const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB max pour les documents
  }
});

// Middleware pour uploader un seul fichier
const uploadMiddleware = upload.single('document');

module.exports = (req, res, next) => {
  uploadMiddleware(req, res, async (err) => {
    if (err) {
      return next(err);
    }

    // Vérification supplémentaire avec file-type si disponible
    if (req.file && req.file.buffer === undefined && req.file.path) {
      try {
        const fs = require('fs').promises;
        const buffer = await fs.readFile(req.file.path);
        const fileType = await fileTypeFromBuffer(buffer);

        // Vérifier que c'est un type de fichier autorisé
        const isValidType = fileType && (
          fileType.mime.startsWith('image/') ||
          fileType.mime === 'application/pdf' ||
          fileType.mime.includes('wordprocessingml') ||
          fileType.mime.includes('spreadsheetml') ||
          fileType.mime === 'text/plain'
        );

        if (!isValidType) {
          // Supprimer le fichier invalide
          await fs.unlink(req.file.path);
          return next(new Error('Le fichier n\'est pas d\'un type autorisé'));
        }
      } catch (fileTypeError) {
        // Si file-type échoue, on continue quand même (le filtre multer a déjà validé)
        console.warn('Impossible de vérifier le type de fichier:', fileTypeError.message);
      }
    }

    next();
  });
};




