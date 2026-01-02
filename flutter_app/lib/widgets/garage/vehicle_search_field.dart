import 'package:flutter/material.dart';
import '../../services/garage_service.dart';

class VehicleSearchField extends StatefulWidget {
  final String? initialMake;
  final String? initialModel;
  final Function(String make, String model)? onVehicleSelected;
  final bool enabled;

  const VehicleSearchField({
    super.key,
    this.initialMake,
    this.initialModel,
    this.onVehicleSelected,
    this.enabled = true,
  });

  @override
  State<VehicleSearchField> createState() => _VehicleSearchFieldState();
}

class _VehicleSearchFieldState extends State<VehicleSearchField> {
  final GarageService _garageService = GarageService();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final FocusNode _makeFocusNode = FocusNode();
  final FocusNode _modelFocusNode = FocusNode();

  List<Map<String, dynamic>> _makes = [];
  List<Map<String, dynamic>> _filteredMakes = [];
  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _filteredModels = [];

  bool _isLoadingMakes = false;
  bool _isLoadingModels = false;
  String? _selectedMake;
  bool _showMakeSuggestions = false;
  bool _showModelSuggestions = false;

  @override
  void initState() {
    super.initState();
    _makeController.text = widget.initialMake ?? '';
    _modelController.text = widget.initialModel ?? '';
    _selectedMake = widget.initialMake;
    
    _makeController.addListener(_onMakeChanged);
    _modelController.addListener(_onModelChanged);
    _makeFocusNode.addListener(_onMakeFocusChanged);
    _modelFocusNode.addListener(_onModelFocusChanged);

    // Charger les marques au démarrage
    _loadMakes();
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _makeFocusNode.dispose();
    _modelFocusNode.dispose();
    super.dispose();
  }

  void _onMakeFocusChanged() {
    if (_makeFocusNode.hasFocus && _makeController.text.isNotEmpty) {
      _filterMakes(_makeController.text);
      setState(() {
        _showMakeSuggestions = true;
      });
    } else {
      setState(() {
        _showMakeSuggestions = false;
      });
    }
  }

  void _onModelFocusChanged() {
    if (_modelFocusNode.hasFocus && _modelController.text.isNotEmpty && _selectedMake != null) {
      _filterModels(_modelController.text);
      setState(() {
        _showModelSuggestions = true;
      });
    } else {
      setState(() {
        _showModelSuggestions = false;
      });
    }
  }

  void _onMakeChanged() {
    if (!widget.enabled) return;
    
    final query = _makeController.text;
    if (query.isEmpty) {
      setState(() {
        _filteredMakes = [];
        _showMakeSuggestions = false;
        _selectedMake = null;
        _modelController.clear();
        _models = [];
        _filteredModels = [];
      });
      return;
    }

    _filterMakes(query);
    
    if (_makeFocusNode.hasFocus) {
      setState(() {
        _showMakeSuggestions = true;
      });
    }
  }

  void _onModelChanged() {
    if (!widget.enabled) return;
    
    final query = _modelController.text;
    if (query.isEmpty) {
      setState(() {
        _filteredModels = [];
        _showModelSuggestions = false;
      });
      return;
    }

    if (_selectedMake != null) {
      _filterModels(query);
      
      if (_modelFocusNode.hasFocus) {
        setState(() {
          _showModelSuggestions = true;
        });
      }
    }
  }

  Future<void> _loadMakes() async {
    if (!widget.enabled) return;

    setState(() {
      _isLoadingMakes = true;
    });

    try {
      final makes = await _garageService.searchMakes();
      if (mounted) {
        setState(() {
          _makes = makes;
          _isLoadingMakes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMakes = false;
        });
      }
      debugPrint('Erreur lors du chargement des marques: $e');
    }
  }

  void _filterMakes(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredMakes = _makes
          .where((make) => make['makeName']?.toString().toLowerCase().contains(lowerQuery) ?? false)
          .take(20)
          .toList();
    });
  }

  Future<void> _loadModels(String makeName) async {
    if (!widget.enabled || makeName.isEmpty) return;

    setState(() {
      _isLoadingModels = true;
    });

    try {
      final models = await _garageService.getModelsForMake(makeName);
      if (mounted) {
        setState(() {
          _models = models;
          _isLoadingModels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingModels = false;
        });
      }
      debugPrint('Erreur lors du chargement des modèles: $e');
    }
  }

  void _filterModels(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredModels = _models
          .where((model) => model['modelName']?.toString().toLowerCase().contains(lowerQuery) ?? false)
          .take(20)
          .toList();
    });
  }

  void _selectMake(Map<String, dynamic> make) {
    final makeName = make['makeName'] as String;
    setState(() {
      _selectedMake = makeName;
      _makeController.text = makeName;
      _showMakeSuggestions = false;
      _modelController.clear();
      _models = [];
      _filteredModels = [];
    });
    _makeFocusNode.unfocus();
    _loadModels(makeName);
    _modelFocusNode.requestFocus();
  }

  void _selectModel(Map<String, dynamic> model) {
    final modelName = model['modelName'] as String;
    setState(() {
      _modelController.text = modelName;
      _showModelSuggestions = false;
    });
    _modelFocusNode.unfocus();
    
    if (widget.onVehicleSelected != null && _selectedMake != null) {
      widget.onVehicleSelected!(_selectedMake!, modelName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Champ de recherche de marque
        Stack(
          children: [
            TextFormField(
              controller: _makeController,
              focusNode: _makeFocusNode,
              enabled: widget.enabled,
              decoration: InputDecoration(
                labelText: 'Marque *',
                hintText: 'Rechercher une marque...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoadingMakes
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _makeController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _makeController.clear();
                                _selectedMake = null;
                                _modelController.clear();
                                _models = [];
                                _filteredMakes = [];
                                _showMakeSuggestions = false;
                              });
                            },
                          )
                        : null,
              ),
              onTap: () {
                if (_makeController.text.isNotEmpty) {
                  _filterMakes(_makeController.text);
                  setState(() {
                    _showMakeSuggestions = true;
                  });
                }
              },
            ),
            if (_showMakeSuggestions && _filteredMakes.isNotEmpty)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredMakes.length,
                      itemBuilder: (context, index) {
                        final make = _filteredMakes[index];
                        return ListTile(
                          dense: true,
                          title: Text(make['makeName'] ?? ''),
                          onTap: () => _selectMake(make),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Champ de recherche de modèle
        Stack(
          children: [
            TextFormField(
              controller: _modelController,
              focusNode: _modelFocusNode,
              enabled: widget.enabled && _selectedMake != null,
              decoration: InputDecoration(
                labelText: 'Modèle *',
                hintText: _selectedMake == null
                    ? 'Sélectionnez d\'abord une marque'
                    : 'Rechercher un modèle...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoadingModels
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _modelController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _modelController.clear();
                                _filteredModels = [];
                                _showModelSuggestions = false;
                              });
                            },
                          )
                        : null,
              ),
              onTap: () {
                if (_selectedMake != null && _modelController.text.isNotEmpty) {
                  _filterModels(_modelController.text);
                  setState(() {
                    _showModelSuggestions = true;
                  });
                }
              },
            ),
            if (_showModelSuggestions && _filteredModels.isNotEmpty)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredModels.length,
                      itemBuilder: (context, index) {
                        final model = _filteredModels[index];
                        return ListTile(
                          dense: true,
                          title: Text(model['modelName'] ?? ''),
                          onTap: () => _selectModel(model),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

