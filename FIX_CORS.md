# 🔧 Correction CORS

## Problème
Erreur "Not allowed by CORS" lors des requêtes depuis le frontend.

## Solution appliquée

### 1. Ajout du port Flutter Web par défaut
- Ajout de `http://localhost:61004` dans les origines autorisées par défaut
- Ce port est souvent utilisé par Flutter Web en développement

### 2. Amélioration du logging
- En développement, les origines rejetées sont maintenant loggées
- Cela permet de voir quelle origine est rejetée et de l'ajouter si nécessaire

### 3. Configuration .env
Si vous utilisez un port différent pour Flutter Web, ajoutez-le dans votre `.env` :

```env
FRONTEND_URL=http://localhost:3000,http://localhost:59219,http://localhost:61004
```

## Vérification

1. **Vérifier le port Flutter Web** :
   - Regardez dans la console Flutter quel port est utilisé
   - Exemple : `http://localhost:61004` ou `http://127.0.0.1:61004`

2. **Ajouter le port dans .env** :
   - Si le port est différent, ajoutez-le à `FRONTEND_URL`
   - Format : URLs séparées par des virgules

3. **Redémarrer le serveur** :
   ```bash
   npm start
   ```

## Debug

Si vous voyez toujours des erreurs CORS :
1. Regardez les logs du serveur - vous verrez quelle origine est rejetée
2. Vérifiez que cette origine est bien dans `FRONTEND_URL` dans votre `.env`
3. Vérifiez que le port dans l'URL du frontend correspond

## Exemple de configuration .env

```env
FRONTEND_URL=http://localhost:3000,http://localhost:59219,http://localhost:61004,http://127.0.0.1:61004
```

Note : En production, utilisez uniquement les URLs de production :
```env
FRONTEND_URL=https://votre-domaine.com,https://www.votre-domaine.com
```

