# Guide de configuration email

## Variables d'environnement requises

Le système supporte deux formats de variables d'environnement pour la configuration email :

### Format préféré (SMTP_*)
```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=votre-email@gmail.com
SMTP_PASS=votre-app-password
SMTP_FROM=noreply@ridetogether.fr
```

### Format alternatif (EMAIL_*)
```env
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=votre-email@gmail.com
EMAIL_PASS=votre-app-password
EMAIL_FROM=noreply@ridetogether.fr
```

## Configuration pour Gmail

### 1. Activer la validation en 2 étapes
- Allez sur https://myaccount.google.com/security
- Activez la "Validation en deux étapes"

### 2. Générer un mot de passe d'application
- Allez sur https://myaccount.google.com/apppasswords
- Sélectionnez "Application" : "Mail"
- Sélectionnez "Appareil" : "Autre (nom personnalisé)"
- Entrez "Ride Together API"
- Cliquez sur "Générer"
- **Copiez le mot de passe de 16 caractères** (sans espaces)

### 3. Configuration dans .env
```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=votre-email@gmail.com
SMTP_PASS=xxxx xxxx xxxx xxxx  # Le mot de passe d'application (16 caractères)
SMTP_FROM=votre-email@gmail.com
```

**⚠️ IMPORTANT** : Utilisez le **mot de passe d'application** (16 caractères), pas votre mot de passe Gmail normal !

## Configuration pour autres fournisseurs

### Outlook/Hotmail
```env
SMTP_HOST=smtp-mail.outlook.com
SMTP_PORT=587
SMTP_USER=votre-email@outlook.com
SMTP_PASS=votre-mot-de-passe
SMTP_FROM=votre-email@outlook.com
```

### Yahoo
```env
SMTP_HOST=smtp.mail.yahoo.com
SMTP_PORT=587
SMTP_USER=votre-email@yahoo.com
SMTP_PASS=votre-app-password  # Nécessite un mot de passe d'application
SMTP_FROM=votre-email@yahoo.com
```

### Serveur SMTP personnalisé
```env
SMTP_HOST=smtp.votre-domaine.com
SMTP_PORT=587  # ou 465 pour SSL
SMTP_USER=noreply@votre-domaine.com
SMTP_PASS=votre-mot-de-passe
SMTP_FROM=noreply@votre-domaine.com
```

## Ports SMTP

- **Port 587** : TLS (recommandé) - `secure: false`
- **Port 465** : SSL - `secure: true` (configuré automatiquement)
- **Port 25** : Non recommandé (souvent bloqué)

## Vérification de la configuration

Après avoir configuré les variables d'environnement et redémarré le serveur, vous devriez voir :

```
✅ Serveur email prêt à envoyer des messages
   Host: smtp.gmail.com:587
   From: votre-email@gmail.com
```

Si vous voyez une erreur, le serveur affichera des détails sur ce qui ne va pas.

## Dépannage

### Erreur "Invalid login"
- Vérifiez que vous utilisez un **mot de passe d'application** pour Gmail (pas votre mot de passe normal)
- Vérifiez que l'email dans `SMTP_USER` est correct

### Erreur "Connection timeout"
- Vérifiez que le port n'est pas bloqué par votre firewall
- Vérifiez que `SMTP_HOST` est correct
- Essayez le port 465 au lieu de 587 (ou vice versa)

### Erreur "Authentication failed"
- Pour Gmail : utilisez un mot de passe d'application
- Vérifiez que la validation en 2 étapes est activée (pour Gmail)
- Vérifiez que les identifiants sont corrects dans le fichier `.env`

### Les emails ne partent pas mais pas d'erreur
- Vérifiez les logs du serveur pour des erreurs silencieuses
- Vérifiez le dossier spam du destinataire
- Testez avec un email de test simple

## Test de la configuration

Vous pouvez tester la configuration en créant un compte utilisateur. Un email de vérification devrait être envoyé automatiquement.

## Sécurité

⚠️ **NE COMMITEZ JAMAIS** votre fichier `.env` dans Git !
- Le fichier `.env` est déjà dans `.gitignore`
- Utilisez `.env.example` pour documenter les variables nécessaires
- En production, utilisez des variables d'environnement sécurisées (AWS Secrets Manager, etc.)
