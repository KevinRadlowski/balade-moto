# Référentiel Motos France

Ce dossier contient les fichiers JSON de référence pour les motos en France, organisés par année (2005-2024).

## Format des fichiers

- `YYYY_models.json` : Liste des top 20 marques pour l'année YYYY
- `YYYY_makes.json` : Marques avec leurs modèles/générations pour l'année YYYY

## Génération

Pour régénérer les fichiers :

```bash
npm run generate:fr:motos
```

Les fichiers seront générés dans `src/assets/reference/vehicles/motos/fr/`.

## Structure des données

- **Marques** : Top 20 marques motos populaires en France (stable pour toutes les années)
- **Modèles** : Générations de modèles filtrées par année selon les plages start/end

