# Solution pour les erreurs de connexion SMTP (ETIMEDOUT)

## Problème

Si vous obtenez l'erreur `ETIMEDOUT` lors de la connexion SMTP, cela signifie que votre firewall ou routeur bloque les connexions sortantes sur les ports SMTP (465 ou 587).

## Solutions

### Solution 1 : Désactiver la vérification email en développement (RECOMMANDÉ)

Ajoutez cette ligne dans votre fichier `.env` :

```env
SKIP_EMAIL_VERIFICATION=true
```

Cela désactivera la vérification de connexion SMTP au démarrage. Les emails seront toujours tentés, mais les erreurs seront ignorées silencieusement en développement.

**Avantages :**
- Le serveur démarre sans erreur
- Vous pouvez continuer à développer sans configurer SMTP
- Les emails seront tentés mais échoueront silencieusement

### Solution 2 : Configurer le firewall Windows

1. Ouvrez le **Pare-feu Windows Defender**
2. Cliquez sur **Paramètres avancés**
3. Cliquez sur **Règles de trafic sortant** → **Nouvelle règle**
4. Sélectionnez **Port** → **Suivant**
5. Sélectionnez **TCP** et entrez les ports : `465, 587`
6. Sélectionnez **Autoriser la connexion**
7. Appliquez à tous les profils
8. Nommez la règle : "SMTP Outbound"

### Solution 3 : Configurer le routeur

Si vous êtes derrière un routeur, vous devrez peut-être :
1. Désactiver le filtrage SMTP (si activé)
2. Autoriser les connexions sortantes sur les ports 465 et 587
3. Vérifier les paramètres de sécurité du routeur

### Solution 4 : Utiliser un service email alternatif

Si Gmail ne fonctionne pas à cause du firewall, vous pouvez utiliser :

#### SendGrid (Recommandé pour production)
```env
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=votre-api-key-sendgrid
SMTP_FROM=noreply@votre-domaine.com
```

#### Mailgun
```env
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
SMTP_USER=votre-username-mailgun
SMTP_PASS=votre-password-mailgun
SMTP_FROM=noreply@votre-domaine.com
```

#### Outlook/Hotmail
```env
SMTP_HOST=smtp-mail.outlook.com
SMTP_PORT=587
SMTP_USER=votre-email@outlook.com
SMTP_PASS=votre-mot-de-passe
SMTP_FROM=votre-email@outlook.com
```

### Solution 5 : Utiliser un VPN ou proxy

Si votre réseau bloque SMTP, vous pouvez :
1. Désactiver temporairement le VPN/proxy pour tester
2. Utiliser un autre réseau (mobile hotspot, etc.)
3. Configurer un proxy SMTP si disponible

## Test de connexion

Pour tester si les ports sont accessibles :

### PowerShell
```powershell
Test-NetConnection -ComputerName smtp.gmail.com -Port 465
Test-NetConnection -ComputerName smtp.gmail.com -Port 587
```

### Script de test
```bash
npm run test:smtp
```

## Configuration recommandée pour le développement

Pour éviter les problèmes de firewall en développement, ajoutez dans votre `.env` :

```env
# Désactiver la vérification email en développement
SKIP_EMAIL_VERIFICATION=true

# Configuration SMTP (sera ignorée si la vérification est désactivée)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USER=votre-email@gmail.com
SMTP_PASS=votre-app-password
SMTP_FROM=votre-email@gmail.com
```

## Notes importantes

- La vérification email est uniquement désactivée en **développement**
- En **production**, la vérification sera toujours active
- Les emails seront toujours **tentés**, mais les erreurs seront **ignorées** en développement
- Pour la production, vous **devez** résoudre le problème de firewall ou utiliser un service email alternatif
