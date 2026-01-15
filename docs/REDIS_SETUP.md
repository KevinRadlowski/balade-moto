# Configuration Redis - Documentation

Ce document explique comment configurer Redis pour le rate limiting distribué dans l'API RideTogether.

## Installation

### Option 1 : Redis local

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install redis-server

# macOS (Homebrew)
brew install redis
brew services start redis

# Windows
# Télécharger depuis https://redis.io/download
# Ou utiliser WSL2 avec Ubuntu
```

### Option 2 : Redis Cloud (production)

Services recommandés :
- **Redis Cloud** : https://redis.com/try-free/
- **AWS ElastiCache** : https://aws.amazon.com/elasticache/
- **Azure Cache for Redis** : https://azure.microsoft.com/services/cache/

### Option 3 : Docker

```bash
docker run -d -p 6379:6379 --name redis redis:alpine
```

## Installation du package Node.js

```bash
npm install ioredis
```

**Note** : Si `ioredis` n'est pas installé, l'application fonctionnera avec un memory store (fallback automatique).

## Configuration

### Variables d'environnement

Ajoutez dans votre `.env` :

```env
# Redis URL (format: redis://[user:password@]host:port[/db])
REDIS_URL=redis://localhost:6379

# Activer Redis (par défaut: true si REDIS_URL est défini)
REDIS_ENABLED=true
```

### Formats d'URL Redis

- **Local sans auth** : `redis://localhost:6379`
- **Local avec auth** : `redis://:password@localhost:6379`
- **Remote** : `redis://user:password@host:6379`
- **Redis Cloud** : `redis://default:password@redis-12345.c1.us-east-1-1.ec2.cloud.redislabs.com:12345`

## Comportement

### Avec Redis disponible

- ✅ Rate limiting distribué (fonctionne en multi-instances)
- ✅ Persistance des compteurs entre redémarrages
- ✅ Meilleure scalabilité
- ✅ Logs : `✅ Redis: Connexion établie`

### Sans Redis (fallback)

- ✅ Rate limiting en mémoire (memory store)
- ⚠️ Ne fonctionne pas en multi-instances
- ⚠️ Compteurs perdus au redémarrage
- ✅ L'application continue de fonctionner
- Logs : `ℹ️  Redis non configuré (REDIS_URL non défini). Rate limiting en mémoire.`

## Rate Limits configurés

### Authentification

| Endpoint | Limite | Fenêtre |
|----------|--------|---------|
| Login | 30 req | 15 min |
| Register | 20 req | 15 min |
| Send OTP | 10 req | 15 min |
| Verify OTP | 20 req | 15 min |

### Uploads

| Type | Limite | Fenêtre |
|------|--------|---------|
| Avatar | 10 uploads | 15 min |
| Message files | 20 uploads | 15 min |
| Vehicle photos | 15 uploads | 15 min |
| Vehicle documents | 10 uploads | 15 min |
| Background | 5 uploads | 15 min |

### Géospatial

| Endpoint | Limite | Fenêtre |
|----------|--------|---------|
| Get rides nearby | 10 req | 1 min |
| Autres endpoints géospatiaux | Configurable | Configurable |

## Préfixes Redis

Les clés Redis sont organisées par préfixes :

- `otp:send:` - Envoi d'OTP
- `otp:verify:` - Vérification OTP
- `auth:login:` - Connexion
- `auth:register:` - Inscription
- `upload:avatar:` - Upload avatar
- `upload:message:` - Upload fichiers messages
- `upload:vehicle:` - Upload photos véhicules
- `upload:vehicle-doc:` - Upload documents véhicules
- `upload:background:` - Upload backgrounds
- `geospatial:` - Requêtes géospatiales

## Vérification

### Tester la connexion Redis

```bash
# Depuis le terminal
redis-cli ping
# Devrait répondre: PONG
```

### Vérifier les clés de rate limiting

```bash
# Lister toutes les clés de rate limiting
redis-cli KEYS "rl:*"

# Voir une clé spécifique
redis-cli GET "rl:auth:login:192.168.1.100"

# Voir le TTL d'une clé
redis-cli TTL "rl:auth:login:192.168.1.100"
```

### Vérifier depuis l'application

Les logs au démarrage indiquent l'état de Redis :

```
✅ Redis: Connexion établie
✅ Redis: Prêt à recevoir des commandes
✅ Redis: Connexion testée avec succès
```

## Dépannage

### Problème : Redis ne se connecte pas

**Symptômes** :
```
❌ Redis: Erreur: connect ECONNREFUSED 127.0.0.1:6379
ℹ️  Fallback vers memory store pour rate limiting.
```

**Solutions** :
1. Vérifier que Redis est démarré : `redis-cli ping`
2. Vérifier l'URL dans `.env` : `REDIS_URL=redis://localhost:6379`
3. Vérifier les permissions de connexion
4. Vérifier le firewall

### Problème : Rate limiting trop strict

**Solution** : Les limites sont configurables dans les middlewares. En développement, les limites sont multipliées par 5 automatiquement.

### Problème : Rate limiting ne fonctionne pas en multi-instances

**Cause** : Redis n'est pas configuré, utilisation du memory store

**Solution** : Configurer Redis avec `REDIS_URL`

### Problème : Erreurs Redis dans les logs

**Comportement** : L'application bascule automatiquement vers memory store et continue de fonctionner. Les erreurs Redis sont loggées mais n'arrêtent pas l'application.

## Production

### Recommandations

1. **Utiliser Redis Cloud ou un service managé** pour la haute disponibilité
2. **Configurer la persistance Redis** (RDB ou AOF) pour ne pas perdre les compteurs
3. **Monitorer Redis** avec des outils comme RedisInsight
4. **Configurer des alertes** si Redis devient indisponible
5. **Utiliser Redis Sentinel** pour la haute disponibilité (optionnel)

### Exemple de configuration production

```env
# Redis Cloud
REDIS_URL=redis://default:your-password@redis-12345.c1.us-east-1-1.ec2.cloud.redislabs.com:12345
REDIS_ENABLED=true
```

### Monitoring

```bash
# Voir les statistiques Redis
redis-cli INFO stats

# Voir l'utilisation mémoire
redis-cli INFO memory

# Monitorer les commandes en temps réel
redis-cli MONITOR
```

## Migration depuis memory store

Si vous migrez d'un memory store vers Redis :

1. Les compteurs existants en mémoire seront perdus (normal)
2. Les nouveaux compteurs seront dans Redis
3. Aucune action manuelle nécessaire, la migration est transparente

## Désactiver Redis

Pour désactiver Redis et utiliser uniquement le memory store :

```env
REDIS_ENABLED=false
```

Ou simplement ne pas définir `REDIS_URL`.

