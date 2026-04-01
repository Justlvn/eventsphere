import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistance du choix [ThemeMode] (système, clair, sombre).
class ThemeProvider extends ChangeNotifier {
  ThemeProvider() {
    _load();
  }

  static const _prefsKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    switch (raw) {
      case 'light':
        _themeMode = ThemeMode.light;
      case 'dark':
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Met à jour le thème et enregistre la préférence.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
