const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { fileTypeFromBuffer } = require('file-type');

// Créer le dossier uploads/avatars s'il n'existe pas
const uploadsDir = path.join(__dirname, '../uploads/avatars');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Configuration du stockage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    // Générer un nom de fichier unique : userId-timestamp.extension
    const userId = req.user?._id || 'unknown';
    const timestamp = Date.now();
    const ext = path.extname(file.originalname);
    const filename = `${userId}-${timestamp}${ext}`;
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
  
  // Vérifier les extensions interdites en premier
  if (forbiddenExtensions.includes(ext)) {
    return cb(new Error(`Type de fichier interdit pour des raisons de sécurité: ${ext}`));
  }
  
  // Vérifier l'extension
  const hasValidExtension = allowedExtensions.includes(ext);
  
  // Vérifier le mimetype (doit commencer par image/ et être dans la liste autorisée)
  const hasValidMimeType = mimetype.startsWith('image/') && 
    (allowedMimeTypes.includes(mimetype) || 
     allowedExtensions.some(e => mimetype.includes(e.replace('.', ''))));

  // Accepter si l'extension ET le mimetype sont valides (ET au lieu de OU pour plus de sécurité)
  if (hasValidExtension && hasValidMimeType) {
    cb(null, true);
  } else {
    console.log('Fichier rejeté:', {
      originalname: file.originalname,
      mimetype: file.mimetype,
      extname: ext
    });
    cb(new Error(`Seules les images sont autorisées (jpeg, jpg, png, gif, webp). Reçu: ${mimetype || 'mimetype inconnu'}, extension: ${ext || 'aucune'}`));
  }
};

// Configuration de multer
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB max
  },
  fileFilter: fileFilter
});

// Wrapper pour vérifier la signature du fichier
const uploadMiddleware = upload.single('avatar');

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
          // Certains fichiers peuvent ne pas avoir de signature détectable
          // Vérifier l'extension à la place
          const ext = path.extname(req.file.originalname).toLowerCase();
          const allowedImageExts = ['.jpeg', '.jpg', '.png', '.gif', '.webp'];
          if (!allowedImageExts.includes(ext)) {
            fs.unlinkSync(req.file.path);
            return next(new Error('Impossible de vérifier le type de fichier. Fichier suspect.'));
          }
        } else {
          // Vérifier que c'est bien une image
          if (!fileTypeResult.mime.startsWith('image/')) {
            fs.unlinkSync(req.file.path);
            return next(new Error(`Type de fichier détecté: ${fileTypeResult.mime}. Seules les images sont autorisées.`));
          }
          
          // Vérifier les types dangereux
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

