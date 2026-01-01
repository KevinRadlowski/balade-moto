const multer = require('multer');
const path = require('path');
const fs = require('fs');

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

// Filtre pour accepter uniquement les images
const fileFilter = (req, file, cb) => {
  const allowedExtensions = ['.jpeg', '.jpg', '.png', '.gif', '.webp'];
  const mimetype = file.mimetype ? file.mimetype.toLowerCase() : '';
  const ext = path.extname(file.originalname).toLowerCase();
  
  if (allowedExtensions.includes(ext) || mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Seules les images sont autorisées (jpeg, jpg, png, gif, webp)'));
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

module.exports = upload.single('background');

