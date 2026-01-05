# ⚠️ Warning Google Maps Marker Deprecated

## Contexte

Le warning suivant apparaît dans la console web :
```
As of February 21st, 2024, google.maps.Marker is deprecated. 
Please use google.maps.marker.AdvancedMarkerElement instead.
```

## Cause

Ce warning provient de la couche JavaScript de Google Maps utilisée par le package `google_maps_flutter_web`. Le package Flutter utilise encore `google.maps.Marker` en interne, qui est maintenant déprécié par Google.

## Statut actuel

- **Version actuelle** : `google_maps_flutter: ^2.5.0`
- **Support AdvancedMarkerElement** : Non encore disponible dans le package Flutter web
- **Impact** : Warning uniquement, pas d'erreur fonctionnelle
- **Date** : 2024-12-XX

## Plan de migration

1. **Surveiller les mises à jour** du package `google_maps_flutter`
2. **Quand AdvancedMarkerElement sera supporté** :
   - Mettre à jour `google_maps_flutter` vers la version supportant AdvancedMarkerElement
   - Tester sur web et mobile
   - Vérifier la compatibilité avec les markers existants

## Actions recommandées

- ✅ **Maintenant** : Accepter le warning (non bloquant)
- ⏳ **Futur** : Migrer vers AdvancedMarkerElement quand disponible
- 📝 **Documentation** : Ce fichier sert de référence pour la migration future

## Références

- [Google Maps Deprecations](https://developers.google.com/maps/deprecations)
- [Advanced Markers Migration Guide](https://developers.google.com/maps/documentation/javascript/advanced-markers/migration)
- [google_maps_flutter Package](https://pub.dev/packages/google_maps_flutter)

## Note

Ce warning n'affecte pas le fonctionnement de l'application. Les markers continuent de fonctionner normalement. Google a indiqué qu'au moins 12 mois de préavis seront donnés avant la suppression complète de `google.maps.Marker`.






