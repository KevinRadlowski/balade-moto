import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';

/// Modèle pour les données de localisation extraites d'un Place
class LocationFilterData {
  final String? city;
  final String? departmentCode;
  final String? departmentName;
  final String? regionName;
  final String? countryCode;
  final double? lat;
  final double? lng;
  final String? displayName; // Nom d'affichage du lieu sélectionné

  LocationFilterData({
    this.city,
    this.departmentCode,
    this.departmentName,
    this.regionName,
    this.countryCode,
    this.lat,
    this.lng,
    this.displayName,
  });

  bool get hasLocation => city != null || departmentCode != null || regionName != null;
  bool get hasCoordinates => lat != null && lng != null;
}

/// Widget d'autocomplétion pour les lieux (Google Places Autocomplete)
class LocationAutocompleteField extends StatefulWidget {
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final ValueChanged<LocationFilterData?>? onLocationSelected;
  final String? Function(String?)? validator;

  const LocationAutocompleteField({
    super.key,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.onLocationSelected,
    this.validator,
  });

  @override
  State<LocationAutocompleteField> createState() => _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // Ne pas disposer _focusNode car il est géré par Autocomplete
    super.dispose();
  }

  /// Appelle l'API backend pour Places Autocomplete
  Future<List<Map<String, dynamic>>> _fetchSuggestions(String query) async {
    if (query.length < 2) {
      return [];
    }

    // Différer setState() pour éviter l'erreur "setState() called during build"
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
    });

    try {
      // Utiliser le backend pour éviter les problèmes CORS
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        if (token != null) {
          _apiService.setToken(token);
        }
      } catch (e) {
        debugPrint('Erreur lors de la récupération du token: $e');
        // Continuer même sans token (pour les cas où l'utilisateur n'est pas connecté)
      }

      final result = await _apiService.placesAutocomplete(query);
      
      if (result['success'] == true && result['data'] != null) {
        final predictions = (result['data']['predictions'] as List?) ?? [];
        return predictions.map((p) => p as Map<String, dynamic>).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Erreur lors de la récupération des suggestions: $e');
      return [];
    } finally {
      // Différer setState() pour éviter l'erreur "setState() called during build"
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  /// Récupère les détails d'un lieu via Place Details (backend)
  Future<Map<String, dynamic>?> _fetchPlaceDetails(String placeId) async {
    try {
      // Utiliser le backend pour éviter les problèmes CORS
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.storage.read(key: 'token');
        if (token != null) {
          _apiService.setToken(token);
        }
      } catch (e) {
        debugPrint('Erreur lors de la récupération du token: $e');
        // Continuer même sans token
      }

      final result = await _apiService.placeDetails(placeId);
      
      if (result['success'] == true && result['data'] != null) {
        return result['data'] as Map<String, dynamic>?;
      }

      return null;
    } catch (e) {
      debugPrint('Erreur lors de la récupération des détails du lieu: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, dynamic>>(
      initialValue: widget.initialValue != null
          ? TextEditingValue(text: widget.initialValue!)
          : null,
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text.trim();
        return await _fetchSuggestions(query);
      },
      displayStringForOption: (option) {
        return option['description'] as String? ?? '';
      },
      onSelected: (option) async {
        final placeId = option['place_id'] as String?;
        if (placeId == null) return;

        // Récupérer les détails du lieu
        final placeDetails = await _fetchPlaceDetails(placeId);
        if (placeDetails == null) return;

        // Parser les données de localisation
        final locationData = parsePlaceToLocationFilter(placeDetails);

        // Mettre à jour le texte du champ
        _controller.text = locationData.displayName ?? option['description'] ?? '';

        // Appeler le callback
        widget.onLocationSelected?.call(locationData);
        
        // Fermer le clavier et perdre le focus pour fermer le dropdown
        _focusNode?.unfocus();
        FocusScope.of(context).unfocus();
      },
      fieldViewBuilder: (
        context,
        textEditingController,
        focusNode,
        onFieldSubmitted,
      ) {
        // Stocker le focusNode pour pouvoir le réutiliser
        _focusNode = focusNode;
        
        // Synchroniser le controller externe avec celui d'Autocomplete
        if (textEditingController.text != _controller.text) {
          textEditingController.text = _controller.text;
        }

        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText ?? 'Lieu',
            hintText: widget.hintText ?? 'Tapez une ville, région ou département...',
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : textEditingController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          textEditingController.clear();
                          _controller.clear();
                          widget.onLocationSelected?.call(null);
                        },
                      )
                    : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            _controller.text = value;
          },
          onSubmitted: (value) {
            onFieldSubmitted();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final description = option['description'] as String? ?? '';
                  final structuredFormatting = option['structured_formatting'] as Map<String, dynamic>?;
                  final mainText = structuredFormatting?['main_text'] as String? ?? description;
                  final secondaryText = structuredFormatting?['secondary_text'] as String? ?? '';

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place, size: 20),
                    title: Text(
                      mainText,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: secondaryText.isNotEmpty
                        ? Text(
                            secondaryText,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          )
                        : null,
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Parse les données d'un Place Details pour extraire les informations de localisation
LocationFilterData parsePlaceToLocationFilter(Map<String, dynamic> placeDetails) {
  final addressComponents = placeDetails['address_components'] as List? ?? [];
  final geometry = placeDetails['geometry'] as Map<String, dynamic>?;
  final location = geometry?['location'] as Map<String, dynamic>?;
  final formattedAddress = placeDetails['formatted_address'] as String? ?? placeDetails['name'] as String? ?? '';

  String? city;
  String? departmentCode; // Sera extrait depuis address_components ou code postal
  String? departmentName;
  String? regionName;
  String? countryCode;
  double? lat;
  double? lng;

  // Extraire lat/lng
  if (location != null) {
    lat = (location['lat'] as num?)?.toDouble();
    lng = (location['lng'] as num?)?.toDouble();
  }

  // Parser les address_components
  for (final component in addressComponents) {
    final types = (component['types'] as List?)?.cast<String>() ?? [];
    final longName = component['long_name'] as String? ?? '';
    final shortName = component['short_name'] as String? ?? '';

    // Ville (locality ou postal_town)
    if (types.contains('locality') || types.contains('postal_town')) {
      city = longName;
    }

    // Département (administrative_area_level_2)
    if (types.contains('administrative_area_level_2')) {
      departmentName = longName;
      // Parfois le code est dans short_name
      if (shortName.isNotEmpty && shortName.length <= 3) {
        departmentCode = shortName;
      }
    }

    // Région (administrative_area_level_1)
    if (types.contains('administrative_area_level_1')) {
      regionName = longName;
    }

    // Pays
    if (types.contains('country')) {
      countryCode = shortName;
    }
  }

  // Extraire le code postal pour déterminer le département (si non fourni)
  String? postalCode;
  for (final component in addressComponents) {
    final types = (component['types'] as List?)?.cast<String>() ?? [];
    if (types.contains('postal_code')) {
      postalCode = component['long_name'] as String?;
      break;
    }
  }

  // Déterminer le code département si non fourni
  if (departmentCode == null) {
    // Cas spécial: Paris
    if (city == 'Paris' || departmentName == 'Paris') {
      departmentCode = '75';
    }
    // Sinon, utiliser les 2-3 premiers chiffres du code postal
    else if (postalCode != null && postalCode.length >= 2) {
      final code = postalCode.substring(0, 2);
      // Vérifier si c'est un DOM (971, 972, 973, 974, 976)
      if (postalCode.length >= 3) {
        final domCode = postalCode.substring(0, 3);
        if (['971', '972', '973', '974', '976'].contains(domCode)) {
          departmentCode = domCode;
        } else {
          departmentCode = code;
        }
      } else {
        departmentCode = code;
      }
    }
  }

  // Construire le nom d'affichage
  String displayName = formattedAddress;
  if (city != null && city.isNotEmpty) {
    displayName = city;
    if (departmentName != null && departmentName.isNotEmpty) {
      displayName = '$city, $departmentName';
    }
  } else if (departmentName != null && departmentName.isNotEmpty) {
    displayName = departmentName;
  } else if (regionName != null && regionName.isNotEmpty) {
    displayName = regionName;
  }

  return LocationFilterData(
    city: city,
    departmentCode: departmentCode,
    departmentName: departmentName,
    regionName: regionName,
    countryCode: countryCode,
    lat: lat,
    lng: lng,
    displayName: displayName,
  );
}

