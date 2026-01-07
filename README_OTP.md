# Documentation OTP SMS avec Twilio Verify

Ce document décrit l'utilisation des endpoints OTP pour la vérification des numéros de téléphone via Twilio Verify.

## Configuration requise

Variables d'environnement à définir dans `.env`:

```env
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_VERIFY_SERVICE_SID=VAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Pour le développement local (sans Twilio):
```env
SKIP_SMS_VERIFICATION=true
TEST_OTP_CODE=123456  # Code de test accepté en mode développement
```

## Format des numéros de téléphone

Tous les numéros doivent être au format **E.164** (format international):
- Commence par `+`
- Suivi de l'indicatif pays (1-3 chiffres)
- Suivi du numéro (4-14 chiffres)
- Exemples:
  - `+33612345678` (France)
  - `+14155552671` (États-Unis)
  - `+442071234567` (Royaume-Uni)

Le système normalise automatiquement les formats courants:
- `06 12 34 56 78` → `+33612345678`
- `0612345678` → `+33612345678`
- `+33 6 12 34 56 78` → `+33612345678`

## Endpoints

### 1. Envoyer un code OTP

**POST** `/api/auth/phone/send-otp`

**Rate Limit:** 10 requêtes par 15 minutes par IP

**Body:**
```json
{
  "phone": "+33612345678"
}
```

**Réponse succès (200):**
```json
{
  "success": true,
  "message": "Code OTP envoyé avec succès"
}
```

**Réponse erreur (400):**
```json
{
  "success": false,
  "message": "Format de numéro de téléphone invalide. Utilisez le format international (ex: +33612345678)"
}
```

**Réponse erreur (404):**
```json
{
  "success": false,
  "message": "Aucun compte trouvé avec ce numéro de téléphone"
}
```

**Réponse erreur (429 - Rate Limit):**
```json
{
  "success": false,
  "message": "Trop de tentatives d'envoi de code. Veuillez réessayer dans 15 minutes."
}
```

**Exemple curl:**
```bash
curl -X POST http://localhost:5000/api/auth/phone/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "+33612345678"}'
```

**Exemple avec authentification (pour changer son téléphone):**
```bash
curl -X POST http://localhost:5000/api/auth/phone/send-otp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"phone": "+33612345678"}'
```

---

### 2. Vérifier un code OTP

**POST** `/api/auth/phone/verify-otp`

**Rate Limit:** 20 requêtes par 15 minutes par IP (les vérifications réussies ne comptent pas)

**Body:**
```json
{
  "phone": "+33612345678",
  "code": "123456"
}
```

**Réponse succès (200):**
```json
{
  "success": true,
  "message": "Téléphone vérifié avec succès"
}
```

**Réponse erreur (401 - Code invalide):**
```json
{
  "success": false,
  "message": "Code OTP invalide ou expiré"
}
```

**Réponse erreur (400):**
```json
{
  "success": false,
  "message": "Le code doit contenir entre 4 et 8 chiffres"
}
```

**Réponse erreur (404):**
```json
{
  "success": false,
  "message": "Aucun compte trouvé avec ce numéro de téléphone"
}
```

**Réponse erreur (429 - Rate Limit):**
```json
{
  "success": false,
  "message": "Trop de tentatives de vérification. Veuillez réessayer dans 15 minutes."
}
```

**Exemple curl:**
```bash
curl -X POST http://localhost:5000/api/auth/phone/verify-otp \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+33612345678",
    "code": "123456"
  }'
```

**Exemple avec authentification:**
```bash
curl -X POST http://localhost:5000/api/auth/phone/verify-otp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "phone": "+33612345678",
    "code": "123456"
  }'
```

---

## Flux d'inscription avec téléphone (OBLIGATOIRE)

1. **Inscription** (`POST /api/auth/register`)
   - **Le téléphone est OBLIGATOIRE** (erreur 400 si absent)
   - L'utilisateur fournit `phone` (sera normalisé en `phoneE164`)
   - Le compte est créé avec:
     - `phoneVerified: false`
     - `status: "pending_phone_verification"`
   - **L'OTP est envoyé automatiquement** après création du compte
   - Si un code de parrainage est fourni, il est enregistré mais **aucune récompense n'est accordée**
   - **L'utilisateur n'est PAS connecté** (pas de token JWT)
   - Réponse: `{ success: true, nextStep: "PHONE_VERIFICATION", otpSent: true }`

2. **Envoi OTP** (`POST /api/auth/phone/send-otp`)
   - Utilisé uniquement pour **renvoyer le code** si nécessaire
   - Twilio Verify envoie le code par SMS

3. **Vérification OTP** (`POST /api/auth/phone/verify-otp`)
   - L'utilisateur fournit le code reçu
   - Si le code est valide:
     - `phoneVerified` est mis à `true`
     - `status` est mis à `"active"`
     - **Les récompenses de parrainage sont accordées automatiquement** (si applicable)
     - Le compte est maintenant activé et l'utilisateur peut se connecter

## Connexion par téléphone

**POST** `/api/auth/login`

**Body:**
```json
{
  "identifier": "+33612345678",
  "password": "motdepasse123"
}
```

**OU (rétrocompatibilité):**
```json
{
  "email": "user@example.com",
  "password": "motdepasse123"
}
```

**Important:** 
- Le téléphone est **OBLIGATOIRE** à l'inscription
- Si un utilisateur tente de se connecter avec un compte non activé (`status !== "active"`), la connexion sera refusée avec une erreur 403:
  ```json
  {
    "success": false,
    "message": "Phone number must be verified before login",
    "requiresPhoneVerification": true
  }
  ```

**Exemple curl:**
```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "+33612345678",
    "password": "motdepasse123"
  }'
```

## Mode développement

Si `SKIP_SMS_VERIFICATION=true` ou `NODE_ENV=development`:
- Les SMS ne sont pas réellement envoyés (simulation dans les logs)
- Le code de test `TEST_OTP_CODE` (défaut: `123456`) est accepté pour la vérification
- Les erreurs Twilio sont ignorées

## Sécurité

- **Rate limiting:** Protection contre le spam et les abus
- **Format E.164:** Validation stricte des numéros
- **Unicité:** Un numéro ne peut être utilisé que par un seul compte
- **Vérification obligatoire:** Les récompenses de parrainage ne sont accordées qu'après vérification du téléphone
- **Anti-auto-parrainage:** Empêche qu'un utilisateur se parraine lui-même

## Gestion des erreurs

Tous les endpoints retournent des codes HTTP standard:
- `200`: Succès
- `400`: Erreur de validation (format invalide, champs manquants)
- `401`: Code OTP invalide
- `403`: Téléphone non vérifié (pour login)
- `404`: Utilisateur non trouvé
- `429`: Rate limit dépassé
- `500`: Erreur serveur

Les messages d'erreur ne contiennent jamais d'informations sensibles (tokens, codes, etc.).
