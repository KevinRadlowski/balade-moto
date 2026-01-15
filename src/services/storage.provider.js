/**
 * Abstraction pour le stockage de fichiers
 * Permet de basculer facilement entre stockage local et S3
 */

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

/**
 * Interface StorageProvider
 * Toutes les implémentations doivent respecter cette interface
 */
class StorageProvider {
  /**
   * Sauvegarde un fichier
   * @param {Buffer|Stream} fileData - Données du fichier
   * @param {string} filePath - Chemin relatif où sauvegarder
   * @param {object} options - Options supplémentaires
   * @returns {Promise<string>} URL ou chemin du fichier sauvegardé
   */
  async saveFile(fileData, filePath, options = {}) {
    throw new Error('saveFile must be implemented');
  }

  /**
   * Supprime un fichier
   * @param {string} filePath - Chemin du fichier à supprimer
   * @returns {Promise<void>}
   */
  async deleteFile(filePath) {
    throw new Error('deleteFile must be implemented');
  }

  /**
   * Vérifie si un fichier existe
   * @param {string} filePath - Chemin du fichier
   * @returns {Promise<boolean>}
   */
  async fileExists(filePath) {
    throw new Error('fileExists must be implemented');
  }

  /**
   * Génère un chemin unique pour un fichier
   * @param {string} userId - ID de l'utilisateur
   * @param {string} category - Catégorie (avatars, messages, vehicles, etc.)
   * @param {string} originalName - Nom original du fichier
   * @returns {string} Chemin relatif unique
   */
  generateFilePath(userId, category, originalName) {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    
    // Générer un nom aléatoire (32 caractères hex)
    const randomName = crypto.randomBytes(16).toString('hex');
    const ext = path.extname(originalName).toLowerCase();
    
    // Structure: category/userId/YYYY/MM/DD/randomName.ext
    return path.join(category, userId.toString(), String(year), month, day, `${randomName}${ext}`).replace(/\\/g, '/');
  }
}

/**
 * Implémentation pour stockage local (filesystem)
 */
class LocalStorageProvider extends StorageProvider {
  constructor(baseDir) {
    super();
    this.baseDir = baseDir || path.join(__dirname, '../uploads');
  }

  /**
   * Crée les dossiers nécessaires
   * @param {string} filePath - Chemin du fichier
   */
  _ensureDirectoryExists(filePath) {
    const fullPath = path.join(this.baseDir, filePath);
    const dir = path.dirname(fullPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  async saveFile(fileData, filePath, options = {}) {
    const fullPath = path.join(this.baseDir, filePath);
    this._ensureDirectoryExists(filePath);
    
    // Si fileData est un Buffer
    if (Buffer.isBuffer(fileData)) {
      fs.writeFileSync(fullPath, fileData);
      return fullPath;
    }
    
    // Si fileData est un Stream
    if (fileData.pipe) {
      const writeStream = fs.createWriteStream(fullPath);
      return new Promise((resolve, reject) => {
        fileData.pipe(writeStream);
        writeStream.on('finish', () => resolve(fullPath));
        writeStream.on('error', reject);
      });
    }
    
    throw new Error('fileData must be a Buffer or Stream');
  }

  async deleteFile(filePath) {
    const fullPath = path.join(this.baseDir, filePath);
    if (fs.existsSync(fullPath)) {
      fs.unlinkSync(fullPath);
    }
  }

  async fileExists(filePath) {
    const fullPath = path.join(this.baseDir, filePath);
    return fs.existsSync(fullPath);
  }
}

/**
 * Implémentation pour stockage S3 (stub - à implémenter)
 */
class S3StorageProvider extends StorageProvider {
  constructor(config) {
    super();
    // config: { bucket, region, accessKeyId, secretAccessKey }
    this.config = config;
    // TODO: Initialiser le client S3 (AWS SDK v3)
    // const { S3Client } = require('@aws-sdk/client-s3');
    // this.s3Client = new S3Client({ ... });
  }

  async saveFile(fileData, filePath, options = {}) {
    // TODO: Implémenter upload S3
    // const { PutObjectCommand } = require('@aws-sdk/client-s3');
    // const command = new PutObjectCommand({
    //   Bucket: this.config.bucket,
    //   Key: filePath,
    //   Body: fileData,
    //   ContentType: options.contentType,
    //   ACL: 'private' // ou 'public-read' selon besoin
    // });
    // await this.s3Client.send(command);
    // return `https://${this.config.bucket}.s3.${this.config.region}.amazonaws.com/${filePath}`;
    throw new Error('S3StorageProvider not yet implemented. Use LocalStorageProvider.');
  }

  async deleteFile(filePath) {
    // TODO: Implémenter suppression S3
    // const { DeleteObjectCommand } = require('@aws-sdk/client-s3');
    // const command = new DeleteObjectCommand({
    //   Bucket: this.config.bucket,
    //   Key: filePath
    // });
    // await this.s3Client.send(command);
    throw new Error('S3StorageProvider not yet implemented. Use LocalStorageProvider.');
  }

  async fileExists(filePath) {
    // TODO: Implémenter vérification existence S3
    // const { HeadObjectCommand } = require('@aws-sdk/client-s3');
    // try {
    //   const command = new HeadObjectCommand({
    //     Bucket: this.config.bucket,
    //     Key: filePath
    //   });
    //   await this.s3Client.send(command);
    //   return true;
    // } catch (error) {
    //   if (error.name === 'NotFound') return false;
    //   throw error;
    // }
    throw new Error('S3StorageProvider not yet implemented. Use LocalStorageProvider.');
  }
}

/**
 * Factory pour créer le StorageProvider approprié
 * @returns {StorageProvider}
 */
function createStorageProvider() {
  const storageType = process.env.STORAGE_TYPE || 'local';
  
  if (storageType === 's3') {
    const config = {
      bucket: process.env.S3_BUCKET,
      region: process.env.S3_REGION || 'us-east-1',
      accessKeyId: process.env.S3_ACCESS_KEY_ID,
      secretAccessKey: process.env.S3_SECRET_ACCESS_KEY
    };
    
    if (!config.bucket || !config.accessKeyId || !config.secretAccessKey) {
      throw new Error('S3 configuration incomplete. Required: S3_BUCKET, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY');
    }
    
    return new S3StorageProvider(config);
  }
  
  // Par défaut: stockage local
  const baseDir = process.env.UPLOAD_BASE_DIR || path.join(__dirname, '../uploads');
  return new LocalStorageProvider(baseDir);
}

module.exports = {
  StorageProvider,
  LocalStorageProvider,
  S3StorageProvider,
  createStorageProvider
};

