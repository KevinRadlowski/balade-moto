/**
 * Helper pour construire l'URL de base du serveur
 * Détecte automatiquement depuis la requête ou utilise une valeur par défaut
 */
const getBaseUrl = (req = null) => {
  // 1. Utiliser BASE_URL si défini dans l'environnement
  if (process.env.BASE_URL) {
    return process.env.BASE_URL;
  }
  
  // 2. Détecter depuis la requête HTTP (fonctionne pour les requêtes HTTP)
  if (req) {
    const protocol = req.protocol || 'http';
    const host = req.get('host');
    if (host) {
      return `${protocol}://${host}`;
    }
  }
  
  // 3. Fallback : utiliser l'IP LAN pour le développement
  // Cela permet de fonctionner depuis un iPhone sur le réseau local
  return `http://localhost:${process.env.PORT || 5000}`;
};

/**
 * Construire l'URL complète d'un fichier (avatar, background, etc.)
 */
const buildFileUrl = (filePath, req = null) => {
  if (!filePath) return null;
  
  // Si c'est déjà une URL complète, la retourner telle quelle
  if (filePath.startsWith('http')) {
    return filePath;
  }
  
  // Construire l'URL complète
  const baseUrl = getBaseUrl(req);
  return `${baseUrl}${filePath}`;
};

/**
 * Construire l'URL complète de l'avatar d'un utilisateur
 */
const buildUserAvatarUrl = (user, req = null) => {
  if (user && user.avatarUrl && !user.avatarUrl.startsWith('http')) {
    user.avatarUrl = buildFileUrl(user.avatarUrl, req);
  }
  return user;
};

module.exports = {
  getBaseUrl,
  buildFileUrl,
  buildUserAvatarUrl
};


