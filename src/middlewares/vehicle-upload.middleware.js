const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { fileTypeFromBuffer } = require('file-type');

// Créer le dossier uploads/vehicles s'il n'existe pas
const vehiclesDir = path.join(__dirname, '../uploads/vehicles');
if (!fs.existsSync(vehiclesDir)) {
  fs.mkdirSync(vehiclesDir, { recursive: true });
}

// Configuration du stockage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, vehiclesDir);
  },
  filename: (req, file, cb) => {
    // Générer un nom de fichier unique : vehicleId-userId-timestamp.extension
    const vehicleId = req.params.id || 'unknown';
    const userId = req.user?._id || 'unknown';
    const timestamp = Date.now();
    const ext = path.extname(file.originalname);
    const filename = `${vehicleId}-${userId}-${timestamp}${ext}`;
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

// Filtre pour n'accepter que les images
const fileFilter = (req, file, cb) => {
  const allowedExtensions = ['.jpeg', '.jpg', '.png', '.gif', '.webp'];
  const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
  
  const ext = path.extname(file.originalname).toLowerCase();
  const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';
  
  console.log('[VehicleUpload] File received:', {
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
  // Si le mimetype est fourni, on vérifie qu'il commence par image/
  const hasValidMimeType = mimetype === '' || 
    (mimetype.startsWith('image/') && 
     (allowedMimeTypes.includes(mimetype) || 
      allowedMimeTypes.some(allowed => mimetype.includes(allowed.split('/')[1]))));
  
  // Accepter si l'extension est valide
  // Le mimetype est vérifié mais n'est pas bloquant s'il est vide (certains clients ne l'envoient pas)
  if (hasValidExtension) {
    if (!hasValidMimeType && mimetype !== '') {
      // Si un mimetype est fourni mais invalide, on log mais on accepte quand même si l'extension est bonne
      console.warn('[VehicleUpload] Warning: Extension valide mais mimetype suspect:', { ext, mimetype });
    }
    console.log('[VehicleUpload] File accepted:', { ext, mimetype });
    cb(null, true);
  } else {
    console.log('[VehicleUpload] File rejected:', { 
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
    fileSize: 15 * 1024 * 1024, // 15MB max par photo (augmenté pour les photos haute résolution)
    files: 10 // Max 10 fichiers en une seule requête
  }
});

// Middleware pour uploader une seule photo (compatibilité)
const uploadSingleMiddleware = upload.single('photo');

// Middleware pour uploader plusieurs photos (galerie)
const uploadMultipleMiddleware = upload.array('photos', 10); // Max 10 photos

// Middleware pour uploader une seule photo (compatibilité)
const handleSingleUpload = (req, res, next) => {
  uploadSingleMiddleware(req, res, async (err) => {
    if (err) {
      return next(err);
    }
    
    // Vérification supplémentaire avec file-type si disponible
    if (req.file && req.file.buffer === undefined && req.file.path) {
      try {
        const fs = require('fs').promises;
        const buffer = await fs.readFile(req.file.path);
        const fileType = await fileTypeFromBuffer(buffer);
        
        if (!fileType || !fileType.mime.startsWith('image/')) {
          // Supprimer le fichier invalide
          await fs.unlink(req.file.path);
          return next(new Error('Le fichier n\'est pas une image valide'));
        }
      } catch (fileTypeError) {
        // Si file-type échoue, on continue quand même (le filtre multer a déjà validé)
        console.warn('Impossible de vérifier le type de fichier:', fileTypeError.message);
      }
    }
    
    next();
  });
};

// Middleware pour uploader plusieurs photos (galerie)
const handleMultipleUpload = (req, res, next) => {
  uploadMultipleMiddleware(req, res, async (err) => {
    if (err) {
      return next(err);
    }
    
    // Vérification supplémentaire avec file-type pour chaque fichier
    if (req.files && req.files.length > 0) {
      const fs = require('fs').promises;
      const invalidFiles = [];
      
      for (const file of req.files) {
        if (file.buffer === undefined && file.path) {
          try {
            const buffer = await fs.readFile(file.path);
            const fileType = await fileTypeFromBuffer(buffer);
            
            if (!fileType || !fileType.mime.startsWith('image/')) {
              // Marquer le fichier comme invalide
              invalidFiles.push(file);
            }
          } catch (fileTypeError) {
            console.warn('Impossible de vérifier le type de fichier:', fileTypeError.message);
          }
        }
      }
      
      // Supprimer les fichiers invalides
      for (const file of invalidFiles) {
        try {
          await fs.unlink(file.path);
          req.files = req.files.filter(f => f !== file);
        } catch (e) {
          console.error('Erreur lors de la suppression du fichier invalide:', e);
        }
      }
      
      if (invalidFiles.length > 0) {
        return next(new Error(`${invalidFiles.length} fichier(s) invalide(s) détecté(s)`));
      }
    }
    
    next();
  });
};

// Exporter les deux middlewares
module.exports = handleSingleUpload;
module.exports.single = handleSingleUpload;
module.exports.multiple = handleMultipleUpload;

