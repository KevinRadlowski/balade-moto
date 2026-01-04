import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home/home_screen.dart';
import 'groups/groups_screen.dart';
import 'profile/profile_screen.dart';
import 'rides/rides_history_screen.dart';
import 'garage/garage_home_screen.dart';
import 'admin/admin_home_screen.dart';
import '../services/auth_service.dart';
import '../services/navigation_state.dart';
import '../utils/vehicle_icon_helper.dart';
import '../widgets/legal/terms_consent_banner.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  Future<void> _refreshTokenSilently() async {
    if (!mounted) return;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAuthenticated) {
        await authService.refreshToken();
      }
    } catch (e) {
      // Ignorer les erreurs silencieusement - le token sera rafraîchi lors de la prochaine requête
      if (mounted) {
        debugPrint('[MainNavigation] Erreur lors du rafraîchissement silencieux du token: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final navigationState = Provider.of<NavigationState>(context);
    final vehiclePreference = authService.user?.vehiclePreference;
    final rideIcon = getVehicleIcon(vehiclePreference);
    final isAdmin = authService.isAdmin;
    
    // Construire la liste des écrans et items dynamiquement
    final List<Widget> screens = [
      const HomeScreen(),
      const RidesHistoryScreen(),
      const GarageHomeScreen(),
      const GroupsScreen(),
      const ProfileScreen(),
    ];
    
    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Accueil',
      ),
      BottomNavigationBarItem(
        icon: Icon(rideIcon),
        label: 'Balades',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.garage),
        label: 'Garage',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.group),
        label: 'Groupes',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profil',
      ),
    ];
    
    // Ajouter l'onglet Admin si l'utilisateur est admin
    if (isAdmin) {
      screens.add(const AdminHomeScreen());
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      );
    }
    
    // Ajuster l'index si nécessaire (si on passe de 6 à 5 items)
    final currentIndex = navigationState.currentIndex;
    final maxIndex = screens.length - 1;
    final safeIndex = currentIndex > maxIndex ? 0 : currentIndex;
    
    return Stack(
      children: [
        Scaffold(
          body: screens[safeIndex],
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: safeIndex,
            onTap: (index) {
              navigationState.setIndex(index);
              // Rafraîchir le token silencieusement lors du changement d'onglet
              _refreshTokenSilently();
            },
            items: items,
          ),
        ),
        // Bannière de consentement CGU/Confidentialité (ne devrait normalement pas s'afficher si déjà acceptées)
        // Conservée pour compatibilité au cas où les CGU n'auraient pas été acceptées avant connexion
        const TermsConsentBanner(),
      ],
    );
  }
}



