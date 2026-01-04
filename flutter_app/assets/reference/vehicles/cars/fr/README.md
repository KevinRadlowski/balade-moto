# Référentiel Véhicules Français - Voitures

Ce dossier contient le référentiel JSON des marques et modèles de voitures pour le marché français, généré automatiquement pour les années 2005 à 2024.

## Structure

Pour chaque année, deux fichiers sont générés :

- `YYYY_models.json` : Liste des top 20 marques de l'année
- `YYYY_makes.json` : Liste des marques avec leurs modèles/générations disponibles

### Format des fichiers

**YYYY_models.json** :
```json
{
  "year": 2020,
  "makes": ["RENAULT", "PEUGEOT", "CITROEN", ...]
}
```

**YYYY_makes.json** :
```json
{
  "year": 2020,
  "makeBlocks": [
    {
      "make": "RENAULT",
      "models": ["CLIO IV", "MEGANE IV", "CAPTUR II", ...]
    },
    ...
  ]
}
```

## Génération

Pour régénérer les fichiers :

```bash
npm run generate:fr:cars
```

Le script :
1. Télécharge automatiquement les données SDES depuis data.gouv.fr (pour 2011-2024)
2. Utilise un fallback pour les années 2005-2010
3. Génère les fichiers JSON dans ce dossier

## Données sources

- **2011-2024** : Données SDES (Service des données et études statistiques) sur les immatriculations de véhicules routiers, disponibles sur data.gouv.fr
- **2005-2010** : Fallback avec top 20 marques cohérent

## Modèles et générations

Les modèles sont organisés par générations avec des plages d'années. Seules les générations actives pour une année donnée sont incluses dans les fichiers.

Les marques couvertes incluent au minimum :
RENAULT, PEUGEOT, CITROEN, VOLKSWAGEN, FORD, TOYOTA, BMW, AUDI, MERCEDES-BENZ, NISSAN, FIAT, OPEL, SEAT, SKODA, HYUNDAI, KIA, SUZUKI, ALFA ROMEO, SMART

