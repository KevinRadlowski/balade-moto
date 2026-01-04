import 'package:flutter/foundation.dart';

/// État global de navigation pour gérer l'onglet actif dans MainNavigation
class NavigationState extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  /// Change l'onglet actif (0=Accueil, 1=Balades, 2=Garage, 3=Groupes, 4=Profil, 5=Admin si admin)
  void setIndex(int index) {
    if (index != _currentIndex && index >= 0) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}


