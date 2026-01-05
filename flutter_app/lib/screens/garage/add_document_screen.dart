import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/garage_service.dart';
import '../../utils/snackbar_helper.dart';

class AddDocumentScreen extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic>? document; // Pour l'édition

  const AddDocumentScreen({
    super.key,
    required this.vehicleId,
    this.document,
  });

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final GarageService _garageService = GarageService();

  String? _type;
  final _labelController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
  // Fichier sélectionné
  PlatformFile? _selectedFile;
  String? _selectedFilePath; // Pour mobile/desktop
  String? _selectedFileName;

  final List<String> _types = ['ASSURANCE', 'CT', 'FACTURE', 'AUTRE'];

  @override
  void initState() {
    super.initState();
    if (widget.document != null) {
      _type = widget.document!['type'];
      _labelController.text = widget.document!['label'] ?? '';
      // En mode édition, on peut avoir une URL existante (ancien format)
      // On ne peut pas modifier le fichier en mode édition
      if (widget.document!['date'] != null) {
        _selectedDate = DateTime.parse(widget.document!['date']);
      }
      _notesController.text = widget.document!['notes'] ?? '';
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFile = file;
          _selectedFileName = file.name;
          if (!kIsWeb && file.path != null) {
            _selectedFilePath = file.path;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors de la sélection du fichier: $e');
      }
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'ASSURANCE':
        return 'Assurance';
      case 'CT':
        return 'Contrôle technique';
      case 'FACTURE':
        return 'Facture';
      case 'AUTRE':
        return 'Autre';
      default:
        return type;
    }
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_type == null) {
      SnackBarHelper.showError(context, 'Veuillez sélectionner un type de document');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'type': _type!,
        'label': _labelController.text.trim(),
        'date': _selectedDate.toIso8601String(),
        if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
      };

      if (widget.document != null) {
        // En mode édition, on peut mettre à jour les métadonnées mais pas le fichier
        // Si l'utilisateur veut changer le fichier, il doit supprimer et recréer
        payload['fileUrl'] = widget.document!['fileUrl'] ?? '';
        await _garageService.updateDocument(
          widget.vehicleId,
          widget.document!['id'],
          payload,
        );
        if (mounted) {
          Navigator.pop(context, true);
          SnackBarHelper.showSuccess(context, 'Document mis à jour avec succès');
        }
      } else {
        // En mode création, un fichier est requis
        if (_selectedFile == null && _selectedFilePath == null) {
          SnackBarHelper.showError(context, 'Veuillez sélectionner un fichier');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        await _garageService.createDocument(
          widget.vehicleId,
          payload,
          file: _selectedFile,
          filePath: _selectedFilePath,
        );
        if (mounted) {
          Navigator.pop(context, true);
          SnackBarHelper.showSuccess(context, 'Document ajouté avec succès');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
        SnackBarHelper.showError(context, _errorMessage ?? 'Erreur lors de l\'ajout du document');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document != null ? 'Modifier le document' : 'Ajouter un document'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type de document *',
                prefixIcon: Icon(Icons.description),
              ),
              items: _types.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _type = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Le type est requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Libellé *',
                hintText: 'Ex: Assurance 2024',
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
            // Sélection de fichier
            InkWell(
              onTap: widget.document == null ? _pickFile : null, // Désactivé en mode édition
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fichier *',
                  prefixIcon: const Icon(Icons.attach_file),
                  helperText: widget.document == null
                      ? 'Sélectionnez un fichier depuis votre appareil'
                      : 'Le fichier ne peut pas être modifié en mode édition',
                  suffixIcon: _selectedFileName != null
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: widget.document == null
                              ? () {
                                  setState(() {
                                    _selectedFile = null;
                                    _selectedFilePath = null;
                                    _selectedFileName = null;
                                  });
                                }
                              : null,
                        )
                      : null,
                ),
                child: Text(
                  _selectedFileName ?? 
                  (widget.document != null 
                      ? 'Fichier existant' 
                      : 'Appuyez pour sélectionner un fichier'),
                  style: TextStyle(
                    color: _selectedFileName != null || widget.document != null
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ),
            if (_selectedFileName != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedFileName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optionnel)',
                hintText: 'Informations supplémentaires...',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
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
                  : Text(widget.document != null ? 'Enregistrer les modifications' : 'Ajouter le document'),
            ),
          ],
        ),
      ),
    );
  }
}

