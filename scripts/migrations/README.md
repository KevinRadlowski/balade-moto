# Migrations de base de données

Ce dossier contient les scripts de migration pour normaliser et mettre à jour les données de la base de données.

## Migration 001: Normalisation des rôles utilisateur

**Fichier:** `001_normalize_user_roles.js`

**Objectif:** Convertir les anciens rôles en minuscules vers les nouveaux rôles en majuscules standardisés.

**Transformations:**
- `"user"` → `"MEMBER"`
- `"admin"` → `"ADMIN"`
- `null` / `undefined` / `""` → `"MEMBER"`

**Usage:**
```bash
npm run migrate:roles
```

**Résultat attendu:**
- Tous les utilisateurs avec `role: "user"` sont convertis en `role: "MEMBER"`
- Tous les utilisateurs avec `role: "admin"` sont convertis en `role: "ADMIN"`
- Tous les utilisateurs sans rôle ou avec un rôle vide reçoivent `role: "MEMBER"`

**Note:** Cette migration est idempotente et peut être exécutée plusieurs fois sans risque.

## Vérification après migration

1. Exécuter la migration: `npm run migrate:roles`
2. Relancer le serveur: `npm start` ou `npm run dev`
3. Tester le login avec un utilisateur existant
4. Vérifier que l'erreur `User validation failed: role: 'user' is not a valid enum value` n'apparaît plus

