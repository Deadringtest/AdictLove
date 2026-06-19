import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);
  final ValueNotifier<Color> seedColor = ValueNotifier(Colors.pink);

  static const _modeKey = 'theme_mode';
  static const _colorKey = 'theme_seed_color';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMode = prefs.getString(_modeKey);
    if (storedMode != null) {
      mode.value = ThemeMode.values.firstWhere(
        (m) => m.name == storedMode,
        orElse: () => ThemeMode.system,
      );
    }
    final storedColor = prefs.getInt(_colorKey);
    if (storedColor != null) {
      seedColor.value = Color(storedColor);
    }
  }

  Future<void> setMode(ThemeMode newMode) async {
    mode.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, newMode.name);
  }

  Future<void> setSeedColor(Color color) async {
    seedColor.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.value);
  }
}
