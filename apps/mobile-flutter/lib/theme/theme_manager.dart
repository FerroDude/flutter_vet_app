import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  // Force light mode for all users - dark mode has been removed from the app
  ThemeMode get themeMode => ThemeMode.light;

  // Always return false - dark mode is no longer supported
  bool get isDarkMode => false;

  ThemeManager() {
    _forceLightMode();
  }

  void _forceLightMode() async {
    // Force light mode for all users, clearing any previous dark mode preference
    final prefs = await SharedPreferences.getInstance();
    final storedIndex = prefs.getInt(_themeKey);
    
    // If user had dark mode (2) or system (0), force to light mode (1)
    if (storedIndex != 1) {
      await prefs.setInt(_themeKey, 1); // Save light mode preference
    }
    
    notifyListeners();
  }

  // Theme mode setting is disabled - always light mode
  void setThemeMode(ThemeMode mode) async {
    // Ignore any attempts to change theme - always stay on light mode
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, 1); // Always save light mode
  }

  // Toggle is disabled - always light mode
  void toggleTheme() {
    // No-op: dark mode is no longer supported
  }

  String get themeModeString => 'Light';
}
