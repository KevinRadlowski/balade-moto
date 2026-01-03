import 'package:flutter/material.dart';
import '../../screens/ride/create_ride_with_map_screen.dart';
import '../../screens/groups/create_group_screen.dart';

/// Widget pour le bouton FAB "Actions rapides"
/// 
/// Positionné en bas à droite avec un padding pour éviter le chevauchement
class QuickActionsFab extends StatelessWidget {
  final ScrollController? scrollController;

  const QuickActionsFab({
    super.key,
    this.scrollController,
  });

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Que veux-tu faire ?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            _buildQuickActionButton(
              context: context,
              icon: Icons.add_location_alt,
              label: 'Créer une balade',
              color: Colors.blue.shade700,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateRideWithMapScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildQuickActionButton(
              context: context,
              icon: Icons.group_add,
              label: 'Créer un groupe',
              color: Colors.purple.shade700,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateGroupScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildQuickActionButton(
              context: context,
              icon: Icons.search,
              label: 'Rechercher une balade',
              color: Colors.green.shade700,
              onTap: () {
                Navigator.pop(context);
                // Scroll vers la section "Toutes les balades"
                if (scrollController != null && scrollController!.hasClients) {
                  scrollController!.animateTo(
                    scrollController!.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showQuickActions(context),
      icon: const Icon(Icons.add),
      label: const Text('Actions rapides'),
      backgroundColor: Colors.blue.shade700,
    );
  }
}



