import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../../services/garage_service.dart';
import '../../models/maintenance_log.dart';
import '../../utils/snackbar_helper.dart';

class AddMaintenanceLogScreen extends StatefulWidget {
  final String vehicleId;
  final MaintenanceLog? maintenanceLog; // Pour l'édition

  const AddMaintenanceLogScreen({
    super.key,
    required this.vehicleId,
    this.maintenanceLog,
  });

  @override
  State<AddMaintenanceLogScreen> createState() => _AddMaintenanceLogScreenState();
}

class _AddMaintenanceLogScreenState extends State<AddMaintenanceLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final GarageService _garageService = GarageService();

  final _labelController = TextEditingController();
  String? _category;
  DateTime _selectedDate = DateTime.now();
  final _kmController = TextEditingController();
  final _costController = TextEditingController();
  final _garageNameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
  // Fichier document
  PlatformFile? _selectedFile;
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _existingDocumentUrl; // URL du document existant en mode édition
  
  // Kilométrage actuel du véhicule
  int? _vehicleCurrentKm;

  final List<String> _categories = [
    'vidange',
    'filtre_huile',
    'filtre_air',
    'filtre_essence',
    'bougies',
    'freins',
    'pneus',
    'batterie',
    'chaines',
    'liquide_refroidissement',
    'liquide_freins',
    'revision',
    'autre',
  ];

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
    // Si en mode édition, pré-remplir les champs
    if (widget.maintenanceLog != null) {
      final log = widget.maintenanceLog!;
      _labelController.text = log.label;
      _category = log.category;
      _selectedDate = log.date;
      _kmController.text = log.kmAtService.toString();
      _costController.text = log.cost > 0 ? log.cost.toString() : '';
      _garageNameController.text = log.garageName ?? '';
      _notesController.text = log.notes ?? '';
      _existingDocumentUrl = log.invoiceFileUrl;
    }
  }

  Future<void> _loadVehicleData() async {
    try {
      final vehicle = await _garageService.getVehicle(widget.vehicleId);
      if (mounted) {
        setState(() {
          _vehicleCurrentKm = vehicle.odometerCurrentKm;
        });
      }
    } catch (e) {
      // Ne pas bloquer l'écran si on ne peut pas charger le kilométrage
      debugPrint('Erreur lors du chargement du kilométrage du véhicule: $e');
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _kmController.dispose();
    _costController.dispose();
    _garageNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result;
      final allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'doc', 'docx', 'xls', 'xlsx', 'txt'];

      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFile = file;
          _selectedFileName = _selectedFile!.name;
          if (!kIsWeb && _selectedFile!.path != null) {
            _selectedFilePath = _selectedFile!.path;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors de la sélection du fichier: ${e.toString()}');
      }
    }
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedFile = null;
      _selectedFilePath = null;
      _selectedFileName = null;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _getCategoryLabel(String category) {
    final labels = {
      'vidange': 'Vidange',
      'filtre_huile': 'Filtre à huile',
      'filtre_air': 'Filtre à air',
      'filtre_essence': 'Filtre à essence',
      'bougies': 'Bougies',
      'freins': 'Freins',
      'pneus': 'Pneus',
      'batterie': 'Batterie',
      'chaines': 'Chaînes',
      'liquide_refroidissement': 'Liquide de refroidissement',
      'liquide_freins': 'Liquide de frein',
      'revision': 'Révision',
      'autre': 'Autre',
    };
    return labels[category] ?? category;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_category == null) {
      SnackBarHelper.showError(context, 'Veuillez sélectionner une catégorie');
      return;
    }

    // Vérification supplémentaire du kilométrage avant soumission
    final kmValue = int.tryParse(_kmController.text);
    if (kmValue == null) {
      SnackBarHelper.showError(context, 'Kilométrage invalide');
      return;
    }
    if (_vehicleCurrentKm != null && kmValue > _vehicleCurrentKm!) {
      SnackBarHelper.showError(
        context,
        'Le kilométrage ne peut pas être supérieur au kilométrage actuel du véhicule ($_vehicleCurrentKm km)',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'label': _labelController.text.trim(),
        'category': _category!,
        'date': _selectedDate.toIso8601String(),
        'kmAtService': kmValue,
        'cost': double.tryParse(_costController.text) ?? 0,
        if (_garageNameController.text.isNotEmpty) 'garageName': _garageNameController.text.trim(),
        if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
      };

      if (widget.maintenanceLog != null) {
        // Mode édition
        if (_selectedFile != null) {
          await _garageService.updateMaintenanceLog(
            widget.vehicleId,
            widget.maintenanceLog!.id,
            payload,
            file: _selectedFile,
            filePath: _selectedFilePath,
          );
        } else {
          await _garageService.updateMaintenanceLog(
            widget.vehicleId,
            widget.maintenanceLog!.id,
            payload,
          );
        }

        if (mounted) {
          Navigator.pop(context, true);
          SnackBarHelper.showSuccess(context, 'Entretien modifié avec succès');
        }
      } else {
        // Mode création
        if (_selectedFile != null) {
          await _garageService.createMaintenanceLog(
            widget.vehicleId,
            payload,
            file: _selectedFile,
            filePath: _selectedFilePath,
          );
        } else {
          await _garageService.createMaintenanceLog(widget.vehicleId, payload);
        }

        if (mounted) {
          Navigator.pop(context, true);
          SnackBarHelper.showSuccess(context, 'Entretien enregistré avec succès');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.maintenanceLog != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier l\'entretien' : 'Ajouter un entretien'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Libellé *',
                hintText: 'Ex: Vidange complète',
                prefixIcon: Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le libellé est requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Catégorie *',
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(_getCategoryLabel(cat)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _category = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'La catégorie est requise';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_selectedDate),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kmController,
              decoration: InputDecoration(
                labelText: 'Kilométrage au moment du service *',
                hintText: _vehicleCurrentKm != null 
                    ? 'Ex: 5500 (max: $_vehicleCurrentKm km)'
                    : 'Ex: 5500',
                prefixIcon: const Icon(Icons.speed),
                helperText: _vehicleCurrentKm != null
                    ? 'Kilométrage actuel du véhicule: $_vehicleCurrentKm km'
                    : null,
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
                // Vérifier que le kilométrage ne dépasse pas le kilométrage actuel du véhicule
                if (_vehicleCurrentKm != null && km > _vehicleCurrentKm!) {
                  return 'Le kilométrage ne peut pas être supérieur au kilométrage actuel du véhicule ($_vehicleCurrentKm km)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _costController,
              decoration: const InputDecoration(
                labelText: 'Coût (€)',
                hintText: 'Ex: 50',
                prefixIcon: Icon(Icons.euro),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _garageNameController,
              decoration: const InputDecoration(
                labelText: 'Nom du garage (optionnel)',
                hintText: 'Ex: Garage Moto Pro',
                prefixIcon: Icon(Icons.build),
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
            const SizedBox(height: 16),
            // Sélecteur de document (facture, etc.)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Document (optionnel)',
                hintText: 'Facture, photo, PDF...',
                prefixIcon: Icon(Icons.attach_file),
                border: OutlineInputBorder(),
              ),
              child: InkWell(
                onTap: _pickFile,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedFileName ?? 
                        (_existingDocumentUrl != null ? 'Document existant' : 'Aucun fichier sélectionné'),
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedFile != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clearSelectedFile,
                      )
                    else if (_existingDocumentUrl != null && _selectedFile == null)
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      )
                    else
                      const Icon(Icons.folder_open),
                  ],
                ),
              ),
            ),
            if (_existingDocumentUrl != null && _selectedFile == null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Document actuel: ${_existingDocumentUrl!.split('/').last}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Enregistrer les modifications' : 'Enregistrer l\'entretien'),
            ),
          ],
        ),
      ),
    );
  }
}

