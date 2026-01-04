import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/emergency_contact.dart';
import '../../providers/emergency_contact_provider.dart';
import '../../utils/snackbar_helper.dart';

class EmergencyContactEditScreen extends StatefulWidget {
  final EmergencyContact? contact;

  const EmergencyContactEditScreen({
    super.key,
    this.contact,
  });

  @override
  State<EmergencyContactEditScreen> createState() => _EmergencyContactEditScreenState();
}

class _EmergencyContactEditScreenState extends State<EmergencyContactEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  String _relation = 'family';

  bool get isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.contact!.name;
      _phoneController.text = widget.contact!.phone;
      _relation = widget.contact!.relation ?? 'family';
      _notesController.text = widget.contact!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<EmergencyContactProvider>(context, listen: false);

    try {
      if (isEditing) {
        await provider.updateContact(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          relationship: _relation,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      } else {
        await provider.createOrUpdateContact(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          relationship: _relation,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      }

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Contact d\'urgence ${isEditing ? 'modifié' : 'ajouté'} avec succès');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, e.toString());
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le contact d\'urgence ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = Provider.of<EmergencyContactProvider>(context, listen: false);

      try {
        await provider.deleteContact();
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Contact d\'urgence supprimé avec succès');
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier le contact d\'urgence' : 'Ajouter un contact d\'urgence'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone ou Email *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                  helperText: 'Numéro de téléphone ou adresse email',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le téléphone ou l\'email est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _relation,
                decoration: const InputDecoration(
                  labelText: 'Relation',
                  prefixIcon: Icon(Icons.family_restroom),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'family', child: Text('Famille')),
                  DropdownMenuItem(value: 'friend', child: Text('Ami(e)')),
                  DropdownMenuItem(value: 'colleague', child: Text('Collègue')),
                  DropdownMenuItem(value: 'other', child: Text('Autre')),
                ],
                onChanged: (value) {
                  setState(() {
                    _relation = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                  helperText: 'Informations supplémentaires',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(isEditing ? 'Modifier' : 'Ajouter'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

