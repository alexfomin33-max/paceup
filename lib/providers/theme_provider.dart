import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Провайдер для управления темой приложения
/// Сохраняет выбор пользователя в SharedPreferences
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _themeModeKey = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    // Загружаем сохраненную тему при инициализации
    _loadThemeMode();
  }

  /// Загрузка сохраненной темы из SharedPreferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);
      
      if (savedMode != null) {
        final themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedMode,
          orElse: () => ThemeMode.light,
        );
        state = themeMode;
      }
    } catch (e) {
      // Игнорируем ошибки загрузки, используем светлую тему по умолчанию
    }
  }

  /// Переключение темы
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.toString());
      state = mode;
    } catch (e) {
      // Игнорируем ошибки сохранения
    }
  }

  /// Переключение между светлой и темной темой
  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    await setThemeMode(newMode);
  }
}

/// Провайдер для ThemeModeNotifier
final themeModeNotifierProvider = 
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

