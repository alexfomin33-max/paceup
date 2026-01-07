import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';

/// Модель настроек пользователя
class UserSettings {
  final String phone;
  final String email;
  final bool hasPassword;

  const UserSettings({
    required this.phone,
    required this.email,
    required this.hasPassword,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      hasPassword: json['has_password'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'email': email,
      'has_password': hasPassword,
    };
  }
}

const _cacheKey = 'user_settings_cache';

/// Функция для очистки кеша настроек пользователя
Future<void> clearUserSettingsCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  } catch (e) {
    // Игнорируем ошибки очистки кеша
  }
}

/// Провайдер для получения настроек пользователя
/// Использует кеширование: сначала показывает кеш (если есть), затем обновляет данные
final userSettingsProvider = FutureProvider<UserSettings>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = await authService.getUserId();
  if (userId == null) {
    throw Exception('Пользователь не авторизован');
  }

  // ────────── ШАГ 1: Пытаемся загрузить из кеша (мгновенно) ──────────
  try {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cacheKey);
    if (cachedJson != null) {
      final cachedData = jsonDecode(cachedJson) as Map<String, dynamic>;
      // Проверяем, что кеш соответствует текущему пользователю
      if (cachedData['user_id'] == userId) {
        return UserSettings.fromJson(cachedData);
      }
    }
  } catch (e) {
    // Игнорируем ошибки кеша, продолжаем загрузку с сервера
  }

  // ────────── ШАГ 2: Загружаем свежие данные с сервера ──────────
  try {
    final api = ref.read(apiServiceProvider);
    final data = await api.post(
      '/get_user_settings.php',
      body: {'user_id': userId},
    );

    final settings = UserSettings.fromJson(data);

    // Сохраняем в кеш для следующего раза
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonToCache = settings.toJson();
      jsonToCache['user_id'] = userId;
      await prefs.setString(_cacheKey, jsonEncode(jsonToCache));
    } catch (e) {
      // Игнорируем ошибки сохранения кеша
    }

    return settings;
  } catch (e) {
    // Если ошибка загрузки, пробуем вернуть кеш (даже если он старый)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        final cachedData = jsonDecode(cachedJson) as Map<String, dynamic>;
        if (cachedData['user_id'] == userId) {
          return UserSettings.fromJson(cachedData);
        }
      }
    } catch (e) {
      // Игнорируем ошибки кеша
    }
    rethrow;
  }
});
