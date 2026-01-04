import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/emergency_contact_provider.dart';
import '../../screens/profile/emergency_contact_edit_screen.dart';

class EmergencyContactCard extends StatelessWidget {
  const EmergencyContactCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmergencyContactProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (provider.errorMessage != null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(height: 8),
                  Text(
                    'Erreur',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => provider.loadContact(),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        final contact = provider.contact;

        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EmergencyContactEditScreen(
                    contact: null, // Passer null pour éditer le contact existant
                  ),
                ),
              ).then((_) {
                provider.loadContact();
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.emergency,
                            color: Colors.red.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Contact d\'urgence',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          contact != null ? Icons.edit : Icons.add,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EmergencyContactEditScreen(
                                contact: contact,
                              ),
                            ),
                          ).then((_) {
                            provider.loadContact();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (contact == null || !contact.isComplete) ...[
                    // Aucun contact configuré
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Aucun contact d\'urgence configuré',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EmergencyContactEditScreen(
                              contact: null,
                            ),
                          ),
                        ).then((_) {
                          provider.loadContact();
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un contact d\'urgence'),
                    ),
                  ] else ...[
                    // Contact configuré
                    _ContactField(
                      icon: Icons.person,
                      label: 'Nom',
                      value: contact.name,
                    ),
                    const SizedBox(height: 12),
                    _ContactField(
                      icon: Icons.phone,
                      label: 'Téléphone',
                      value: contact.phone,
                    ),
                    if (contact.relation != null) ...[
                      const SizedBox(height: 12),
                      _ContactField(
                        icon: Icons.family_restroom,
                        label: 'Relation',
                        value: contact.relation!,
                      ),
                    ],
                    if (contact.notes != null && contact.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ContactField(
                        icon: Icons.note,
                        label: 'Notes',
                        value: contact.notes!,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ContactField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

