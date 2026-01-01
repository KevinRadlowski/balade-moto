# Feature de Navigation - Documentation

## Vue d'ensemble

Cette feature implémente un système complet de navigation pour les balades, permettant d'ouvrir des itinéraires (départ + checkpoints + arrivée) dans différentes applications de navigation (Google Maps, Waze, Apple Plans, etc.).

## Architecture

### Services

1. **NavigationService** (`lib/services/navigation/navigation_service.dart`)
   - Service centralisé pour la gestion de la navigation
   - Normalise les waypoints (enlève doublons, limite le nombre)
   - Extrait départ, checkpoints et arrivée
   - Gère les providers de navigation

2. **StepByStepNavigationService** (`lib/services/navigation/step_by_step_navigation_service.dart`)
   - Gère la navigation par étapes pour les apps qui ne supportent pas les waypoints multiples
   - Stocke la progression localement (SharedPreferences)
   - Permet de reprendre une navigation interrompue

3. **GPXExporter** (`lib/services/navigation/gpx_exporter.dart`)
   - Génère des fichiers GPX pour exporter les itinéraires
   - Permet le partage vers d'autres apps GPS/moto

4. **AppDetector** (`lib/services/navigation/app_detector.dart`)
   - Détecte les apps de navigation installées
   - Fournit les URLs des stores pour installer les apps

### Providers

Chaque provider implémente `NavigationProvider` :

1. **GoogleMapsProvider** - Support complet des waypoints multiples (jusqu'à 25)
2. **WazeProvider** - Mode par étapes uniquement (ne supporte pas les waypoints multiples)
3. **ApplePlansProvider** - Mode par étapes (iOS uniquement)
4. **GenericProvider** - Fallback générique (format geo:)

### UI

1. **NavigationAppSelector** (`lib/widgets/navigation/navigation_app_selector.dart`)
   - Bottom sheet pour choisir l'app de navigation
   - Détecte les apps installées
   - Affiche les capacités de chaque app

2. **StepByStepNavigationScreen** (`lib/screens/navigation/step_by_step_navigation_screen.dart`)
   - Écran pour la navigation par étapes
   - Affiche la progression
   - Permet de naviguer étape par étape

## Utilisation

### Ouvrir la navigation depuis une balade

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (context) => NavigationAppSelector(
    waypoints: ride.waypoints!,
    rideId: ride.id,
    rideName: ride.titre,
  ),
);
```

## Capacités par app

| App | Waypoints multiples | Mode par étapes | Export GPX |
|-----|-------------------|-----------------|------------|
| Google Maps | ✅ (jusqu'à 25) | ❌ | ❌ |
| Waze | ❌ | ✅ | ❌ |
| Apple Plans | ❌ | ✅ | ❌ |
| Autre | ❌ | ❌ | ✅ |

## Mode par étapes

Pour les apps qui ne supportent pas les waypoints multiples (Waze, Apple Plans), un mode par étapes est proposé :

1. L'utilisateur choisit "Mode par étapes"
2. Un écran s'ouvre avec la liste complète des points
3. L'utilisateur ouvre la navigation vers le point actuel
4. Après avoir atteint le point, il peut passer à l'étape suivante
5. La progression est sauvegardée localement

## Export GPX

L'export GPX permet de partager l'itinéraire avec d'autres apps GPS/moto qui supportent ce format.

```dart
final exporter = GPXExporter();
await exporter.shareGPX(route, name: 'Ma balade');
```

## Tests

### Tests manuels recommandés

1. **Google Maps avec waypoints** :
   - Tester avec 0, 1, 5, 15, 25+ checkpoints
   - Vérifier que tous les points sont inclus dans l'URL

2. **Waze mode par étapes** :
   - Démarrer une navigation par étapes
   - Tester la progression (étape suivante/précédente)
   - Tester la reprise après fermeture de l'app
   - Tester la réinitialisation

3. **Détection d'apps** :
   - Tester avec Google Maps installé/non installé
   - Tester avec Waze installé/non installé
   - Tester sur iOS (Apple Plans)

4. **Export GPX** :
   - Générer un GPX
   - Partager vers une app compatible
   - Vérifier le contenu du fichier

## Limitations connues

1. **Waze** : Ne supporte pas les waypoints multiples dans l'URL (limitation de Waze)
2. **Apple Plans** : Ne supporte pas les waypoints multiples (limitation iOS)
3. **Google Maps** : Limite de 25 waypoints dans l'URL
4. **URL longue** : Si l'URL dépasse ~2000 caractères, les waypoints sont automatiquement réduits

## Améliorations futures

- [ ] Détection automatique de l'arrivée à un checkpoint (géolocalisation)
- [ ] Support de plus d'apps (TomTom, Sygic, etc.)
- [ ] Import de routes GPX
- [ ] Calcul de distance/temps estimé
- [ ] Mode hors ligne avec cache des itinéraires


