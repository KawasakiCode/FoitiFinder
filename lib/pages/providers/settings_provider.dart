import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  // Getter to see current mode
  ThemeMode get themeMode => _themeMode;

  // Function to toggle mode
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // <--- This tells the app to rebuild!
  }
}