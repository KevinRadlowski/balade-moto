import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home/home_screen.dart';
import 'groups/groups_screen.dart';
import 'profile/profile_screen.dart';
import 'rides/rides_history_screen.dart';
import '../services/auth_service.dart';
import '../utils/vehicle_icon_helper.dart';

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
    const GroupsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final vehiclePreference = authService.user?.vehiclePreference;
    final rideIcon = getVehicleIcon(vehiclePreference);
    
    return Scaffold(
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
            icon: Icon(Icons.group),
            label: 'Groupes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}



