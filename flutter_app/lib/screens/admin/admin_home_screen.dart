import 'package:flutter/material.dart';
import '../../widgets/admin/admin_only.dart';
import 'catalog/admin_catalog_proposals_screen.dart';
import 'users/admin_users_screen.dart';
import 'rides/admin_rides_screen.dart';
import 'groups/admin_groups_screen.dart';
import 'promoCodes/admin_promo_codes_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminOnly(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel Administrateur'),
        ),
        body: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildAdminCard(
              context,
              title: 'Catalogue',
              subtitle: 'Propositions',
              icon: Icons.inventory_2,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminCatalogProposalsScreen(),
                  ),
                );
              },
            ),
            _buildAdminCard(
              context,
              title: 'Utilisateurs',
              subtitle: 'Gestion',
              icon: Icons.people,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminUsersScreen(),
                  ),
                );
              },
            ),
            _buildAdminCard(
              context,
              title: 'Balades',
              subtitle: 'Modération',
              icon: Icons.directions_bike,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminRidesScreen(),
                  ),
                );
              },
            ),
            _buildAdminCard(
              context,
              title: 'Groupes',
              subtitle: 'Modération',
              icon: Icons.group,
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminGroupsScreen(),
                  ),
                );
              },
            ),
            _buildAdminCard(
              context,
              title: 'Codes promo',
              subtitle: 'Génération',
              icon: Icons.confirmation_number,
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminPromoCodesScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

