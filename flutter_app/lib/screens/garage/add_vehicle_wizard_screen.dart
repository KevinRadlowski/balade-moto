import 'package:flutter/material.dart';
import '../../models/vehicle.dart';
import '../../models/catalog_make.dart';
import '../../models/catalog_model.dart';
import '../../services/garage_service.dart';
import '../../services/catalog_service.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';

class AddVehicleWizardScreen extends StatefulWidget {
  final Vehicle? vehicle;

  const AddVehicleWizardScreen({super.key, this.vehicle});

  @override
  State<AddVehicleWizardScreen> createState() => _AddVehicleWizardScreenState();
}

class _AddVehicleWizardScreenState extends State<AddVehicleWizardScreen> {
  final GarageService _garageService = GarageService();
  late final CatalogService _catalogService;
  final PageController _pageController = PageController();

  // Étape 1: Type
  String? _type;

  // Étape 2: Année
  int? _year;
  final int _currentYear = DateTime.now().year;
  final int _minYear = 1900;

  // Étape 3: Marque
  List<CatalogMake> _makes = [];
  List<CatalogMake> _featuredMakes = [];
  List<CatalogMake> _remainingMakes = [];
  CatalogMake? _selectedMake;
  bool _isLoadingMakes = false;
  String? _makesError;

  // Marques populaires en France (ordre exact)
  static const List<String> _popularMakesNames = [
    // Voitures populaires
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Volkswagen',
    'Toyota',
    'Honda',
    'Ford',
    'Peugeot',
    'Renault',
    'Citroen',
    'Nissan',
    'Hyundai',
    'Kia',
    'Volvo',
    'Fiat',
    'Opel',
    'Mazda',
    'Subaru',
    'Porsche',
    'Jaguar',
    // Motos populaires (si disponibles)
    'Yamaha',
    'Triumph',
    'Kawasaki',
    'KTM',
    'Piaggio',
    'Harley-Davidson',
    'Ducati',
    'Suzuki',
    'Royal Enfield',
    'Aprilia',
    'Kymco',
    'SYM',
    'CFMoto',
  ];

  // Étape 4: Modèle
  List<CatalogModel> _models = [];
  CatalogModel? _selectedModel;
  bool _isLoadingModels = false;
  String? _modelsError;

  // Étape 5: Détails optionnels
  final _nicknameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _enableRecommendedMaintenancePack = false;

  // Étape 6: Création
  bool _isCreating = false;

  int _currentStep = 0;
  final int _totalSteps = 6;

  @override
  void initState() {
    super.initState();
    
    // Initialiser CatalogService avec le même ApiService que AuthService
    final authService = Provider.of<AuthService>(context, listen: false);
    _catalogService = CatalogService(apiService: authService.apiService);
    
    if (widget.vehicle != null) {
      _type = widget.vehicle!.type;
      _nicknameController.text = widget.vehicle!.nickname ?? '';
      _notesController.text = widget.vehicle!.notes ?? '';
      if (widget.vehicle!.year != null) {
        _year = widget.vehicle!.year;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nicknameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      final nextStep = _currentStep + 1;
      
      debugPrint('[Wizard] _nextStep: étape $_currentStep -> $nextStep');
      
      // Déclencher les chargements selon l'étape suivante
      if (nextStep == 2) {
        // Étape Marque (index 2) - nécessite type ET année
        if (_type != null && _year != null) {
          debugPrint('[Wizard] Passage à l\'étape Marque, déclenchement _loadMakes()');
          _loadMakes();
        }
      } else if (nextStep == 3) {
        // Étape Modèle (index 3) - nécessite type, année ET marque
        if (_type != null && _year != null && _selectedMake != null) {
          debugPrint('[Wizard] Passage à l\'étape Modèle, déclenchement _loadModels()');
          _loadModels();
        }
      }
      
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep = nextStep;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _loadMakes() async {
    if (_type == null) {
      debugPrint('[Wizard] _loadMakes: type est null, abandon');
      return;
    }

    debugPrint('[Wizard] _loadMakes démarré pour type: $_type');

    setState(() {
      _isLoadingMakes = true;
      _makesError = null;
    });

    if (_year == null) {
      debugPrint('[Wizard] _loadMakes: year est null, abandon');
      return;
    }

    try {
      debugPrint('[Wizard] Appel catalogService.fetchMakes($_type, $_year)');
      final makes = await _catalogService.fetchMakes(_type!, _year!);
      debugPrint('[Wizard] fetchMakes retourné ${makes.length} marques');
      
      if (mounted) {
        // Organiser les marques : populaires en premier, puis les autres
        _organizeMakes(makes);
        setState(() {
          _makes = makes;
          _isLoadingMakes = false;
          // Forcer la mise à jour des listes organisées dans le setState
        });
        debugPrint('[Wizard] État mis à jour: ${_makes.length} marques disponibles (${_featuredMakes.length} populaires, ${_remainingMakes.length} autres)');
      }
    } catch (e, stackTrace) {
      debugPrint('[Wizard] ERREUR dans _loadMakes: $e');
      debugPrint('[Wizard] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _makesError = 'Erreur lors du chargement des marques: ${e.toString()}';
          _isLoadingMakes = false;
        });
      }
    }
  }

  // Organiser les marques en populaires et autres
  void _organizeMakes(List<CatalogMake> allMakes) {
    _featuredMakes = [];
    _remainingMakes = [];
    
    // Fonction pour normaliser un nom de marque (casse, espaces, tirets)
    String normalizeMakeName(String name) {
      return name.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    }
    
    // Créer un Map pour retrouver rapidement les marques populaires
    final Map<String, CatalogMake> popularMap = {};
    for (final popularName in _popularMakesNames) {
      final normalized = normalizeMakeName(popularName);
      // Chercher dans allMakes une marque qui correspond
      for (final make in allMakes) {
        if (normalizeMakeName(make.name) == normalized) {
          popularMap[normalized] = make;
          break;
        }
      }
    }
    
    // Construire _featuredMakes dans l'ordre exact de _popularMakesNames
    for (final popularName in _popularMakesNames) {
      final normalized = normalizeMakeName(popularName);
      if (popularMap.containsKey(normalized)) {
        _featuredMakes.add(popularMap[normalized]!);
      }
    }
    
    // Construire _remainingMakes avec les marques non populaires, triées alphabétiquement
    final featuredNormalized = _featuredMakes
        .map((make) => normalizeMakeName(make.name))
        .toSet();
    
    _remainingMakes = allMakes
        .where((make) => !featuredNormalized.contains(normalizeMakeName(make.name)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    
    debugPrint('[Wizard] _organizeMakes: ${_featuredMakes.length} populaires, ${_remainingMakes.length} autres');
  }

  // Construire la liste des items pour le dropdown avec les marques populaires en premier
  List<DropdownMenuItem<CatalogMake>> _buildMakeDropdownItems() {
    debugPrint('[Wizard] _buildMakeDropdownItems: ${_featuredMakes.length} populaires, ${_remainingMakes.length} autres, ${_makes.length} total');
    
    final List<DropdownMenuItem<CatalogMake>> items = [];
    
    // Si aucune marque n'est chargée, retourner une liste vide
    if (_makes.isEmpty && _featuredMakes.isEmpty && _remainingMakes.isEmpty) {
      debugPrint('[Wizard] _buildMakeDropdownItems: aucune marque disponible');
      return items;
    }
    
    // Ajouter les marques populaires en premier
    if (_featuredMakes.isNotEmpty) {
      // Ajouter un séparateur visuel pour les marques populaires
      items.add(
        DropdownMenuItem<CatalogMake>(
          enabled: false,
          child: Text(
            'Marques populaires',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
      
      for (final make in _featuredMakes) {
        items.add(
          DropdownMenuItem<CatalogMake>(
            value: make,
            child: Text(make.name),
          ),
        );
      }
    }
    
    // Ajouter les autres marques
    if (_remainingMakes.isNotEmpty) {
      // Ajouter un séparateur visuel pour toutes les marques
      if (_featuredMakes.isNotEmpty) {
        items.add(
          const DropdownMenuItem<CatalogMake>(
            enabled: false,
            child: Divider(height: 1),
          ),
        );
      }
      
      items.add(
        DropdownMenuItem<CatalogMake>(
          enabled: false,
          child: Text(
            'Toutes les marques',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
      
      for (final make in _remainingMakes) {
        items.add(
          DropdownMenuItem<CatalogMake>(
            value: make,
            child: Text(make.name),
          ),
        );
      }
    }
    
    // Si aucune marque n'a été ajoutée (ni populaires ni autres), utiliser toutes les marques
    if (items.isEmpty && _makes.isNotEmpty) {
      debugPrint('[Wizard] _buildMakeDropdownItems: utilisation de toutes les marques (${_makes.length})');
      for (final make in _makes) {
        items.add(
          DropdownMenuItem<CatalogMake>(
            value: make,
            child: Text(make.name),
          ),
        );
      }
    }
    
    debugPrint('[Wizard] _buildMakeDropdownItems: ${items.length} items retournés');
    return items;
  }

  Future<void> _loadModels() async {
    if (_type == null) {
      debugPrint('[Wizard] _loadModels: type est null, abandon');
      return;
    }
    if (_selectedMake == null) {
      debugPrint('[Wizard] _loadModels: selectedMake est null, abandon');
      return;
    }
    if (_year == null) {
      debugPrint('[Wizard] _loadModels: year est null, abandon');
      return;
    }

    debugPrint('[Wizard] _loadModels démarré pour type: $_type, make: ${_selectedMake!.name}, year: $_year');

    setState(() {
      _isLoadingModels = true;
      _modelsError = null;
    });

    try {
      debugPrint('[Wizard] Appel catalogService.fetchModels($_type, ${_selectedMake!.id}, $_year)');
      final models = await _catalogService.fetchModels(
        _type!,
        _selectedMake!.id,
        _year!,
      );
      debugPrint('[Wizard] fetchModels retourné ${models.length} modèles');
      
      if (mounted) {
        setState(() {
          _models = models;
          _isLoadingModels = false;
        });
        debugPrint('[Wizard] État mis à jour: ${_models.length} modèles disponibles');
      }
    } catch (e, stackTrace) {
      debugPrint('[Wizard] ERREUR dans _loadModels: $e');
      debugPrint('[Wizard] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _modelsError = 'Erreur lors du chargement des modèles: ${e.toString()}';
          _isLoadingModels = false;
        });
      }
    }
  }

  Future<void> _createVehicle() async {
    if (_type == null ||
        _selectedMake == null ||
        _selectedModel == null ||
        _year == null) {
      SnackBarHelper.showError(context, 'Veuillez compléter toutes les étapes');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Convertir les IDs en entiers (le backend attend des numbers)
      final makeIdInt = int.tryParse(_selectedMake!.id) ?? 0;
      final modelIdInt = int.tryParse(_selectedModel!.id) ?? 0;
      
      if (makeIdInt == 0 || modelIdInt == 0) {
        throw Exception('IDs de marque ou modèle invalides');
      }

      final payload = <String, dynamic>{
        'type': _type!,
        'selectionSource': 'CATALOG',
        'make': _selectedMake!.name,
        'model': _selectedModel!.name,
        'year': _year!,
        'odometerCurrentKm': 0,
        // Nouveau format unifié: externalCatalog avec provider CARAPI
        'externalCatalog': {
          'provider': 'CARAPI',
          'vehicleType': _type!,
          'makeId': makeIdInt, // Entier (number)
          'modelId': modelIdInt, // Entier (number)
          'year': _year!,
        },
        if (_enableRecommendedMaintenancePack)
          'enableRecommendedMaintenancePack': true,
      };

      if (_nicknameController.text.isNotEmpty) {
        payload['nickname'] = _nicknameController.text.trim();
      }

      if (_notesController.text.isNotEmpty) {
        payload['notes'] = _notesController.text.trim();
      }

      await _garageService.createVehicle(payload);

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Véhicule créé avec succès');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Erreur lors de la création du véhicule',
        );
      }
      debugPrint('Erreur createVehicle: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0:
        return _type != null;
      case 1:
        return _year != null;
      case 2:
        return _selectedMake != null;
      case 3:
        return _selectedModel != null;
      case 4:
        return true; // Étape de confirmation, toujours possible
      case 5:
        return false; // Dernière étape
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter un véhicule (${_currentStep + 1}/$_totalSteps)'),
      ),
      body: Column(
        children: [
          // Indicateur de progression
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            minHeight: 4,
          ),
          const SizedBox(height: 8),
          // Contenu des étapes
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1Type(),
                _buildStep2Year(),
                _buildStep3Make(),
                _buildStep4Model(),
                _buildStep5Details(),
                _buildStep6Confirmation(),
              ],
            ),
          ),
          // Boutons de navigation
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  TextButton(
                    onPressed: _previousStep,
                    child: const Text('Précédent'),
                  )
                else
                  const SizedBox(),
                ElevatedButton(
                  onPressed: _canProceedToNextStep()
                      ? (_currentStep == _totalSteps - 1
                          ? _createVehicle
                          : _nextStep)
                      : null,
                  child: Text(_currentStep == _totalSteps - 1
                      ? (_isCreating ? 'Création...' : 'Créer')
                      : 'Suivant'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Type() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type de véhicule',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
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
              debugPrint('[Wizard] Type changé: $_type -> $newType');
              setState(() {
                // Si le type change, réinitialiser les étapes suivantes
                if (newType != _type) {
                  _selectedMake = null;
                  _selectedModel = null;
                  _makes = [];
                  _models = [];
                  _makesError = null;
                  _modelsError = null;
                  _isLoadingMakes = false;
                  _isLoadingModels = false;
                }
                _type = newType;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Year() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Année du véhicule',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<int>(
            value: _year,
            decoration: const InputDecoration(
              labelText: 'Année *',
              prefixIcon: Icon(Icons.calendar_today),
            ),
            items: List.generate(
              _currentYear - _minYear + 2,
              (index) {
                final year = _currentYear + 1 - index;
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              },
            ),
            onChanged: (value) {
              debugPrint('[Wizard] Année changée: $_year -> $value');
              setState(() {
                // Si l'année change, réinitialiser le modèle
                if (value != _year) {
                  _selectedModel = null;
                  _models = [];
                  _modelsError = null;
                  _isLoadingModels = false;
                }
                _year = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Make() {
    // Note: Le chargement est maintenant déclenché dans _nextStep() lors du passage à l'étape 2
    // Plus besoin de addPostFrameCallback ici

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marque du véhicule',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (_makesError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _makesError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          DropdownButtonFormField<CatalogMake>(
            value: _selectedMake,
            decoration: InputDecoration(
              labelText: 'Marque *',
              hintText: 'Sélectionner une marque',
              prefixIcon: const Icon(Icons.branding_watermark),
              errorText: _makesError,
            ),
            items: _buildMakeDropdownItems(),
            onChanged: (_isLoadingMakes || _type == null || _year == null)
                ? null
                : (CatalogMake? make) {
                    debugPrint('[Wizard] Marque sélectionnée: ${make?.name ?? "null"}');
                    setState(() {
                      // Si la marque change, réinitialiser le modèle
                      if (make != _selectedMake) {
                        _selectedModel = null;
                        _models = [];
                        _modelsError = null;
                        _isLoadingModels = false;
                      }
                      _selectedMake = make;
                    });
                  },
            isExpanded: true,
          ),
          if (_isLoadingMakes)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildStep4Model() {
    // Note: Le chargement est maintenant déclenché dans _nextStep() lors du passage à l'étape 3
    // Plus besoin de addPostFrameCallback ici

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Modèle du véhicule',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (_modelsError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _modelsError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          DropdownButtonFormField<CatalogModel>(
            value: _selectedModel,
            decoration: InputDecoration(
              labelText: 'Modèle *',
              hintText: 'Sélectionner un modèle',
              prefixIcon: const Icon(Icons.precision_manufacturing),
              errorText: _modelsError,
            ),
            items: _models.map((model) {
              return DropdownMenuItem<CatalogModel>(
                value: model,
                child: Text(model.name),
              );
            }).toList(),
            onChanged: _isLoadingModels || _selectedMake == null || _year == null
                ? null
                : (CatalogModel? model) {
                    setState(() {
                      _selectedModel = model;
                    });
                  },
            isExpanded: true,
          ),
          if (_isLoadingModels)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildStep5Details() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Détails optionnels',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              labelText: 'Surnom (optionnel)',
              hintText: 'Ex: Ma moto',
              prefixIcon: Icon(Icons.label),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optionnel)',
              hintText: 'Informations supplémentaires...',
              prefixIcon: Icon(Icons.note),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
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
        ],
      ),
    );
  }

  Widget _buildStep6Confirmation() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Confirmation',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfirmationRow('Type', _type == 'moto' ? 'Moto' : 'Voiture'),
                  if (_year != null)
                    _buildConfirmationRow('Année', _year.toString()),
                  if (_selectedMake != null)
                    _buildConfirmationRow('Marque', _selectedMake!.name),
                  if (_selectedModel != null)
                    _buildConfirmationRow('Modèle', _selectedModel!.name),
                  if (_nicknameController.text.isNotEmpty)
                    _buildConfirmationRow('Surnom', _nicknameController.text),
                  if (_enableRecommendedMaintenancePack)
                    _buildConfirmationRow(
                      'Pack entretien',
                      'Activé',
                    ),
                ],
              ),
            ),
          ),
          if (_isCreating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

