# Filtrage des logs Android - Réduire le spam FrameEvents

## Problème

Les erreurs `E/FrameEvents: updateAcquireFence: Did not find frame` sont très fréquentes et polluent les logs. Ces erreurs sont généralement **non bloquantes** et n'affectent pas le fonctionnement de l'application.

## Solutions

### 1. Filtrer les logs dans Android Studio / Logcat

Dans Android Studio, utilisez un filtre pour exclure ces messages :

**Filtre à utiliser dans Logcat :**
```
^(?!.*FrameEvents.*updateAcquireFence).*$
```

Ou plus simple, utilisez un filtre négatif :
```
-FrameEvents
```

**Dans le terminal (adb logcat) :**
```bash
adb logcat | grep -v "FrameEvents.*updateAcquireFence"
```

### 2. Filtrer les logs dans Flutter

Créer un fichier `flutter_app/android/app/src/main/kotlin/com/example/balades_moto/MainActivity.kt` (si n'existe pas) ou modifier le fichier existant :

```kotlin
package com.example.balades_moto

import io.flutter.embedding.android.FlutterActivity
import android.util.Log

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Filtrer les logs FrameEvents
        Log.setLogcatFilter { tag, priority, message ->
            !message.contains("updateAcquireFence")
        }
    }
}
```

### 3. Utiliser un wrapper logcat personnalisé

Créer un script pour filtrer les logs :

**Windows (PowerShell) :**
```powershell
adb logcat | Select-String -Pattern "^(?!.*FrameEvents.*updateAcquireFence)" | Select-String -Pattern "^(?!.*ProxyAndroidLoggerBackend)"
```

**Linux/Mac :**
```bash
adb logcat | grep -v "FrameEvents.*updateAcquireFence" | grep -v "ProxyAndroidLoggerBackend"
```

### 4. Configuration dans build.gradle (optionnel)

Ajouter dans `flutter_app/android/app/build.gradle` :

```gradle
android {
    // ...
    buildTypes {
        debug {
            // Réduire la verbosité des logs en mode debug
            buildConfigField "boolean", "ENABLE_VERBOSE_LOGS", "false"
        }
    }
}
```

## Notes importantes

- ✅ **Ces erreurs sont normales** et n'indiquent pas un problème critique
- ✅ **L'application fonctionne correctement** malgré ces messages
- ✅ **Google Maps génère souvent ces erreurs** - c'est un comportement connu
- ⚠️ Si l'application est **lente ou lag**, cela peut indiquer un problème de performance réel

## Vérifier les performances

Si vous suspectez un problème de performance :

1. **Vérifier le FPS** : Utilisez Flutter DevTools pour voir les performances
2. **Vérifier la mémoire** : Surveillez l'utilisation mémoire
3. **Vérifier les animations** : Assurez-vous que les animations ne sont pas trop lourdes

## Commandes utiles

**Voir uniquement les erreurs Flutter :**
```bash
adb logcat | grep -i flutter
```

**Voir uniquement les erreurs critiques :**
```bash
adb logcat *:E
```

**Voir les logs sans FrameEvents :**
```bash
adb logcat | grep -v "FrameEvents"
```


