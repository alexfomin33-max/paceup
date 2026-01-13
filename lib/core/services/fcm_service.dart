// ВАЖНО: Перед использованием выполните: flutter pub get
// Этот файл требует установки пакетов:
//   - firebase_core: ^2.24.2
//   - firebase_messaging: ^14.7.9
//   - device_info_plus: ^12.2.0
//
// Ошибки компиляции исчезнут после установки пакетов

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Сервис для работы с Firebase Cloud Messaging (FCM)
///
/// Использование:
/// ```dart
/// final fcmService = FCMService();
/// await fcmService.initialize();
/// ```
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  // Ленивая инициализация FirebaseMessaging (создается только при первом использовании)
  FirebaseMessaging? _messaging;
  FirebaseMessaging get messaging {
    _messaging ??= FirebaseMessaging.instance;
    return _messaging!;
  }

  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();

  String? _fcmToken;
  bool _isInitialized = false;

  /// Инициализация FCM и запрос разрешений
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        debugPrint('🔔 [FCM] Уже инициализирован, пропускаем');
      }
      return;
    }

    // На macOS и iOS FCM временно отключен (проблемы с модульными заголовками)
    if (Platform.isMacOS || Platform.isIOS) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ [FCM] Временно отключен на ${Platform.isMacOS ? "macOS" : "iOS"}, пропускаем инициализацию',
        );
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('🔔 [FCM] Запрашиваем разрешения на уведомления...');
      }

      // Запрос разрешений на уведомления
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint(
          '🔔 [FCM] Статус разрешения: ${settings.authorizationStatus}',
        );
      }

      // ВАЖНО: для регистрации токена разрешение на уведомления НЕ обязательно.
      // Даже если пользователь запретил пуши, мы всё равно пытаемся получить FCM token
      // и зарегистрировать его на сервере (пуши могут быть включены позже).
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [FCM] Разрешение на уведомления не предоставлено (статус: ${settings.authorizationStatus}), '
            'но токен всё равно попробуем зарегистрировать',
          );
        }
      }

      // Получаем FCM токен (вне зависимости от разрешений) и регистрируем на сервере
      await _getAndRegisterToken();

      // Настраиваем обработчики уведомлений (data-сообщения могут приходить даже без permission)
      _setupMessageHandlers();

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ [FCM] Инициализация завершена');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [FCM] Ошибка инициализации FCM: $e');
        debugPrint('❌ [FCM] Stack trace: $stackTrace');
      }
    }
  }

  /// Получение и регистрация FCM токена
  Future<void> _getAndRegisterToken() async {
    try {
      if (kDebugMode) {
        debugPrint('🔔 [FCM] Запрашиваем токен у Firebase...');
      }

      String? token = await messaging.getToken();
      _fcmToken = token;

      if (kDebugMode) {
        debugPrint(
          '🔔 [FCM] Токен получен: ${token != null ? "${token.substring(0, 20)}..." : "null"}',
        );
      }

      if (_fcmToken != null) {
        if (kDebugMode) {
          debugPrint('🔔 [FCM] Регистрируем токен на сервере...');
        }
        await _registerTokenOnServer(_fcmToken!);
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM] Токен не получен от Firebase');
        }
      }

      // Слушаем обновления токена
      messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          debugPrint('🔔 [FCM] Токен обновлен, регистрируем новый токен...');
        }
        _fcmToken = newToken;
        _registerTokenOnServer(newToken);
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [FCM] Ошибка получения FCM токена: $e');
        debugPrint('❌ [FCM] Stack trace: $stackTrace');
      }
    }
  }

  /// Регистрация токена на сервере
  Future<void> _registerTokenOnServer(String token) async {
    try {
      final userId = await _auth.getUserId();
      if (userId == null) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [FCM] userId не найден, пропускаем регистрацию токена',
          );
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('🔔 [FCM] Регистрируем токен для userId: $userId');
      }

      // Получаем тип устройства
      String deviceType = 'android';
      String? deviceId;

      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          deviceType = 'android';
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id; // Android ID
          if (kDebugMode) {
            debugPrint('🔔 [FCM] Android device ID: $deviceId');
          }
        } else if (Platform.isIOS) {
          deviceType = 'ios';
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor; // IDFV
          if (kDebugMode) {
            debugPrint('🔔 [FCM] iOS device ID: $deviceId');
          }
        }
        // macOS пропускаем - FCM не поддерживается
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM] Ошибка получения device info: $e');
        }
      }

      // Отправляем токен на сервер
      if (kDebugMode) {
        debugPrint(
          '🔔 [FCM] Отправляем запрос на сервер: /register_fcm_token.php',
        );
        debugPrint(
          '🔔 [FCM] Данные: user_id=$userId, device_type=$deviceType, device_id=$deviceId',
        );
      }

      final response = await _api.post(
        '/register_fcm_token.php',
        body: {
          'user_id': userId,
          'fcm_token': token,
          'device_type': deviceType,
          if (deviceId != null) 'device_id': deviceId,
        },
      );

      if (kDebugMode) {
        debugPrint('✅ [FCM] Ответ сервера: $response');
        debugPrint('✅ [FCM] Токен успешно зарегистрирован на сервере');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [FCM] Ошибка регистрации FCM токена на сервере: $e');
        debugPrint('❌ [FCM] Stack trace: $stackTrace');
      }
    }
  }

  /// Настройка обработчиков входящих уведомлений
  void _setupMessageHandlers() {
    // Обработчик уведомлений когда приложение в foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint(
          '📨 Получено уведомление (foreground): ${message.notification?.title}',
        );
        debugPrint('   Данные: ${message.data}');
      }
      // Здесь можно показать локальное уведомление или обновить UI
    });

    // Обработчик нажатий на уведомления когда приложение открыто
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('📨 Уведомление открыто: ${message.data}');
      }
      // Здесь можно выполнить навигацию к соответствующему экрану
      _handleNotificationTap(message);
    });

    // Обработка уведомления, открывшего приложение из закрытого состояния
    messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          debugPrint('📨 Приложение открыто из уведомления: ${message.data}');
        }
        _handleNotificationTap(message);
      }
    });
  }

  /// Обработка нажатия на уведомление
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    // final notificationType = data['notification_type'] as String?;

    // Здесь можно добавить логику навигации в зависимости от типа уведомления
    // Например:
    // if (notificationType == 'new_messages') {
    //   Navigator.pushNamed(context, '/chat', arguments: {'chat_id': data['chat_id']});
    // }

    if (kDebugMode) {
      debugPrint('📨 Обработка нажатия на уведомление: $data');
    }
  }

  /// Получить текущий FCM токен
  String? get token => _fcmToken;

  /// Проверка, инициализирован ли сервис
  bool get isInitialized => _isInitialized;
}
