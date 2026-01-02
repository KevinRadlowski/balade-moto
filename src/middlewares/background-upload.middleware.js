const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { fileTypeFromBuffer } = require('file-type');

// Créer le dossier uploads/backgrounds s'il n'existe pas
const backgroundsDir = path.join(__dirname, '../uploads/backgrounds');
if (!fs.existsSync(backgroundsDir)) {
  fs.mkdirSync(backgroundsDir, { recursive: true });
}

// Configuration du stockage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, backgroundsDir);
  },
  filename: (req, file, cb) => {
    const userId = req.user?._id || 'unknown';
    const timestamp = Date.now();
    const ext = path.extname(file.originalname);
    const type = req.body.type || 'balade'; // balade, groupe, profil, global
    const filename = `${userId}-${type}-${timestamp}${ext}`;
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

// Filtre pour accepter uniquement les images
const fileFilter = (req, file, cb) => {
  const allowedExtensions = ['.jpeg', '.jpg', '.png', '.gif', '.webp'];
  const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
  const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';
  const ext = path.extname(file.originalname).toLowerCase();
  
  // Vérifier les extensions interdites en premier
  if (forbiddenExtensions.includes(ext)) {
    return cb(new Error(`Type de fichier interdit pour des raisons de sécurité: ${ext}`));
  }
  
  // Vérifier extension ET mimetype (ET au lieu de OU pour plus de sécurité)
  const hasValidExtension = allowedExtensions.includes(ext);
  const hasValidMimeType = mimetype.startsWith('image/') && 
    (allowedMimeTypes.includes(mimetype) || 
     allowedExtensions.some(e => mimetype.includes(e.replace('.', ''))));
  
  if (hasValidExtension && hasValidMimeType) {
    cb(null, true);
  } else {
    cb(new Error(`Seules les images sont autorisées (jpeg, jpg, png, gif, webp). Reçu: ${mimetype || 'mimetype inconnu'}, extension: ${ext || 'aucune'}`));
  }
};

// Configuration de multer
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB max
  },
  fileFilter: fileFilter
});

// Wrapper pour vérifier la signature du fichier
const uploadMiddleware = upload.single('background');

module.exports = async (req, res, next) => {
  uploadMiddleware(req, res, async (err) => {
    if (err) {
      return next(err);
    }
    
    // Vérifier la signature du fichier (magic bytes)
    if (req.file) {
      try {
        const fileBuffer = fs.readFileSync(req.file.path);
        const fileTypeResult = await fileTypeFromBuffer(fileBuffer);
        
        if (!fileTypeResult) {
          const ext = path.extname(req.file.originalname).toLowerCase();
          const allowedImageExts = ['.jpeg', '.jpg', '.png', '.gif', '.webp'];
          if (!allowedImageExts.includes(ext)) {
            fs.unlinkSync(req.file.path);
            return next(new Error('Impossible de vérifier le type de fichier. Fichier suspect.'));
          }
        } else {
          if (!fileTypeResult.mime.startsWith('image/')) {
            fs.unlinkSync(req.file.path);
            return next(new Error(`Type de fichier détecté: ${fileTypeResult.mime}. Seules les images sont autorisées.`));
          }
          
          const dangerousMimes = [
            'text/html', 'application/javascript', 'text/javascript',
            'application/x-executable', 'application/x-msdownload'
          ];
          
          if (dangerousMimes.some(dm => fileTypeResult.mime.includes(dm))) {
            fs.unlinkSync(req.file.path);
            return next(new Error(`Type de fichier dangereux détecté: ${fileTypeResult.mime}. Upload refusé.`));
          }
        }
      } catch (error) {
        if (req.file && req.file.path && fs.existsSync(req.file.path)) {
          fs.unlinkSync(req.file.path);
        }
        return next(new Error(`Erreur lors de la vérification du fichier: ${error.message}`));
      }
    }
    
    next();
  });
};

