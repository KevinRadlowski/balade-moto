const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Fonction pour corriger l'encodage UTF-8 du nom de fichier
function fixFileNameEncoding(filename) {
  if (!filename) return filename;
  
  try {
    // Si le nom contient des caractères mal encodés (comme Ã© au lieu de é)
    // C'est souvent un problème de double encodage UTF-8
    if (filename.includes('Ã')) {
      // Décoder depuis latin1 (qui est souvent l'encodage par défaut mal interprété)
      // puis encoder en UTF-8
      const buffer = Buffer.from(filename, 'latin1');
      const decoded = buffer.toString('utf8');
      console.log('🔤 Correction encodage:', { original: filename, corrected: decoded });
      return decoded;
    }
    
    // Vérifier s'il y a d'autres problèmes d'encodage
    // Si le nom contient des séquences UTF-8 mal interprétées
    try {
      // Essayer de détecter si c'est déjà correct
      const testBuffer = Buffer.from(filename, 'utf8');
      const testString = testBuffer.toString('utf8');
      if (testString === filename) {
        return filename; // Déjà correct
      }
    } catch (e) {
      // Pas un problème UTF-8
    }
    
    return filename;
  } catch (e) {
    console.warn('Erreur lors de la correction de l\'encodage:', e);
    return filename;
  }
}

// Créer les dossiers uploads s'ils n'existent pas
const uploadsBaseDir = path.join(__dirname, '../uploads');
const messagesDir = path.join(uploadsBaseDir, 'messages');
const imagesDir = path.join(messagesDir, 'images');
const videosDir = path.join(messagesDir, 'videos');
const filesDir = path.join(messagesDir, 'files');
const audioDir = path.join(messagesDir, 'audio');

[uploadsBaseDir, messagesDir, imagesDir, videosDir, filesDir, audioDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Configuration du stockage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    // Déterminer le dossier selon le type de fichier
    const fileType = req.body.messageType || req.body.type || 'file';
    let destinationDir = filesDir;
    
    if (fileType === 'image') {
      destinationDir = imagesDir;
    } else if (fileType === 'video') {
      destinationDir = videosDir;
    } else if (fileType === 'audio') {
      destinationDir = audioDir;
    }
    
    cb(null, destinationDir);
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

// Filtre pour accepter différents types de fichiers
const fileFilter = (req, file, cb) => {
  const fileType = req.body.messageType || req.body.type || 'file';
  
  if (fileType === 'image') {
    const allowedExtensions = ['.jpeg', '.jpg', '.png', '.gif', '.webp'];
    const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
    
    const ext = path.extname(file.originalname).toLowerCase();
    const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';
    
    const hasValidExtension = allowedExtensions.includes(ext);
    const hasValidMimeType = mimetype.startsWith('image/') && 
      (allowedMimeTypes.includes(mimetype) || 
       allowedExtensions.some(ext => mimetype.includes(ext.replace('.', ''))));
    
    if (hasValidExtension || hasValidMimeType) {
      cb(null, true);
    } else {
      cb(new Error(`Seules les images sont autorisées (jpeg, jpg, png, gif, webp). Reçu: ${mimetype || 'mimetype inconnu'}`));
    }
  } else if (fileType === 'video') {
    const allowedExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    const allowedMimeTypes = ['video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/x-matroska', 'video/webm'];
    
    const ext = path.extname(file.originalname).toLowerCase();
    const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';
    
    const hasValidExtension = allowedExtensions.includes(ext);
    const hasValidMimeType = mimetype.startsWith('video/') && 
      (allowedMimeTypes.includes(mimetype) || 
       allowedExtensions.some(ext => mimetype.includes(ext.replace('.', ''))));
    
    if (hasValidExtension || hasValidMimeType) {
      cb(null, true);
    } else {
      cb(new Error(`Seules les vidéos sont autorisées (mp4, mov, avi, mkv, webm). Reçu: ${mimetype || 'mimetype inconnu'}`));
    }
  } else if (fileType === 'audio') {
    const allowedExtensions = ['.mp3', '.wav', '.ogg', '.m4a', '.aac'];
    const allowedMimeTypes = ['audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/mp4', 'audio/aac'];
    
    const ext = path.extname(file.originalname).toLowerCase();
    const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';
    
    const hasValidExtension = allowedExtensions.includes(ext);
    const hasValidMimeType = mimetype.startsWith('audio/') && 
      (allowedMimeTypes.includes(mimetype) || 
       allowedExtensions.some(ext => mimetype.includes(ext.replace('.', ''))));
    
    if (hasValidExtension || hasValidMimeType) {
      cb(null, true);
    } else {
      cb(new Error(`Seuls les fichiers audio sont autorisés (mp3, wav, ogg, m4a, aac). Reçu: ${mimetype || 'mimetype inconnu'}`));
    }
  } else if (fileType === 'file') {
    // Whitelist stricte pour les fichiers génériques
    const allowedExtensions = ['.pdf', '.txt', '.docx', '.xlsx', '.doc', '.xls'];
    const allowedMimeTypes = [
      'application/pdf',
      'text/plain',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // .docx
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // .xlsx
      'application/msword', // .doc
      'application/vnd.ms-excel' // .xls
    ];
    
    // Extensions interdites explicitement (sécurité)
    const forbiddenExtensions = [
      '.html', '.htm', '.js', '.jsx', '.ts', '.tsx',
      '.svg', '.xml', '.exe', '.bat', '.cmd', '.ps1', '.sh', '.bash',
      '.php', '.asp', '.jsp', '.py', '.rb', '.pl',
      '.jar', '.war', '.ear', '.dll', '.so', '.dylib',
      '.deb', '.rpm', '.msi', '.app', '.apk', '.ipa'
    ];
    
    const ext = path.extname(file.originalname).toLowerCase();
    const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';
    
    // Vérifier les extensions interdites en premier
    if (forbiddenExtensions.includes(ext)) {
      return cb(new Error(`Type de fichier interdit pour des raisons de sécurité: ${ext}`));
    }
    
    // Vérifier l'extension autorisée
    const hasValidExtension = allowedExtensions.includes(ext);
    
    // Vérifier le mimetype
    const hasValidMimeType = allowedMimeTypes.includes(mimetype) ||
      (mimetype.startsWith('application/') && allowedExtensions.some(e => mimetype.includes(e.replace('.', ''))));
    
    if (hasValidExtension && hasValidMimeType) {
      cb(null, true);
    } else {
      cb(new Error(`Seuls les fichiers suivants sont autorisés: PDF, TXT, DOCX, XLSX, DOC, XLS. Reçu: ${mimetype || 'mimetype inconnu'}, extension: ${ext || 'aucune'}`));
    }
  } else {
    // Type non reconnu
    cb(new Error(`Type de fichier non autorisé: ${fileType}`));
  }
};

// Configuration de multer
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB max pour les fichiers (plus restrictif que images/vidéos)
  },
  fileFilter: fileFilter
});

// Middleware pour corriger l'encodage du nom de fichier après l'upload
const uploadMiddleware = upload.single('file');

// Wrapper pour corriger l'encodage et vérifier la signature du fichier
module.exports = async (req, res, next) => {
  uploadMiddleware(req, res, async (err) => {
    if (err) {
      return next(err);
    }
    
    // Corriger l'encodage du nom de fichier si présent
    if (req.file && req.file.originalname) {
      req.file.originalname = fixFileNameEncoding(req.file.originalname);
    }
    
    // Vérifier la signature du fichier (magic bytes) pour type=file
    if (req.file && req.body.messageType === 'file') {
      try {
        const fileBuffer = fs.readFileSync(req.file.path);
        const fileTypeResult = await fileTypeFromBuffer(fileBuffer);
        
        if (!fileTypeResult) {
          // Certains fichiers (comme .txt) peuvent ne pas avoir de signature
          // Vérifier l'extension à la place
          const ext = path.extname(req.file.originalname).toLowerCase();
          if (ext !== '.txt') {
            fs.unlinkSync(req.file.path); // Supprimer le fichier
            return next(new Error('Impossible de vérifier le type de fichier. Fichier suspect.'));
          }
        } else {
          // Vérifier que le mimetype détecté correspond à l'extension
          const ext = path.extname(req.file.originalname).toLowerCase();
          const detectedMime = fileTypeResult.mime;
          
          // Mapping extension -> mimetype attendu
          const expectedMimes = {
            '.pdf': 'application/pdf',
            '.txt': 'text/plain',
            '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            '.doc': 'application/msword',
            '.xls': 'application/vnd.ms-excel'
          };
          
          const expectedMime = expectedMimes[ext];
          
          // Vérifier la correspondance (tolérance pour les variantes)
          if (expectedMime && detectedMime !== expectedMime) {
            // Vérifier si c'est une variante acceptable
            const isAcceptable = (
              (ext === '.pdf' && detectedMime === 'application/pdf') ||
              (ext === '.txt' && detectedMime.startsWith('text/')) ||
              (ext === '.docx' && detectedMime.includes('wordprocessingml')) ||
              (ext === '.xlsx' && detectedMime.includes('spreadsheetml')) ||
              (ext === '.doc' && detectedMime.includes('msword')) ||
              (ext === '.xls' && detectedMime.includes('ms-excel'))
            );
            
            if (!isAcceptable) {
              fs.unlinkSync(req.file.path); // Supprimer le fichier
              return next(new Error(`Incohérence détectée: extension ${ext} mais type détecté ${detectedMime}. Fichier suspect.`));
            }
          }
          
          // Vérifier les types dangereux même si l'extension est correcte
          const dangerousMimes = [
            'text/html', 'application/javascript', 'text/javascript',
            'application/x-executable', 'application/x-msdownload',
            'application/x-sh', 'application/x-bash'
          ];
          
          if (dangerousMimes.some(dm => detectedMime.includes(dm))) {
            fs.unlinkSync(req.file.path);
            return next(new Error(`Type de fichier dangereux détecté: ${detectedMime}. Upload refusé.`));
          }
        }
      } catch (error) {
        // En cas d'erreur de vérification, supprimer le fichier par sécurité
        if (req.file && req.file.path && fs.existsSync(req.file.path)) {
          fs.unlinkSync(req.file.path);
        }
        return next(new Error(`Erreur lors de la vérification du fichier: ${error.message}`));
      }
    }
    
    next();
  });
};

