import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home/home_screen.dart';
import 'groups/groups_screen.dart';
import 'profile/profile_screen.dart';
import 'rides/rides_history_screen.dart';
import 'garage/garage_home_screen.dart';
import '../services/auth_service.dart';
import '../utils/vehicle_icon_helper.dart';
import '../widgets/legal/terms_consent_banner.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const RidesHistoryScreen(),
    const GarageHomeScreen(),
    const GroupsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final vehiclePreference = authService.user?.vehiclePreference;
    final rideIcon = getVehicleIcon(vehiclePreference);
    
    return Stack(
      children: [
        Scaffold(
          body: _screens[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
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
        ],
          ),
        ),
        // Bannière de consentement CGU/Confidentialité (ne devrait normalement pas s'afficher si déjà acceptées)
        // Conservée pour compatibilité au cas où les CGU n'auraient pas été acceptées avant connexion
        const TermsConsentBanner(),
      ],
    );
  }
}



