// ВАЖНО: Перед использованием выполните: flutter pub get
// Этот файл требует установки пакетов:
//   - firebase_core: ^2.24.2
//   - firebase_messaging: ^14.7.9
//   - device_info_plus: ^9.1.1
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

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  
  String? _fcmToken;
  bool _isInitialized = false;

  /// Инициализация FCM и запрос разрешений
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // На macOS FCM не поддерживается, пропускаем инициализацию
    if (Platform.isMacOS) {
      if (kDebugMode) {
        debugPrint('⚠️ FCM: Не поддерживается на macOS, пропускаем инициализацию');
      }
      return;
    }
    
    try {
      // Запрос разрешений на уведомления
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Получаем FCM токен
        await _getAndRegisterToken();
        
        // Настраиваем обработчики уведомлений
        _setupMessageHandlers();
        
        _isInitialized = true;
        
        if (kDebugMode) {
          debugPrint('✅ FCM инициализирован успешно');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ FCM: Разрешение на уведомления не предоставлено');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Ошибка инициализации FCM: $e');
      }
    }
  }

  /// Получение и регистрация FCM токена
  Future<void> _getAndRegisterToken() async {
    try {
      String? token = await _messaging.getToken();
      _fcmToken = token;
      if (_fcmToken != null) {
        await _registerTokenOnServer(_fcmToken!);
      }
      
      // Слушаем обновления токена
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerTokenOnServer(newToken);
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Ошибка получения FCM токена: $e');
      }
    }
  }

  /// Регистрация токена на сервере
  Future<void> _registerTokenOnServer(String token) async {
    try {
      final userId = await _auth.getUserId();
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ FCM: userId не найден, пропускаем регистрацию токена');
        }
        return;
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
        } else if (Platform.isIOS) {
          deviceType = 'ios';
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor; // IDFV
        }
        // macOS пропускаем - FCM не поддерживается
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ FCM: Ошибка получения device info: $e');
        }
      }

      // Отправляем токен на сервер
      await _api.post(
        '/register_fcm_token.php',
        body: {
          'user_id': userId,
          'fcm_token': token,
          'device_type': deviceType,
          if (deviceId != null) 'device_id': deviceId,
        },
      );

      if (kDebugMode) {
        debugPrint('✅ FCM токен зарегистрирован на сервере');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Ошибка регистрации FCM токена на сервере: $e');
      }
    }
  }

  /// Настройка обработчиков входящих уведомлений
  void _setupMessageHandlers() {
    // Обработчик уведомлений когда приложение в foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('📨 Получено уведомление (foreground): ${message.notification?.title}');
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
    _messaging.getInitialMessage().then((RemoteMessage? message) {
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
