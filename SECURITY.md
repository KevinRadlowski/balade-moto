# Guide de Sécurité - RideTogether

## 🔐 Gestion des Secrets

### Variables d'environnement

**CRITIQUE**: Ne jamais committer de secrets dans le repository Git.

#### Fichiers à créer

1. **`.env`** (local, non versionné) - Contient les vraies valeurs
2. **`.env.example`** (versionné) - Template sans valeurs sensibles

#### Secrets à protéger

- `JWT_SECRET` - Secret pour signer les tokens JWT
- `JWT_REFRESH_SECRET` - Secret pour les refresh tokens
- `GOOGLE_MAPS_API_KEY` - Clé API Google Maps
- `EMAIL_PASS` - Mot de passe SMTP
- `MONGO_URI` - URI de connexion MongoDB (si contient credentials)

### Rotation des Secrets

#### JWT Secrets

**Quand rotater**:
- Compromission suspectée
- Tous les 90 jours (recommandé)
- Changement d'équipe

**Procédure**:
1. Générer de nouveaux secrets (min 32 caractères aléatoires):
   ```bash
   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
   ```
2. Mettre à jour `.env` avec les nouvelles valeurs
3. **Important**: Tous les tokens existants seront invalidés
4. Les utilisateurs devront se reconnecter

#### Google Maps API Key

**Quand rotater**:
- Clé exposée publiquement
- Restrictions violées
- Changement de projet Google Cloud

**Procédure**:
1. Créer une nouvelle clé dans Google Cloud Console
2. Configurer les restrictions (HTTP referrers, IPs)
3. Mettre à jour `.env` avec la nouvelle clé
4. Tester que l'application fonctionne
5. Révoquer l'ancienne clé après 24-48h

#### SMTP Password

**Quand rotater**:
- Mot de passe compromis
- Changement de compte email
- Tous les 6 mois (recommandé)

**Procédure**:
1. Générer un nouveau mot de passe d'application (Gmail) ou changer le mot de passe SMTP
2. Mettre à jour `.env` avec le nouveau mot de passe
3. Tester l'envoi d'email
4. Révoquer l'ancien mot de passe

### Scan de Secrets

Avant chaque commit, exécuter le scan de secrets:

```bash
# Linux/Mac
./scripts/scan-secrets.sh

# Windows
powershell -ExecutionPolicy Bypass -File scripts/scan-secrets.ps1
```

**Recommandation**: Installer `gitleaks` pour un scan plus complet:
```bash
# Installation
brew install gitleaks  # Mac
# ou télécharger depuis https://github.com/gitleaks/gitleaks/releases

# Scan
gitleaks detect --source . --verbose
```

## 🛡️ Bonnes Pratiques

### Upload de Fichiers

- ✅ Whitelist stricte d'extensions
- ✅ Vérification du mimetype
- ✅ Vérification de signature (magic bytes)
- ✅ Limite de taille
- ❌ Ne jamais accepter `.html`, `.js`, `.exe`, `.bat`, `.ps1`, etc.

### API Endpoints

- ✅ Authentification requise pour toutes les routes sensibles
- ✅ Rate limiting sur les endpoints publics/proxy
- ✅ Validation stricte des entrées (express-validator)
- ✅ Gestion d'erreurs centralisée (pas d'exposition de stack traces en prod)

### CORS

- ✅ Whitelist stricte des origines autorisées
- ❌ Ne jamais utiliser `Access-Control-Allow-Origin: *` avec credentials
- ✅ Configurer selon l'environnement (dev vs prod)

### Base de Données

- ✅ Index MongoDB créés via scripts de migration (pas au démarrage)
- ✅ Connexion avec credentials sécurisés
- ✅ Pas de credentials en dur dans le code

## 🚨 En Cas de Compromission

1. **Isoler**: Désactiver les endpoints compromis
2. **Rotater**: Tous les secrets concernés immédiatement
3. **Auditer**: Vérifier les logs pour l'étendue de la compromission
4. **Notifier**: Informer les utilisateurs si données personnelles exposées
5. **Documenter**: Créer un incident report

## 📞 Contact Sécurité

Pour signaler une vulnérabilité de sécurité, contactez l'équipe de développement.



