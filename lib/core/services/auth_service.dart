import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

/// 🔹 Сервис для управления авторизацией пользователя
/// Использует FlutterSecureStorage для безопасного хранения токенов
class AuthService {
  /// 🔹 Безопасное хранилище для токенов и данных пользователя
  /// 
  /// ⚠️ КРИТИЧНО для Android:
  /// - Используем encryptedSharedPreferences: true для безопасности
  /// - resetOnError: false - не очищаем данные при ошибках чтения
  /// - Это важно для надежного сохранения токенов между запусками приложения
  final storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false, // 🔹 Не очищаем данные при ошибках чтения
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final String baseUrl = "https://api.paceup.ru";

  /// 🔹 Получение access token из безопасного хранилища
  Future<String?> getAccessToken() async =>
      await storage.read(key: "access_token");

  /// 🔹 Получение refresh token из безопасного хранилища
  Future<String?> getRefreshToken() async =>
      await storage.read(key: "refresh_token");

  /// 🔹 Получение ID пользователя из безопасного хранилища
  Future<int?> getUserId() async {
    try {
      final userIdStr = await storage.read(key: "user_id");
      final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
      
      if (kDebugMode && userId != null) {
        debugPrint('🔹 UserId прочитан: $userId');
      }
      
      return userId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Ошибка при чтении userId: $e');
      }
      return null;
    }
  }

  /// 🔹 Сохранение токенов и ID пользователя в безопасное хранилище
  /// Вызывается после успешной авторизации или обновления токенов
  /// 
  /// ⚠️ КРИТИЧНО: Сохраняем токены последовательно и проверяем после сохранения
  /// для надежности на Android (FlutterSecureStorage может иметь проблемы
  /// с параллельным сохранением)
  Future<void> saveTokens(String access, String refresh, int userId) async {
    try {
      // 🔹 Сохраняем токены последовательно для надежности
      await storage.write(key: "access_token", value: access);
      await storage.write(key: "refresh_token", value: refresh);
      await storage.write(key: "user_id", value: userId.toString());
      
      // 🔹 Проверяем, что токены действительно сохранились
      final savedAccess = await storage.read(key: "access_token");
      final savedRefresh = await storage.read(key: "refresh_token");
      final savedUserId = await storage.read(key: "user_id");
      
      if (kDebugMode) {
        debugPrint('🔹 Токены сохранены: access=${savedAccess != null}, refresh=${savedRefresh != null}, userId=${savedUserId != null}');
      }
      
      // 🔹 Если токены не сохранились - выбрасываем ошибку
      if (savedAccess == null || savedRefresh == null || savedUserId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ ОШИБКА: Токены не сохранились после записи!');
        }
        throw Exception('Не удалось сохранить токены');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Ошибка при сохранении токенов: $e');
      }
      rethrow;
    }
  }

  /// 🔹 Выход из системы - удаление всех сохраненных данных
  Future<void> logout() async {
    await storage.deleteAll();
  }

  /// 🔹 Быстрая проверка наличия сохраненных токенов (без сетевого запроса)
  /// Используется для определения начального экрана при запуске приложения
  /// Возвращает true если есть access_token, refresh_token и user_id
  Future<bool> hasStoredTokens() async {
    try {
      final token = await getAccessToken();
      final refresh = await getRefreshToken();
      final userID = await getUserId();
      
      if (kDebugMode) {
        debugPrint('🔹 Проверка токенов: access=${token != null}, refresh=${refresh != null}, userId=${userID != null}');
      }
      
      if (token == null) {
        if (kDebugMode) {
          debugPrint('⚠️ Access token не найден');
        }
        return false;
      }

      if (refresh == null) {
        if (kDebugMode) {
          debugPrint('⚠️ Refresh token не найден');
        }
        return false;
      }

      if (userID == null) {
        if (kDebugMode) {
          debugPrint('⚠️ User ID не найден');
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint('✅ Все токены найдены, userId=$userID');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Ошибка при проверке токенов: $e');
      }
      return false;
    }
  }

  /// 🔹 Проверка валидности access_token через сеть
  /// Выполняет запрос к серверу для проверки токена
  /// Если токен невалиден, пытается обновить через refresh_token
  /// 
  /// Возвращает:
  /// - true если токен валиден или успешно обновлен
  /// - false если токен невалиден и не удалось обновить
  Future<bool> validateToken() async {
    final token = await getAccessToken();
    if (token == null) return false;

    final userID = await getUserId();
    if (userID == null) return false;

    try {
      // ApiService автоматически добавит заголовки с токеном
      final api = ApiService();
      final data = await api.post('/check_token.php');

      if (data["valid"] == true) {
        // Токен валиден
        return true;
      }
      
      // Токен невалиден - пробуем обновить через refresh_token
      if (kDebugMode) {
        debugPrint('🔹 Access token невалиден, пытаемся обновить через refresh_token');
      }
      return await refreshToken();
    } on ApiException catch (e) {
      // Ошибка сети или сервера - пробуем обновить токен
      if (kDebugMode) {
        debugPrint('⚠️ Ошибка при проверке токена: $e, пытаемся обновить');
      }
      return await refreshToken();
    }
  }

  /// 🔹 Проверка авторизации пользователя
  /// Сначала проверяет наличие токенов локально (быстро)
  /// Затем валидирует токен через сеть (если есть интернет)
  /// 
  /// ⚡ ОПТИМИЗАЦИЯ: Для быстрого старта приложения сначала проверяем
  /// наличие токенов локально. Если токены есть - считаем пользователя
  /// авторизованным. Валидацию токена можно сделать в фоне или при первом запросе.
  Future<bool> isAuthorized() async {
    // Сначала быстрая проверка наличия токенов
    if (!await hasStoredTokens()) {
      return false;
    }

    // Если токены есть, пытаемся валидировать через сеть
    // Но если сети нет или сервер недоступен - все равно считаем авторизованным
    // (токены еще не просрочены по времени)
    try {
      return await validateToken();
    } catch (e) {
      // Если ошибка сети - все равно считаем авторизованным
      // (токены сохранены, валидацию сделаем при первом запросе к API)
      return true;
    }
  }

  // Обновление access_token через refresh_token
  Future<bool> refreshToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return false;

    final userID = await getUserId();
    if (userID == null) return false;

    try {
      final api = ApiService();
      final data = await api.post(
        '/refresh.php',
        body: {"refresh_token": refresh, "userID": userID},
      );

      if (data["success"] == true) {
        // 🔹 Сохраняем новый access token после обновления
        final newAccessToken = data["access_token"] as String?;
        if (newAccessToken != null) {
          await storage.write(key: "access_token", value: newAccessToken);
        }
        return true;
      }
    } on ApiException {
      // Ошибка обновления токена
      return false;
    }

    return false;
  }
}
