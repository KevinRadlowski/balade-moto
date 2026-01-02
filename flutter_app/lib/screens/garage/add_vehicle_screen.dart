import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../models/vehicle.dart';
import '../../models/catalog_make.dart';
import '../../models/catalog_model.dart';
import '../../services/garage_service.dart';
import '../../services/catalog_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/garage/searchable_select.dart';

class AddVehicleScreen extends StatefulWidget {
  final Vehicle? vehicle;

  const AddVehicleScreen({super.key, this.vehicle});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final GarageService _garageService = GarageService();
  late final CatalogService _catalogService;

  // Champs du formulaire
  String? _type; // 'moto' ou 'voiture'
  final _nicknameController = TextEditingController();
  final _notesController = TextEditingController();
  String? _fuel;
  final _powerController = TextEditingController();
  final _odometerController = TextEditingController(text: '0');
  bool _enableRecommendedMaintenancePack = false;

  // Sélection catalogue CarAPI
  int? _year;
  List<CatalogMake> _makes = [];
  CatalogMake? _selectedMake;
  List<CatalogModel> _models = [];
  CatalogModel? _selectedModel;
  bool _useCatalog = true; // Par défaut, utiliser le catalogue CarAPI

  // Marques populaires voitures (affichées en premier)
  static const List<String> _popularCarMakes = [
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Toyota',
    'Honda',
    'Ford',
    'Volkswagen',
    'Porsche',
    'Ferrari',
    'Lamborghini',
  ];

  // Marques populaires motos (affichées en premier)
  static const List<String> _popularMotoMakes = [
    'Honda',
    'Yamaha',
    'Kawasaki',
    'Suzuki',
    'BMW',
    'KTM',
    'Ducati',
    'Triumph',
    'Harley-Davidson',
    'Royal Enfield',
    'Aprilia',
    'Moto Guzzi',
    'Husqvarna',
    'Indian',
    'Benelli',
    'CF Moto',
    'Piaggio',
    'Vespa',
    'Kymco',
    'SYM',
    'Zero',
    'MV Agusta',
    'Peugeot Motocycles',
    'GasGas',
    'Sherco',
    'Beta',
    'Derbi',
    'Norton',
  ];

  // États de chargement
  bool _isLoadingMakes = false;
  bool _isLoadingModels = false;
  bool _isSubmitting = false;
  String? _makesError;
  String? _modelsError;

  // Champs manuels (si useCatalog = false)
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Initialiser CatalogService avec le même ApiService que AuthService
    final authService = Provider.of<AuthService>(context, listen: false);
    _catalogService = CatalogService(apiService: authService.apiService);
    
    // Si on édite un véhicule existant, pré-remplir les champs
    if (widget.vehicle != null) {
      final v = widget.vehicle!;
      _type = v.type;
      _nicknameController.text = v.nickname ?? '';
      _makeController.text = v.make ?? '';
      _modelController.text = v.model ?? '';
      if (v.year != null) {
        _year = v.year;
        _yearController.text = v.year.toString();
      }
      _fuel = v.engine?.fuel;
      if (v.engine?.powerHp != null) {
        _powerController.text = v.engine!.powerHp.toString();
      }
      _odometerController.text = v.odometerCurrentKm.toString();
      _notesController.text = v.notes ?? '';
      // Note: selectionSource n'est pas encore dans le modèle Vehicle Flutter
      // _useCatalog = v.selectionSource == 'VPIC';
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _powerController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMakes() async {
    if (_type == null || _year == null) {
      debugPrint('[AddVehicle] _loadMakes: type ou année est null, abandon');
      return;
    }

    debugPrint('[AddVehicle] _loadMakes démarré pour type: $_type, year: $_year');

    setState(() {
      _isLoadingMakes = true;
      _makesError = null;
    });

    try {
      debugPrint('[AddVehicle] Appel catalogService.fetchMakes($_type, $_year)');
      final makes = await _catalogService.fetchMakes(_type!, _year!);
      debugPrint('[AddVehicle] fetchMakes retourné ${makes.length} marques');
      
      if (mounted) {
        setState(() {
          _makes = makes;
          _isLoadingMakes = false;
        });
        debugPrint('[AddVehicle] État mis à jour: ${_makes.length} marques disponibles');
      }
    } catch (e, stackTrace) {
      debugPrint('[AddVehicle] ERREUR dans _loadMakes: $e');
      debugPrint('[AddVehicle] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          // Extraire un message d'erreur lisible
          String errorMessage = 'Erreur lors du chargement des marques';
          if (e is Exception) {
            final message = e.toString();
            if (message.contains('Parsing makes failed')) {
              errorMessage = 'Erreur de format de réponse';
            } else if (message.contains('401') || message.contains('403')) {
              errorMessage = 'Erreur d\'authentification';
            } else if (message.contains('timeout') || message.contains('Timeout')) {
              errorMessage = 'Timeout - veuillez réessayer';
            } else {
              errorMessage = message.replaceFirst('Exception: ', '');
            }
          }
          _makesError = errorMessage;
          _isLoadingMakes = false;
        });
      }
    }
  }

  Future<void> _loadModels() async {
    if (_type == null || _selectedMake == null || _year == null) return;

    setState(() {
      _isLoadingModels = true;
      _modelsError = null;
    });

    try {
      debugPrint('[AddVehicle] Appel catalogService.fetchModels($_type, ${_selectedMake!.id}, $_year)');
      final models = await _catalogService.fetchModels(
        _type!,
        _selectedMake!.id, // Utiliser l'ID au lieu du nom
        _year!,
      );
      debugPrint('[AddVehicle] fetchModels retourné ${models.length} modèles');
      if (mounted) {
        setState(() {
          _models = models;
          _isLoadingModels = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[AddVehicle] ERREUR dans _loadModels: $e');
      debugPrint('[AddVehicle] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          String errorMessage = 'Erreur lors du chargement des modèles';
          if (e is Exception) {
            final message = e.toString();
            errorMessage = message.replaceFirst('Exception: ', '');
          }
          _modelsError = errorMessage;
          _isLoadingModels = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_type == null) {
      SnackBarHelper.showError(context, 'Veuillez sélectionner un type de véhicule');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final payload = <String, dynamic>{
        'type': _type!,
        'odometerCurrentKm': int.tryParse(_odometerController.text) ?? 0,
        if (_enableRecommendedMaintenancePack) 'enableRecommendedMaintenancePack': true,
      };

      // Champs optionnels
      if (_nicknameController.text.isNotEmpty) {
        payload['nickname'] = _nicknameController.text.trim();
      }

      if (_notesController.text.isNotEmpty) {
        payload['notes'] = _notesController.text.trim();
      }

      // Moteur
      if (_fuel != null || _powerController.text.isNotEmpty) {
        payload['engine'] = {};
        if (_fuel != null) {
          payload['engine']['fuel'] = _fuel;
        }
        if (_powerController.text.isNotEmpty) {
          final power = int.tryParse(_powerController.text);
          if (power != null) {
            payload['engine']['powerHp'] = power;
          }
        }
      }

      // Si utilisation du catalogue externe (CarAPI)
      if (_useCatalog) {
        if (_selectedMake == null || _selectedModel == null || _year == null) {
          SnackBarHelper.showError(
            context,
            'Veuillez compléter la sélection via le catalogue (marque, modèle, année)',
          );
          setState(() {
            _isSubmitting = false;
          });
          return;
        }

        payload['selectionSource'] = 'CATALOG';
        payload['make'] = _selectedMake!.name;
        payload['model'] = _selectedModel!.name;
        payload['year'] = _year!;
        
        // Nouveau format unifié: externalCatalog (CarAPI.app)
        payload['externalCatalog'] = {
          'provider': 'CARAPI',
          'vehicleType': _type!,
          'makeId': _selectedMake!.id, // Déjà une string
          'modelId': _selectedModel!.id, // Déjà une string
          'year': _year!,
        };
        
        debugPrint('[AddVehicle] Payload avec catalogue: ${jsonEncode(payload)}');
      } else {
        // Saisie manuelle
        payload['selectionSource'] = 'MANUAL';
        if (_makeController.text.isNotEmpty) {
          payload['make'] = _makeController.text.trim();
        }
        if (_modelController.text.isNotEmpty) {
          payload['model'] = _modelController.text.trim();
        }
        if (_yearController.text.isNotEmpty) {
          final year = int.tryParse(_yearController.text);
          if (year != null) {
            payload['year'] = year;
          }
        }
      }

      if (widget.vehicle != null) {
        // Mise à jour
        await _garageService.updateVehicle(widget.vehicle!.id, payload);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Véhicule modifié avec succès');
          Navigator.of(context).pop(true);
        }
      } else {
        // Création
        await _garageService.createVehicle(payload);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Véhicule créé avec succès');
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          widget.vehicle != null
              ? 'Erreur lors de la modification du véhicule'
              : 'Erreur lors de la création du véhicule',
        );
      }
      debugPrint('Erreur submitForm: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Construire le champ de recherche pour les marques avec marques populaires
  Widget _buildMakeSearchField() {
    // Organiser les marques : populaires en premier, puis les autres
    List<CatalogMake> sortedMakes = [];
    List<CatalogMake> popularMakes = [];
    List<CatalogMake> otherMakes = [];

    // Utiliser la bonne liste de marques populaires selon le type
    final popularMakesList = _type == 'moto' ? _popularMotoMakes : _popularCarMakes;

    for (var make in _makes) {
      if (popularMakesList.contains(make.name.toUpperCase())) {
        popularMakes.add(make);
      } else {
        otherMakes.add(make);
      }
    }

    // Trier les marques populaires selon l'ordre défini
    popularMakes.sort((a, b) {
      int indexA = popularMakesList.indexWhere((name) => name == a.name.toUpperCase());
      int indexB = popularMakesList.indexWhere((name) => name == b.name.toUpperCase());
      if (indexA == -1) indexA = 999;
      if (indexB == -1) indexB = 999;
      return indexA.compareTo(indexB);
    });

    // Trier les autres marques par ordre alphabétique
    otherMakes.sort((a, b) => a.name.compareTo(b.name));

    sortedMakes = [...popularMakes, ...otherMakes];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormField<CatalogMake>(
          initialValue: _selectedMake,
          validator: (value) {
            if (_useCatalog && value == null) {
              return 'La marque est requise';
            }
            return null;
          },
          builder: (FormFieldState<CatalogMake> field) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchableSelect<CatalogMake>(
                  label: 'Marque *',
                  hint: _type == null || _year == null
                      ? 'Sélectionnez d\'abord le type et l\'année'
                      : 'Rechercher une marque...',
                  items: sortedMakes,
                  selectedItem: _selectedMake,
                  displayText: (make) => make.name,
                  onSelected: (CatalogMake? make) {
                    field.didChange(make);
                    setState(() {
                      _selectedMake = make;
                      // Réinitialiser le modèle si la marque change
                      _selectedModel = null;
                      _models = [];
                      // Recharger les modèles si année et marque sont sélectionnés
                      if (_selectedMake != null && _year != null) {
                        _loadModels();
                      }
                    });
                  },
                  isLoading: _isLoadingMakes,
                  errorMessage: _makesError ?? field.errorText,
                  prefixIcon: Icons.branding_watermark,
                  enabled: !_isLoadingMakes && _type != null && _year != null,
                  featuredItems: popularMakes,
                  featuredTitle: 'Marques populaires',
                  allTitle: 'Toutes les marques',
                  showSections: popularMakes.isNotEmpty,
                ),
              ],
            );
          },
        ),
        // Afficher les marques populaires si la liste est vide et qu'on n'a pas encore tapé
        if (popularMakes.isNotEmpty && _makes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marques populaires',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: popularMakes.take(10).map((make) {
                    final isSelected = _selectedMake?.id == make.id;
                    return FilterChip(
                      label: Text(make.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedMake = make;
                            _selectedModel = null;
                            _models = [];
                            if (_selectedMake != null && _year != null) {
                              _loadModels();
                            }
                          });
                        }
                      },
                      avatar: isSelected
                          ? const Icon(Icons.check, size: 18)
                          : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle != null ? 'Modifier le véhicule' : 'Ajouter un véhicule'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type de véhicule (requis)
            _buildSectionTitle('Type de véhicule *'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'moto',
                  label: Text('Moto'),
                  icon: Icon(Icons.two_wheeler),
                ),
                ButtonSegment(
                  value: 'voiture',
                  label: Text('Voiture'),
                  icon: Icon(Icons.directions_car),
                ),
              ],
              selected: _type != null ? {_type!} : <String>{},
              emptySelectionAllowed: true,
              onSelectionChanged: (Set<String> newSelection) {
                final newType = newSelection.firstOrNull;
                debugPrint('[AddVehicle] Type changé: $_type -> $newType');
                setState(() {
                  // Si le type change, réinitialiser les sélections
                  if (newType != _type) {
                    _selectedMake = null;
                    _selectedModel = null;
                    _models = [];
                    if (_useCatalog) {
                      _makes = [];
                    }
                    _makesError = null;
                    _modelsError = null;
                    _isLoadingMakes = false;
                    _isLoadingModels = false;
                  }
                  _type = newType;
                });
                
                // Charger les marques si type + année sont déjà sélectionnés
                if (_useCatalog && newType != null && _year != null && _makes.isEmpty && !_isLoadingMakes) {
                  debugPrint('[AddVehicle] Type ($newType) et année ($_year) sélectionnés, déclenchement _loadMakes()');
                  _loadMakes();
                }
              },
            ),
            const SizedBox(height: 24),

            // Informations principales
            _buildSectionTitle('Informations principales'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Surnom (optionnel)',
                hintText: 'Ex: Ma moto',
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 24),

            // Choix entre catalogue et saisie manuelle
            _buildSectionTitle('Mode de saisie'),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Utiliser le catalogue CarAPI'),
              subtitle: const Text('Sélectionner depuis le catalogue officiel'),
              value: _useCatalog,
              onChanged: (value) {
                debugPrint('[AddVehicle] Switch catalogue: $_useCatalog -> $value');
                setState(() {
                  _useCatalog = value;
                  // Réinitialiser les sélections
                  _selectedMake = null;
                  _selectedModel = null;
                  _models = [];
                  _makes = [];
                  _makesError = null;
                  _modelsError = null;
                  _isLoadingMakes = false;
                  _isLoadingModels = false;
                });
                // Charger les marques si catalogue activé, type et année sélectionnés
                if (value && _type != null && _year != null && _makes.isEmpty) {
                  debugPrint('[AddVehicle] Catalogue activé, déclenchement _loadMakes()');
                  _loadMakes();
                }
              },
            ),
            const SizedBox(height: 24),

            // Sélection via catalogue ou saisie manuelle
            if (_useCatalog) ...[
              // Année
              DropdownButtonFormField<int>(
                value: _year,
                decoration: const InputDecoration(
                  labelText: 'Année *',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: List.generate(
                  DateTime.now().year - 1900 + 2,
                  (index) {
                    final year = DateTime.now().year + 1 - index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  },
                ),
                onChanged: (value) {
                  debugPrint('[AddVehicle] Année changée: $_year -> $value');
                  setState(() {
                    final oldYear = _year;
                    _year = value;
                    // Réinitialiser les sélections et listes si l'année change
                    if (oldYear != value) {
                      _selectedMake = null;
                      _selectedModel = null;
                      _models = [];
                    }
                    _modelsError = null;
                    _isLoadingModels = false;
                  });
                  
                  // Charger automatiquement les marques si type + année sont sélectionnés
                  if (_useCatalog && _type != null && value != null && _makes.isEmpty && !_isLoadingMakes) {
                    debugPrint('[AddVehicle] Type ($_type) et année ($value) sélectionnés, déclenchement automatique _loadMakes()');
                    _loadMakes();
                  }
                  
                  // Recharger les modèles si marque et année sont sélectionnés
                  if (_selectedMake != null && value != null) {
                    debugPrint('[AddVehicle] Marque et année sélectionnées, déclenchement _loadModels()');
                    _loadModels();
                  }
                },
                validator: (value) {
                  if (_useCatalog && value == null) {
                    return 'L\'année est requise';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Marque (recherche avec marques populaires)
              _buildMakeSearchField(),
              const SizedBox(height: 16),

              // Modèle (recherche)
              FormField<CatalogModel>(
                initialValue: _selectedModel,
                validator: (value) {
                  if (_useCatalog && value == null) {
                    return 'Le modèle est requis';
                  }
                  return null;
                },
                builder: (FormFieldState<CatalogModel> field) {
                  return SearchableSelect<CatalogModel>(
                    label: 'Modèle *',
                    hint: _selectedMake == null || _year == null || _type == null
                        ? 'Sélectionnez d\'abord le type, la marque et l\'année'
                        : 'Rechercher un modèle...',
                    items: _models,
                    selectedItem: _selectedModel,
                    displayText: (model) => model.name,
                    onSelected: (CatalogModel? model) {
                      field.didChange(model);
                      setState(() {
                        _selectedModel = model;
                      });
                    },
                    isLoading: _isLoadingModels,
                    errorMessage: _modelsError ?? field.errorText,
                    prefixIcon: Icons.precision_manufacturing,
                    enabled: !_isLoadingModels && _type != null && _selectedMake != null && _year != null,
                  );
                },
              ),
            ] else ...[
              // Saisie manuelle
              TextFormField(
                controller: _makeController,
                decoration: const InputDecoration(
                  labelText: 'Marque',
                  hintText: 'Ex: Yamaha',
                  prefixIcon: Icon(Icons.branding_watermark),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Modèle',
                  hintText: 'Ex: MT-07',
                  prefixIcon: Icon(Icons.precision_manufacturing),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: 'Année (optionnel)',
                  hintText: 'Ex: 2020',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final year = int.tryParse(value);
                    if (year == null) {
                      return 'Année invalide';
                    }
                    final currentYear = DateTime.now().year;
                    if (year < 1900 || year > currentYear + 1) {
                      return 'Année invalide';
                    }
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),

            // Moteur
            _buildSectionTitle('Moteur (optionnel)'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _fuel,
              decoration: const InputDecoration(
                labelText: 'Carburant',
                prefixIcon: Icon(Icons.local_gas_station),
              ),
              items: const [
                DropdownMenuItem(value: 'essence', child: Text('Essence')),
                DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
                DropdownMenuItem(value: 'electrique', child: Text('Électrique')),
                DropdownMenuItem(value: 'hybride', child: Text('Hybride')),
                DropdownMenuItem(value: 'autre', child: Text('Autre')),
              ],
              onChanged: (value) {
                setState(() {
                  _fuel = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _powerController,
              decoration: const InputDecoration(
                labelText: 'Puissance (ch)',
                hintText: 'Ex: 73',
                prefixIcon: Icon(Icons.speed),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Kilométrage
            _buildSectionTitle('Kilométrage'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _odometerController,
              decoration: const InputDecoration(
                labelText: 'Kilométrage actuel',
                hintText: 'Ex: 5000',
                prefixIcon: Icon(Icons.speed),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Le kilométrage est requis';
                }
                final km = int.tryParse(value);
                if (km == null || km < 0) {
                  return 'Kilométrage invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Pack entretien recommandé
            _buildSectionTitle('Entretien'),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Activer pack entretien recommandé'),
              subtitle: const Text(
                'Crée automatiquement une liste de maintenances adaptées à votre véhicule',
              ),
              value: _enableRecommendedMaintenancePack,
              onChanged: (value) {
                setState(() {
                  _enableRecommendedMaintenancePack = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Notes
            _buildSectionTitle('Notes (optionnel)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Informations supplémentaires...',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Bouton de soumission
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.vehicle != null ? 'Modifier' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }
}
