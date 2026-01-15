# Sécurité des Uploads - Documentation

Ce document explique le système de sécurité des uploads implémenté dans l'API RideTogether.

## Architecture

### Composants

1. **StorageProvider** (`src/services/storage.provider.js`)
   - Abstraction pour le stockage (local ou S3)
   - Génération de chemins uniques avec structure `category/userId/YYYY/MM/DD/randomName.ext`
   - Noms de fichiers randomisés avec `crypto.randomBytes`

2. **UploadUsage** (`src/models/UploadUsage.js`)
   - Modèle MongoDB pour suivre les quotas par utilisateur
   - Suivi mensuel (période YYYY-MM)
   - Suivi par type d'upload (image, document, video, audio, other)

3. **Upload Quota Service** (`src/services/upload.quota.service.js`)
   - Vérification des quotas avant upload
   - Enregistrement après upload réussi
   - Limites configurables via variables d'environnement

4. **Secure Upload Middleware** (`src/middlewares/upload-secure.middleware.js`)
   - Middleware d'exemple utilisant StorageProvider et quotas
   - Validation magic bytes (file-type)
   - Validation extension et mimetype
   - Gestion d'erreurs avec nettoyage automatique

## Sécurité

### 1. Validation des fichiers

#### Extensions interdites
Les extensions suivantes sont explicitement interdites :
- Scripts : `.html`, `.htm`, `.js`, `.jsx`, `.ts`, `.tsx`, `.php`, `.asp`, `.jsp`, `.py`, `.rb`, `.pl`
- Exécutables : `.exe`, `.bat`, `.cmd`, `.ps1`, `.sh`, `.bash`, `.jar`, `.war`, `.ear`, `.dll`, `.so`, `.dylib`
- Packages : `.deb`, `.rpm`, `.msi`, `.app`, `.apk`, `.ipa`
- Autres : `.svg`, `.xml`

#### Validation magic bytes
- Utilisation de `file-type` pour vérifier la signature réelle du fichier
- Ne se fie pas uniquement à l'extension ou au mimetype
- Supprime automatiquement les fichiers suspects

#### Validation mimetype
- Whitelist stricte de mimetypes autorisés
- Tolérance pour `application/octet-stream` (Flutter Web) si extension valide
- Vérification que le mimetype correspond à l'extension

### 2. Noms de fichiers

#### Randomisation
- Utilisation de `crypto.randomBytes(16)` pour générer des noms uniques
- Format : `{randomHex32}.{extension}`
- Jamais d'utilisation du nom original du fichier

#### Structure de dossiers
```
uploads/
  {category}/
    {userId}/
      {YYYY}/
        {MM}/
          {DD}/
            {randomName}.{ext}
```

Exemple :
```
uploads/avatars/507f1f77bcf86cd799439011/2025/01/27/a3f5b8c9d1e2f3a4b5c6d7e8f9a0b1c2.jpg
```

### 3. Quotas par utilisateur

#### Types d'upload et limites par défaut

| Type | Max fichiers/mois | Max taille/mois |
|------|-------------------|-----------------|
| Images | 100 | 500 MB |
| Documents | 50 | 200 MB |
| Vidéos | 20 | 1000 MB |
| Audio | 30 | 300 MB |
| Autres | 50 | 200 MB |

#### Configuration
Les limites sont configurables via variables d'environnement :
```env
UPLOAD_QUOTA_IMAGES_PER_USER=100
UPLOAD_QUOTA_IMAGES_MB_PER_MONTH=500
# ... etc
```

#### Vérification
- Vérification **avant** l'upload (évite les uploads inutiles)
- Enregistrement **après** l'upload réussi
- Calcul mensuel (réinitialisation automatique chaque mois)

### 4. Taille maximale par fichier

| Type | Taille max |
|------|------------|
| Images | 5 MB |
| Documents | 20 MB |
| Vidéos | 50 MB |
| Audio | 10 MB |

Configuration :
```env
UPLOAD_MAX_SIZE_IMAGE=5
UPLOAD_MAX_SIZE_DOCUMENT=20
# ... etc
```

## Stockage

### Local (par défaut)

- Stockage dans `./uploads/` (configurable via `UPLOAD_BASE_DIR`)
- Structure organisée par utilisateur et date
- Accessible via Express static middleware

### S3 (préparé)

- Stub prêt pour implémentation future
- Configuration via variables d'environnement :
```env
STORAGE_TYPE=s3
S3_BUCKET=your-bucket-name
S3_REGION=us-east-1
S3_ACCESS_KEY_ID=your-access-key
S3_SECRET_ACCESS_KEY=your-secret-key
```

## Migration progressive

### Middlewares existants

Les middlewares existants continuent de fonctionner :
- `upload.middleware.js` - Avatars
- `background-upload.middleware.js` - Backgrounds
- `message-upload.middleware.js` - Fichiers messages
- `vehicle-upload.middleware.js` - Photos véhicules
- `vehicle-document-upload.middleware.js` - Documents véhicules

### Nouveau middleware sécurisé

Le middleware `upload-secure.middleware.js` peut être adopté progressivement :

```javascript
const { createSecureUploadMiddleware } = require('../middlewares/upload-secure.middleware');

const uploadAvatar = createSecureUploadMiddleware({
  fieldName: 'avatar',
  category: 'avatars',
  maxSizeMB: 5,
  allowedExtensions: ['.jpeg', '.jpg', '.png', '.gif', '.webp'],
  allowedMimeTypes: ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
});
```

## Utilisation

### Exemple : Upload d'avatar avec quotas

```javascript
// Route
router.post('/upload-avatar', authMiddleware, uploadAvatarSecure, userController.uploadAvatar);

// Controller
exports.uploadAvatar = async (req, res) => {
  try {
    // req.file contient :
    // - path: Chemin complet (local) ou URL (S3)
    // - relativePath: Chemin relatif pour référence
    // - url: URL publique pour servir le fichier
    
    const user = await User.findByIdAndUpdate(
      req.user._id,
      { avatar: req.file.url },
      { new: true }
    );
    
    res.json({
      success: true,
      data: {
        avatar: req.file.url
      }
    });
  } catch (error) {
    next(error);
  }
};
```

### Vérification des quotas (avant upload)

```javascript
const { checkQuota } = require('../services/upload.quota.service');

// Dans le middleware ou controller
const { uploadType } = await checkQuota(
  userId,
  fileSize,
  mimetype,
  extension
);
// Lance une erreur si quota dépassé
```

### Consultation des quotas

```javascript
const { getUsage } = require('../services/upload.quota.service');

// Récupérer l'utilisation actuelle
const usage = await getUsage(userId, 'image');
// { fileCount: 15, totalSize: 25000000, lastUploadAt: ... }
```

## Tests

### Test de quota dépassé

```javascript
// Simuler un quota dépassé
await UploadUsage.findOneAndUpdate(
  { userId, period: '2025-01', uploadType: 'image' },
  { fileCount: 100, totalSize: 500 * 1024 * 1024 },
  { upsert: true }
);

// Tentative d'upload devrait échouer
```

### Test de validation magic bytes

```javascript
// Créer un fichier .jpg qui est en réalité un .exe
const fakeImage = Buffer.from('MZ\x90\x00...'); // Signature PE
// L'upload devrait être refusé par file-type
```

## Checklist de déploiement

- [ ] Configurer les variables d'environnement de quotas
- [ ] Vérifier que `UPLOAD_BASE_DIR` est accessible en écriture
- [ ] Tester les quotas avec un utilisateur test
- [ ] Vérifier que les fichiers sont bien randomisés
- [ ] Vérifier la structure de dossiers créée
- [ ] Tester le rejet de fichiers suspects
- [ ] Documenter les limites pour les utilisateurs
- [ ] Prévoir un mécanisme d'alerte si quotas souvent dépassés

## Dépannage

### Problème : Quota toujours dépassé

**Cause** : Les quotas ne se réinitialisent pas automatiquement

**Solution** : Les quotas sont mensuels (période YYYY-MM). Ils se réinitialisent automatiquement au début du mois suivant.

### Problème : Fichiers non accessibles

**Cause** : Chemin incorrect ou permissions

**Solution** : Vérifier que `UPLOAD_BASE_DIR` est accessible et que les dossiers sont créés avec les bonnes permissions.

### Problème : Uploads trop lents

**Cause** : Stockage local sur disque lent

**Solution** : Migrer vers S3 ou utiliser un disque SSD pour les uploads.

