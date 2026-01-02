const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { fileTypeFromBuffer } = require('file-type');

// Créer le dossier uploads/vehicle-documents s'il n'existe pas
const documentsDir = path.join(__dirname, '../uploads/vehicle-documents');
if (!fs.existsSync(documentsDir)) {
  fs.mkdirSync(documentsDir, { recursive: true });
}

// Fonction pour nettoyer un libellé et en faire un nom de fichier valide
function sanitizeFilename(label) {
  if (!label || typeof label !== 'string') {
    return 'document';
  }
  
  // Nettoyer le libellé : supprimer les caractères spéciaux, garder lettres, chiffres, espaces, tirets, underscores
  let clean = label
    .trim()
    .normalize('NFD') // Normaliser les caractères accentués
    .replace(/[\u0300-\u036f]/g, '') // Supprimer les accents
    .replace(/[^a-zA-Z0-9\s\-_]/g, '') // Supprimer les caractères spéciaux
    .replace(/\s+/g, '-') // Remplacer les espaces multiples par un tiret
    .replace(/-+/g, '-') // Remplacer les tirets multiples par un seul
    .replace(/^-|-$/g, ''); // Supprimer les tirets en début/fin
  
  // Limiter la longueur (max 100 caractères pour le nom de base)
  if (clean.length > 100) {
    clean = clean.substring(0, 100);
  }
  
  // Si le résultat est vide, utiliser un nom par défaut
  if (!clean || clean.length === 0) {
    clean = 'document';
  }
  
  return clean;
}

// Configuration du stockage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, documentsDir);
  },
  filename: (req, file, cb) => {
    // Récupérer le libellé du document depuis req.body (multer parse le body multipart)
    const label = req.body?.label || '';
    const ext = path.extname(file.originalname);
    const timestamp = Date.now();
    
    // Nettoyer le libellé pour en faire un nom de fichier valide
    const cleanLabel = sanitizeFilename(label);
    
    // Générer un nom de fichier : libellé-timestamp.extension
    // Le timestamp garantit l'unicité même si deux documents ont le même libellé
    const filename = `${cleanLabel}-${timestamp}${ext}`;
    
    console.log('[VehicleDocumentUpload] Generated filename:', {
      originalLabel: label,
      cleanLabel: cleanLabel,
      filename: filename
    });
    
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
  
  console.log('[VehicleDocumentUpload] File received:', {
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
      console.warn('[VehicleDocumentUpload] Warning: Extension valide mais mimetype suspect:', { ext, mimetype });
    }
    console.log('[VehicleDocumentUpload] File accepted:', { ext, mimetype });
    cb(null, true);
  } else {
    console.log('[VehicleDocumentUpload] File rejected:', { 
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

// Middleware pour corriger l'encodage du nom de fichier après l'upload
const uploadMiddleware = upload.single('file');

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

