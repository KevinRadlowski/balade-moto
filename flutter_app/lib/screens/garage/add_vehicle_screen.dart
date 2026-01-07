import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../models/catalog_make.dart';
import '../../models/catalog_model.dart';
import '../../services/garage_service.dart';
import '../../services/catalog/catalog_router_service.dart';
import '../../services/catalog_proposal_service.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/garage/searchable_select.dart';
import '../../exceptions/plan_limit_exception.dart';
import '../../widgets/premium/premium_upsell_modal.dart';
import '../../providers/plan_provider.dart';

class AddVehicleScreen extends StatefulWidget {
  final Vehicle? vehicle;

  const AddVehicleScreen({super.key, this.vehicle});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _typeSegmentedKey = GlobalKey(); // Clé pour forcer la reconstruction du SegmentedButton
  final GarageService _garageService = GarageService();
  late final CatalogRouterService _catalogRouter;
  late final CatalogProposalService _proposalService;

  // Champs du formulaire
  String? _type; // 'moto' ou 'voiture'
  final _nicknameController = TextEditingController();
  final _notesController = TextEditingController();
  String? _fuel;
  final _powerController = TextEditingController();
  final _odometerController = TextEditingController(text: '0');
  bool _enableRecommendedMaintenancePack = false;

  // Sélection catalogue local
  int? _year;
  List<CatalogMake> _makes = [];
  CatalogMake? _selectedMake;
  List<CatalogModel> _models = [];
  CatalogModel? _selectedModel;

  // Normaliser un nom de marque pour comparaison (uppercase, sans accents, sans espaces/tirets)
  static String _normalizeForCompare(String name) {
    return name
        .toUpperCase()
        .replaceAll('É', 'E')
        .replaceAll('È', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Ë', 'E')
        .replaceAll('À', 'A')
        .replaceAll('Á', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('Ä', 'A')
        .replaceAll('Å', 'A')
        .replaceAll('Î', 'I')
        .replaceAll('Ï', 'I')
        .replaceAll('Ò', 'O')
        .replaceAll('Ó', 'O')
        .replaceAll('Ô', 'O')
        .replaceAll('Õ', 'O')
        .replaceAll('Ö', 'O')
        .replaceAll('Ù', 'U')
        .replaceAll('Ú', 'U')
        .replaceAll('Û', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ç', 'C')
        .replaceAll(RegExp(r'[\s\-_]'), '');
  }

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

  // Champs pour suggestion (si véhicule non trouvé)
  final _suggestionMakeController = TextEditingController();
  final _suggestionModelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Récupérer l'ApiService partagé depuis AuthService
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Initialiser CatalogRouterService avec l'ApiService partagé
    _catalogRouter = CatalogRouterService(apiService: authService.apiService);
    
    // Initialiser CatalogProposalService avec l'ApiService partagé
    _proposalService = CatalogProposalService(apiService: authService.apiService);
    
    // Vider le cache overlay pour s'assurer d'avoir les dernières données approuvées
    // (la vérification de version se fera automatiquement lors du premier fetch)
    _catalogRouter.clearCache();
    
    // Si on édite un véhicule existant, pré-remplir les champs
    if (widget.vehicle != null) {
      final v = widget.vehicle!;
      _type = v.type;
      _nicknameController.text = v.nickname ?? '';
      if (v.year != null) {
        _year = v.year;
      }
      _fuel = v.engine?.fuel;
      if (v.engine?.powerHp != null) {
        _powerController.text = v.engine!.powerHp.toString();
      }
      _odometerController.text = v.odometerCurrentKm.toString();
      _notesController.text = v.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _suggestionMakeController.dispose();
    _suggestionModelController.dispose();
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
      debugPrint('[AddVehicle] Appel catalogRouter.fetchMakes($_type, $_year)');
      final makes = await _catalogRouter.fetchMakes(_type!, _year!);
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
      debugPrint('[AddVehicle] Appel catalogRouter.fetchModels($_type, ${_selectedMake!.id}, $_year)');
      final models = await _catalogRouter.fetchModels(
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

      // Utilisation du catalogue local ou suggestion
      if (_selectedMake != null && _selectedModel != null && _year != null) {
        // Vérifier si c'est une suggestion (ID commence par SUGGESTION_)
        final isSuggestion = _selectedMake!.id.startsWith('SUGGESTION_') || 
                             _selectedModel!.id.startsWith('SUGGESTION_');
        
        if (isSuggestion) {
          payload['selectionSource'] = 'SUGGESTION';
          payload['make'] = _selectedMake!.name;
          payload['model'] = _selectedModel!.name;
          payload['year'] = _year!;
          payload['externalCatalog'] = {
            'provider': 'SUGGESTION',
            'vehicleType': _type!,
            'year': _year!,
            'make': _selectedMake!.name,
            'model': _selectedModel!.name,
          };
        } else {
          payload['selectionSource'] = 'CATALOG_LOCAL';
          payload['make'] = _selectedMake!.name;
          payload['model'] = _selectedModel!.name;
          payload['year'] = _year!;
          
          payload['externalCatalog'] = {
            'provider': 'LOCAL_FR',
            'vehicleType': _type!,
            'year': _year!,
            'makeId': _selectedMake!.id,
            'modelId': _selectedModel!.id,
          };
          
          debugPrint('[AddVehicle] Payload avec catalogue local: ${jsonEncode(payload)}');
        }
      } else {
        SnackBarHelper.showError(
          context,
          'Veuillez compléter la sélection via le catalogue (marque, modèle, année)',
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
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
          // Rafraîchir le plan pour mettre à jour les quotas
          final planProvider = Provider.of<PlanProvider>(context, listen: false);
          await planProvider.loadPlan(silent: true);
          
          SnackBarHelper.showSuccess(context, 'Véhicule créé avec succès');
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        // Intercepter PlanLimitException et ouvrir la modale premium
        if (e is PlanLimitException) {
          // Construire un message plus explicite selon le type de limite
          String reasonMessage = e.message;
          
          // Si c'est une limite de véhicule par type, personnaliser le message
          if (e.details != null && e.details!['limitKey'] != null) {
            final limitKey = e.details!['limitKey'] as String?;
            if (limitKey != null && limitKey.startsWith('maxVehiclesByType.')) {
              final vehicleType = limitKey.split('.').last; // 'moto' ou 'voiture'
              final vehicleTypeLabel = vehicleType == 'moto' ? 'moto' : 'voiture';
              final current = e.details!['current'] as int? ?? 0;
              final limit = e.details!['limit'] as int? ?? 1;
              
              reasonMessage = 'Limite de véhicules atteinte. '
                  'Vous avez déjà $current $vehicleTypeLabel${current > 1 ? 's' : ''} '
                  'avec le plan Standard (limite : $limit). '
                  'Passez en Premium pour ajouter un nombre illimité de véhicules.';
            }
          }
          
          showPremiumUpsellModal(
            context,
            reason: reasonMessage,
            details: e.details,
          );
        } else {
          // Pour les autres erreurs, afficher le message d'erreur complet si disponible
          final errorMessage = e.toString().replaceAll('Exception: ', '');
          SnackBarHelper.showError(
            context,
            errorMessage.contains('Erreur') 
                ? errorMessage 
                : (widget.vehicle != null
                    ? 'Erreur lors de la modification du véhicule : $errorMessage'
                    : 'Erreur lors de la création du véhicule : $errorMessage'),
          );
        }
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
      // Comparer avec normalisation
      final makeNormalized = _normalizeForCompare(make.name);
      final isPopular = popularMakesList.any((popular) => 
        _normalizeForCompare(popular) == makeNormalized
      );
      
      if (isPopular) {
        popularMakes.add(make);
      } else {
        otherMakes.add(make);
      }
    }

    // Trier les marques populaires selon l'ordre défini (avec normalisation)
    popularMakes.sort((a, b) {
      final aNormalized = _normalizeForCompare(a.name);
      final bNormalized = _normalizeForCompare(b.name);
      int indexA = popularMakesList.indexWhere((name) => 
        _normalizeForCompare(name) == aNormalized
      );
      int indexB = popularMakesList.indexWhere((name) => 
        _normalizeForCompare(name) == bNormalized
      );
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
            if (value == null) {
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

  /// Affiche le dialog de suggestion pour un véhicule non trouvé
  Future<void> _showSuggestionDialog() async {
    if (_type == null || _year == null) {
      SnackBarHelper.showError(context, 'Veuillez d\'abord sélectionner le type et l\'année');
      return;
    }

    // Pré-remplir la marque si elle est déjà sélectionnée
    _suggestionMakeController.text = _selectedMake?.name ?? '';
    _suggestionModelController.clear();

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mon véhicule n\'est pas dans la liste',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _suggestionMakeController,
                decoration: const InputDecoration(
                  labelText: 'Marque *',
                  hintText: 'Ex: YAMAHA',
                  prefixIcon: Icon(Icons.branding_watermark),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La marque est requise';
                  }
                  if (value.trim().length < 2) {
                    return 'La marque doit contenir au moins 2 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _suggestionModelController,
                decoration: const InputDecoration(
                  labelText: 'Modèle *',
                  hintText: 'Ex: MT-07',
                  prefixIcon: Icon(Icons.precision_manufacturing),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le modèle est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Année: ${_year}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_suggestionMakeController.text.trim().isNotEmpty &&
                          _suggestionModelController.text.trim().isNotEmpty) {
                        Navigator.pop(context, {
                          'make': _suggestionMakeController.text.trim().toUpperCase(),
                          'model': _suggestionModelController.text.trim().toUpperCase(),
                        });
                      }
                    },
                    child: const Text('Envoyer la proposition'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      await _sendProposalAndPreFill(
        result['make']!,
        result['model']!,
      );
    }
  }

  /// Envoie une proposition à l'admin et préremplit les champs marque/modèle
  Future<void> _sendProposalAndPreFill(String make, String model) async {
    if (_type == null || _year == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Envoyer la proposition à l'admin
      final proposalResult = await _proposalService.createProposal(
        type: _type!,
        year: _year!,
        make: make,
        model: model,
      );
      
      debugPrint('[AddVehicle] Proposition créée: ${proposalResult?['status']}');
      
      // Afficher un message selon le statut
      if (mounted && proposalResult != null) {
        if (proposalResult['status'] == 'ALREADY_APPROVED') {
          SnackBarHelper.showInfo(context, 'Cette combinaison est déjà approuvée dans le catalogue.');
        } else if (proposalResult['status'] == 'ALREADY_PENDING') {
          SnackBarHelper.showInfo(context, 'Une proposition similaire est déjà en attente de validation.');
        } else {
          SnackBarHelper.showSuccess(context, 'Votre suggestion a été envoyée pour validation par un administrateur.');
        }
      }

      // Préremplir les champs marque et modèle dans le formulaire
      // Créer des objets CatalogMake et CatalogModel temporaires pour la sélection
      final makeId = 'SUGGESTION_MAKE_${make.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_')}';
      final suggestionMake = CatalogMake(
        id: makeId,
        name: make,
      );

      // Vérifier si la marque n'est pas déjà dans la liste
      CatalogMake finalMake;
      if (!_makes.any((m) => m.name.toUpperCase() == make.toUpperCase())) {
        setState(() {
          _makes.add(suggestionMake);
          _makes.sort((a, b) => a.name.compareTo(b.name));
        });
        finalMake = suggestionMake;
      } else {
        // Utiliser la marque existante
        finalMake = _makes.firstWhere((m) => m.name.toUpperCase() == make.toUpperCase());
      }

      setState(() {
        _selectedMake = finalMake;
      });

      // Charger les modèles pour cette marque (ou créer un modèle temporaire)
      await _loadModels();
      
      // Si le modèle n'est pas dans la liste, créer un modèle temporaire
      if (!_models.any((m) => m.name.toUpperCase() == model.toUpperCase())) {
        final modelId = 'SUGGESTION_MODEL_${make.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_')}_${model.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_')}_$_year';
        final suggestionModel = CatalogModel(
          id: modelId,
          name: model,
          makeName: make,
        );
        
        setState(() {
          _models.add(suggestionModel);
          _models.sort((a, b) => a.name.compareTo(b.name));
          _selectedModel = suggestionModel;
        });
      } else {
        // Sélectionner le modèle existant
        setState(() {
          _selectedModel = _models.firstWhere((m) => m.name.toUpperCase() == model.toUpperCase());
        });
      }

      if (mounted) {
        SnackBarHelper.showInfo(
          context,
          'Vous pouvez maintenant compléter le formulaire et créer votre véhicule.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Erreur lors de l\'envoi de la proposition: ${e.toString()}',
        );
      }
      debugPrint('Erreur _sendProposalAndPreFill: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
              key: _typeSegmentedKey,
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
                
                // Vérifier immédiatement si l'utilisateur peut ajouter ce type de véhicule
                if (newType != null) {
                  final planProvider = Provider.of<PlanProvider>(context, listen: false);
                  
                  // Vérifier la limite avant de permettre la sélection
                  if (!planProvider.canAddVehicle(newType)) {
                    // Construire un message explicite selon le type
                    final vehicleTypeLabel = newType == 'moto' ? 'moto' : 'voiture';
                    final currentCount = planProvider.plan?.usage.getVehiclesByType(newType) ?? 0;
                    final limit = planProvider.plan?.limits?.maxVehiclesByType?[newType] ?? 0;
                    
                    // Afficher la modale Premium
                    showPremiumUpsellModal(
                      context,
                      reason: 'Vous avez atteint votre limite de $limit $vehicleTypeLabel${limit > 1 ? 's' : ''} avec le plan Standard (actuellement $currentCount). Passez en Premium pour ajouter un nombre illimité de véhicules.',
                      details: {
                        'limitKey': 'maxVehiclesByType.$newType',
                        'limit': limit,
                        'current': currentCount,
                        'plan': 'FREE'
                      },
                    );
                    
                    // Forcer la sélection à revenir à l'ancien type
                    // En ne mettant pas à jour _type et en forçant un rebuild, le SegmentedButton reviendra à l'ancienne sélection
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          // Ne pas mettre à jour _type, il reste sur l'ancienne valeur
                          // Le SegmentedButton utilisera cette valeur via selected et reviendra à l'ancienne sélection
                        });
                      }
                    });
                    return; // Sortir sans continuer
                  }
                }
                
                setState(() {
                  // Si le type change, réinitialiser les sélections
                  if (newType != _type) {
                    _selectedMake = null;
                    _selectedModel = null;
                    _models = [];
                    _makes = [];
                    _makesError = null;
                    _modelsError = null;
                    _isLoadingMakes = false;
                    _isLoadingModels = false;
                  }
                  _type = newType;
                });
                
                // Charger les marques si type + année sont déjà sélectionnés
                if (newType != null && _year != null && _makes.isEmpty && !_isLoadingMakes) {
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

            // Sélection via catalogue local
            ...[
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
                  if (_type != null && value != null && _makes.isEmpty && !_isLoadingMakes) {
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
                  if (value == null) {
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
                  if (value == null) {
                    return 'Le modèle est requis';
                  }
                  return null;
                },
                builder: (FormFieldState<CatalogModel> field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SearchableSelect<CatalogModel>(
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
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _year == null || _type == null
                            ? null
                            : _showSuggestionDialog,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Mon véhicule n\'est pas dans la liste'),
                      ),
                    ],
                  );
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
