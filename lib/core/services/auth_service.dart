import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

/// 🔹 Сервис для управления авторизацией пользователя
/// Использует FlutterSecureStorage для безопасного хранения токенов
class AuthService {
  /// 🔹 Безопасное хранилище для токенов и данных пользователя
  final storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
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
    final userIdStr = await storage.read(key: "user_id");
    return userIdStr != null ? int.tryParse(userIdStr) : null;
  }

  /// 🔹 Сохранение токенов и ID пользователя в безопасное хранилище
  /// Вызывается после успешной авторизации или обновления токенов
  Future<void> saveTokens(String access, String refresh, int userId) async {
    await Future.wait([
      storage.write(key: "access_token", value: access),
      storage.write(key: "refresh_token", value: refresh),
      storage.write(key: "user_id", value: userId.toString()),
    ]);
  }

  /// 🔹 Выход из системы - удаление всех сохраненных данных
  Future<void> logout() async {
    await storage.deleteAll();
  }

  // Проверка access_token на валидность
  Future<bool> isAuthorized() async {
    final token = await getAccessToken();
    if (token == null) return false;

    final userID = await getUserId();
    if (userID == null) return false;

    try {
      // ApiService автоматически добавит заголовки с токеном
      final api = ApiService();
      final data = await api.post('/check_token.php');

      if (data["valid"] == true) return true;
    } on ApiException {
      // Токен невалиден или ошибка сети
    }

    // Если access_token просрочен, пробуем обновить
    return await refreshToken();
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
