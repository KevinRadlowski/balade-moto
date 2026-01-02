import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/maintenance_item.dart';
import '../../services/garage_service.dart';
import '../../utils/snackbar_helper.dart';

class EditMaintenanceItemScreen extends StatefulWidget {
  final String vehicleId;
  final MaintenanceItem maintenanceItem;

  const EditMaintenanceItemScreen({
    super.key,
    required this.vehicleId,
    required this.maintenanceItem,
  });

  @override
  State<EditMaintenanceItemScreen> createState() => _EditMaintenanceItemScreenState();
}

class _EditMaintenanceItemScreenState extends State<EditMaintenanceItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final GarageService _garageService = GarageService();

  final _labelController = TextEditingController();
  final _intervalKmController = TextEditingController();
  final _intervalMonthsController = TextEditingController();
  final _dueAtKmController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _dueAtDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _labelController.text = widget.maintenanceItem.label;
    if (widget.maintenanceItem.intervalKm != null) {
      _intervalKmController.text = widget.maintenanceItem.intervalKm.toString();
    }
    if (widget.maintenanceItem.intervalMonths != null) {
      _intervalMonthsController.text = widget.maintenanceItem.intervalMonths.toString();
    }
    if (widget.maintenanceItem.dueAtKm != null) {
      _dueAtKmController.text = widget.maintenanceItem.dueAtKm.toString();
    }
    _dueAtDate = widget.maintenanceItem.dueAtDate;
    _notesController.text = widget.maintenanceItem.notes ?? '';
  }

  @override
  void dispose() {
    _labelController.dispose();
    _intervalKmController.dispose();
    _intervalMonthsController.dispose();
    _dueAtKmController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAtDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dueAtDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = <String, dynamic>{
        'label': _labelController.text.trim(),
      };

      if (_intervalKmController.text.isNotEmpty) {
        payload['intervalKm'] = int.parse(_intervalKmController.text);
      }
      if (_intervalMonthsController.text.isNotEmpty) {
        payload['intervalMonths'] = int.parse(_intervalMonthsController.text);
      }
      if (_dueAtKmController.text.isNotEmpty) {
        payload['dueAtKm'] = int.parse(_dueAtKmController.text);
      }
      if (_dueAtDate != null) {
        payload['dueAtDate'] = _dueAtDate!.toIso8601String();
      }
      if (_notesController.text.isNotEmpty) {
        payload['notes'] = _notesController.text.trim();
      }

      await _garageService.updateMaintenanceItem(
        widget.vehicleId,
        widget.maintenanceItem.id,
        payload,
      );

      if (mounted) {
        Navigator.pop(context, true);
        SnackBarHelper.showSuccess(context, 'Élément de maintenance mis à jour');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier la maintenance'),
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
            TextFormField(
              controller: _intervalKmController,
              decoration: const InputDecoration(
                labelText: 'Intervalle (km)',
                hintText: 'Ex: 5000',
                prefixIcon: Icon(Icons.speed),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final km = int.tryParse(value);
                  if (km == null || km < 0) {
                    return 'Valeur invalide';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _intervalMonthsController,
              decoration: const InputDecoration(
                labelText: 'Intervalle (mois)',
                hintText: 'Ex: 12',
                prefixIcon: Icon(Icons.calendar_month),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final months = int.tryParse(value);
                  if (months == null || months < 0) {
                    return 'Valeur invalide';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dueAtKmController,
              decoration: const InputDecoration(
                labelText: 'Échéance (km)',
                hintText: 'Ex: 10000',
                prefixIcon: Icon(Icons.flag),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final km = int.tryParse(value);
                  if (km == null || km < 0) {
                    return 'Valeur invalide';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Échéance (date)',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _dueAtDate != null
                      ? DateFormat('dd/MM/yyyy').format(_dueAtDate!)
                      : 'Sélectionner une date',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
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
                  : const Text('Enregistrer les modifications'),
            ),
          ],
        ),
      ),
    );
  }
}

