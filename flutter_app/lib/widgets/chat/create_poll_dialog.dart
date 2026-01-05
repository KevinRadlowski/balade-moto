import 'package:flutter/material.dart';

class CreatePollDialog extends StatefulWidget {
  const CreatePollDialog({super.key});

  @override
  State<CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<CreatePollDialog> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multipleChoice = false;
  DateTime? _expiresAt;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un sondage doit avoir au moins 2 options'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _selectExpirationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(picked),
      );

      if (time != null) {
        setState(() {
          _expiresAt = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Map<String, dynamic>? _validateAndGetPollData() {
    if (!_formKey.currentState!.validate()) {
      return null;
    }

    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir une question'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un sondage doit avoir au moins 2 options'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    // Vérifier qu'il n'y a pas de doublons
    final uniqueOptions = options.toSet();
    if (uniqueOptions.length != options.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les options doivent être différentes'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    return {
      'question': question,
      'options': options.map((text) => {'text': text, 'votes': []}).toList(),
      'multipleChoice': _multipleChoice,
      if (_expiresAt != null) 'expiresAt': _expiresAt!.toIso8601String(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.poll, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Créer un sondage',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question
                      TextFormField(
                        controller: _questionController,
                        decoration: InputDecoration(
                          labelText: 'Question *',
                          hintText: 'Ex: Quelle date vous convient le mieux ?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.help_outline),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez saisir une question';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Options
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Options *',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        _optionControllers.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _optionControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Option ${index + 1}',
                                    hintText: 'Saisir une option',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.radio_button_unchecked),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Cette option est requise';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              if (_optionControllers.length > 2)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: Colors.red,
                                  onPressed: () => _removeOption(index),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Multiple choice
                      SwitchListTile(
                        title: const Text('Choix multiple'),
                        subtitle: const Text(
                          'Permettre de sélectionner plusieurs options',
                        ),
                        value: _multipleChoice,
                        onChanged: (value) {
                          setState(() {
                            _multipleChoice = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Expiration date
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Date d\'expiration (optionnel)'),
                        subtitle: Text(
                          _expiresAt != null
                              ? 'Expire le ${_formatDateTime(_expiresAt!)}'
                              : 'Aucune expiration',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_expiresAt != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _expiresAt = null;
                                  });
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _selectExpirationDate,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final pollData = _validateAndGetPollData();
                        if (pollData != null) {
                          Navigator.pop(context, pollData);
                        }
                      },
                      child: const Text('Créer le sondage'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}








