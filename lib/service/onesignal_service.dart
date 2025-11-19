// lib/service/onesignal_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Сервис для работы с OneSignal push-уведомлениями
//
// Возможности:
//  • Инициализация OneSignal SDK
//  • Получение и сохранение player ID
//  • Обработка входящих уведомлений
//  • Открытие чата при клике на уведомление
//
// Использование:
//   final onesignal = OneSignalService();
//   await onesignal.initialize();
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../config/app_config.dart';

/// Сервис для работы с OneSignal push-уведомлениями
class OneSignalService {
  // ──────────────────────────── Singleton ────────────────────────────

  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();

  bool _isInitialized = false;

  // ──────────────────────────── Инициализация ────────────────────────────

  /// Инициализирует OneSignal SDK
  ///
  /// ⚡ PERFORMANCE:
  /// - Инициализация происходит один раз при запуске приложения
  /// - Player ID сохраняется на сервере автоматически
  /// - Обработчики уведомлений настраиваются сразу после инициализации
  ///
  /// Параметры:
  /// - [onNotificationOpened] - колбэк при открытии уведомления (опционально)
  Future<void> initialize({
    Function(Map<String, dynamic>)? onNotificationOpened,
  }) async {
    if (_isInitialized) {
      debugPrint('⚠️ OneSignal уже инициализирован');
      return;
    }

    try {
      // ────────── Настройка OneSignal ──────────
      OneSignal.initialize(AppConfig.oneSignalAppId);

      // ────────── Запрос разрешения на уведомления ──────────
      OneSignal.Notifications.requestPermission(true);

      // ────────── Обработчик открытия уведомления ──────────
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('🔔 OneSignal уведомление открыто: ${event.notification}');

        // Получаем дополнительные данные из уведомления
        final additionalData = event.notification.additionalData;
        if (additionalData != null) {
          debugPrint('📦 Дополнительные данные: $additionalData');

          // Вызываем колбэк, если он передан
          // Используем Future.microtask для асинхронного выполнения навигации
          if (onNotificationOpened != null) {
            Future.microtask(() {
              onNotificationOpened(additionalData);
            });
          }
        }
      });

      // ────────── Получение Player ID и сохранение на сервере ──────────
      final playerId = await OneSignal.User.pushSubscription.id;
      if (playerId != null) {
        debugPrint('✅ OneSignal Player ID получен: $playerId');
        await _savePlayerId(playerId);
      } else {
        debugPrint('⚠️ OneSignal Player ID ещё не готов, подписываемся на обновления');
        
        // Подписываемся на обновления подписки
        OneSignal.User.pushSubscription.addObserver((state) {
          if (state.current.id != null) {
            debugPrint('✅ OneSignal Player ID получен после подписки: ${state.current.id}');
            _savePlayerId(state.current.id!);
          }
        });
      }

      _isInitialized = true;
      debugPrint('✅ OneSignal успешно инициализирован');
    } catch (e) {
      debugPrint('❌ Ошибка инициализации OneSignal: $e');
      rethrow;
    }
  }

  // ──────────────────────────── Сохранение Player ID ────────────────────────────

  /// Сохраняет OneSignal Player ID на сервере
  ///
  /// ⚡ PERFORMANCE:
  /// - Вызывается автоматически при получении Player ID
  /// - Использует retry механизм ApiService для надежности
  /// - Игнорирует ошибки, если пользователь не авторизован
  Future<void> _savePlayerId(String playerId) async {
    try {
      final userId = await _auth.getUserId();
      if (userId == null) {
        debugPrint('⚠️ Пользователь не авторизован, Player ID не сохранен');
        return;
      }

      await _api.post(
        '/update_onesignal_player_id.php',
        body: {
          'user_id': userId,
          'onesignal_player_id': playerId,
        },
      );

      debugPrint('✅ OneSignal Player ID сохранен на сервере для пользователя $userId');
    } catch (e) {
      debugPrint('❌ Ошибка сохранения OneSignal Player ID: $e');
      // Не пробрасываем ошибку, чтобы не блокировать работу приложения
    }
  }

  // ──────────────────────────── Публичные методы ────────────────────────────

  /// Получает текущий Player ID
  Future<String?> getPlayerId() async {
    if (!_isInitialized) {
      debugPrint('⚠️ OneSignal не инициализирован');
      return null;
    }

    try {
      return await OneSignal.User.pushSubscription.id;
    } catch (e) {
      debugPrint('❌ Ошибка получения Player ID: $e');
      return null;
    }
  }

  /// Проверяет, инициализирован ли OneSignal
  bool get isInitialized => _isInitialized;
}

