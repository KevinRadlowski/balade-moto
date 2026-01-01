const multer = require('multer');
const path = require('path');
const fs = require('fs');

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

// Filtre pour n'accepter que les images
const fileFilter = (req, file, cb) => {
  const allowedExtensions = ['.jpeg', '.jpg', '.png', '.gif', '.webp'];
  const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
  
  const ext = path.extname(file.originalname).toLowerCase();
  const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';
  
  // Vérifier l'extension
  const hasValidExtension = allowedExtensions.includes(ext);
  
  // Vérifier le mimetype (doit commencer par image/ et être dans la liste autorisée)
  const hasValidMimeType = mimetype.startsWith('image/') && 
    (allowedMimeTypes.includes(mimetype) || 
     allowedExtensions.some(ext => mimetype.includes(ext.replace('.', ''))));

  // Accepter si l'extension est valide OU si le mimetype est valide
  if (hasValidExtension || hasValidMimeType) {
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

module.exports = upload.single('avatar');

