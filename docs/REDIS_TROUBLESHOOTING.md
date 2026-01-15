# Dépannage Redis - Guide rapide

## Problème : Redis n'est pas disponible

Si vous voyez ces messages :
```
❌ Redis: Erreur lors de l'initialisation: ...
⚠️  Redis: Tentative de reconnexion ...
❌ Redis: Échec de connexion après 3 tentatives. Fallback vers memory store.
```

Cela signifie que `REDIS_URL` est défini dans votre `.env` mais Redis n'est pas accessible.

## Solutions

### Solution 1 : Désactiver Redis (Recommandé pour développement local)

Si vous n'avez pas besoin de Redis en développement, désactivez-le :

**Dans votre `.env`**, ajoutez ou modifiez :
```env
REDIS_ENABLED=false
```

Ou **supprimez/commentez** la ligne `REDIS_URL` :
```env
# REDIS_URL=redis://localhost:6379
```

L'application utilisera automatiquement le **memory store** (rate limiting en mémoire).

### Solution 2 : Installer et démarrer Redis (Si vous en avez besoin)

#### Windows

**Option A : WSL2 (Recommandé)**
```bash
# Dans WSL2 (Ubuntu)
sudo apt-get update
sudo apt-get install redis-server
sudo service redis-server start
```

**Option B : Memurai (Redis pour Windows)**
- Télécharger : https://www.memurai.com/
- Installer et démarrer le service

**Option C : Docker**
```bash
docker run -d -p 6379:6379 --name redis redis:alpine
```

#### macOS
```bash
brew install redis
brew services start redis
```

#### Linux
```bash
sudo apt-get update
sudo apt-get install redis-server
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

### Solution 3 : Vérifier que Redis fonctionne

```bash
# Tester la connexion
redis-cli ping
# Devrait répondre: PONG
```

Si `redis-cli` n'est pas trouvé, Redis n'est pas installé.

### Solution 4 : Vérifier la configuration

Vérifiez que `REDIS_URL` dans votre `.env` est correct :

```env
# Local
REDIS_URL=redis://localhost:6379

# Avec mot de passe
REDIS_URL=redis://:password@localhost:6379

# Remote
REDIS_URL=redis://user:password@host:6379
```

## Comportement actuel

Même si Redis échoue, **l'application continue de fonctionner** :
- ✅ Rate limiting fonctionne avec **memory store**
- ✅ Aucune fonctionnalité n'est cassée
- ⚠️ Les compteurs sont perdus au redémarrage (normal avec memory store)
- ⚠️ Ne fonctionne pas en multi-instances (normal avec memory store)

## Pour la production

En production, vous devrez :
1. Installer/configurer Redis
2. Ou utiliser un service Redis managé (Redis Cloud, AWS ElastiCache, etc.)
3. Configurer `REDIS_URL` avec l'URL de votre serveur Redis

## Logs à surveiller

**Redis fonctionne** :
```
✅ Redis: Connexion établie
✅ Redis: Prêt à recevoir des commandes
✅ Redis: Connexion testée avec succès
```

**Redis désactivé (normal)** :
```
ℹ️  Redis non configuré (REDIS_URL non défini). Rate limiting en mémoire.
```

**Redis échoue (fallback automatique)** :
```
❌ Redis: Échec de connexion après 3 tentatives. Fallback vers memory store.
ℹ️  Rate limiting: Utilisation du memory store (Redis non disponible)
```

