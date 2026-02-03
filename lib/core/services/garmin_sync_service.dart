import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/services/api_provider.dart';
import '../utils/error_handler.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// 🔹 Сервис для синхронизации тренировок из Garmin Connect
/// Предоставляет методы для авторизации и синхронизации активностей
class GarminSyncService {
  final ApiService _apiService;
  final AuthService _authService = AuthService();

  GarminSyncService(this._apiService);

  /// 🔹 Авторизация в Garmin Connect
  /// 
  /// [email] - Email аккаунта Garmin
  /// [password] - Пароль аккаунта Garmin
  /// [resetOtherSyncs] - Сбросить другие синхронизации (по умолчанию true)
  /// 
  /// Возвращает результат авторизации
  Future<Map<String, dynamic>> authorize({
    required String email,
    required String password,
    bool resetOtherSyncs = true,
  }) async {
    try {
      // Сбрасываем другие синхронизации перед авторизацией Garmin
      if (resetOtherSyncs) {
        try {
          final userId = await _authService.getUserId();
          if (userId != null) {
            await _apiService.post(
              '/garmin/reset_other_syncs.php',
              body: {'user_id': userId},
            );
            // Логи отключены
            // if (kDebugMode) {
            //   debugPrint('✅ Другие синхронизации отключены');
            // }
          }
        } catch (e) {
          // Логи отключены
          // if (kDebugMode) {
          //   debugPrint('⚠️ Ошибка сброса других синхронизаций: $e');
          // }
          // Продолжаем авторизацию даже если сброс не удался
        }
      }
      
      final response = await _apiService.post(
        '/garmin/authorize.php',
        body: {
          'email': email,
          'password': password,
        },
      );

      return response;
    } catch (e) {
      // Логи отключены
      // if (kDebugMode) {
      //   debugPrint('Ошибка авторизации Garmin: $e');
      // }
      rethrow;
    }
  }

  /// 🔹 Проверка статуса подключения Garmin
  /// 
  /// Возвращает информацию о подключении
  Future<Map<String, dynamic>> checkConnection() async {
    try {
      // Получаем user_id для передачи в теле запроса (резервный вариант)
      final userId = await _authService.getUserId();
      
      final response = await _apiService.post(
        '/garmin/check_status.php',
        body: userId != null ? {'user_id': userId} : null,
      );

      return response;
    } catch (e) {
      // Логи отключены
      // if (kDebugMode) {
      //   debugPrint('Ошибка проверки подключения Garmin: $e');
      // }
      rethrow;
    }
  }

  /// 🔹 Синхронизация последней тренировки из Garmin Connect
  /// 
  /// Получает последнюю тренировку и сохраняет её в БД
  /// Возвращает результат синхронизации
  Future<Map<String, dynamic>> syncLastActivity({String? garminActivityId}) async {
    try {
      // Получаем user_id для передачи в теле запроса (резервный вариант)
      final userId = await _authService.getUserId();
      
      final body = <String, dynamic>{};
      if (userId != null) {
        body['user_id'] = userId;
      }
      if (garminActivityId != null) {
        body['garmin_activity_id'] = garminActivityId;
      }
      
      final response = await _apiService.post(
        '/garmin/sync_activity.php',
        body: body.isNotEmpty ? body : null,
      );

      return response;
    } catch (e) {
      // Логи отключены
      // if (kDebugMode) {
      //   debugPrint('Ошибка синхронизации Garmin: $e');
      // }
      rethrow;
    }
  }

  /// 🔹 Синхронизация всех неподдерживаемых тренировок из Garmin Connect
  /// 
  /// Получает до [limit] последних тренировок (по умолчанию 10) и сохраняет их в БД
  /// Пропускает уже синхронизированные тренировки
  /// 
  /// [limit] - Максимальное количество тренировок для синхронизации (максимум 10)
  /// Возвращает результат синхронизации
  Future<Map<String, dynamic>> syncAllActivities({int limit = 10}) async {
    try {
      // Получаем user_id для передачи в теле запроса
      final userId = await _authService.getUserId();
      
      final response = await _apiService.post(
        '/garmin/sync_all_activities.php',
        body: userId != null 
            ? {'user_id': userId, 'limit': limit.clamp(1, 10)} 
            : {'limit': limit.clamp(1, 10)},
      );

      // 🔹 ЛОГИ ОТКЛЮЧЕНЫ
      // if (kDebugMode) {
      //   debugPrint('🔹 [Garmin Sync] Получен ответ от сервера:');
      //   debugPrint('🔹 [Garmin Sync] success: ${response['success']}');
      //   debugPrint('🔹 [Garmin Sync] message: ${response['message']}');
      //   debugPrint('🔹 [Garmin Sync] version: ${response['version'] ?? 'не указана'}');
      //   if (response.containsKey('debug')) {
      //     debugPrint('🔹 [Garmin Sync] DEBUG данные: ${response['debug']}');
      //   }
      //   debugPrint('🔹 [Garmin Sync] Полный ответ: $response');
      // }

      return response;
    } catch (e) {
      // Логи отключены
      // if (kDebugMode) {
      //   debugPrint('Ошибка синхронизации всех активностей Garmin: $e');
      // }
      rethrow;
    }
  }

  /// 🔹 Получение учётных данных Garmin для редактирования (только email)
  /// 
  /// Пароль никогда не возвращается с сервера.
  Future<Map<String, dynamic>> getCredentials() async {
    try {
      final userId = await _authService.getUserId();
      final response = await _apiService.post(
        '/garmin/get_garmin_credentials.php',
        body: userId != null ? {'user_id': userId} : null,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// 🔹 Обновление учётных данных Garmin (email и опционально новый пароль)
  /// 
  /// [password] — если передан, выполняется повторная авторизация и сохранение;
  /// если не передан, обновляется только email.
  Future<Map<String, dynamic>> updateCredentials({
    required String email,
    String? password,
  }) async {
    try {
      final userId = await _authService.getUserId();
      final body = <String, dynamic>{
        'email': email.trim(),
        if (userId != null) 'user_id': userId,
      };
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }
      final response = await _apiService.post(
        '/garmin/update_garmin_credentials.php',
        body: body,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// 🔹 Отключение Garmin аккаунта
  /// 
  /// Удаляет сохраненные токены
  Future<Map<String, dynamic>> disconnect() async {
    try {
      // Получаем user_id для передачи в теле запроса (резервный вариант)
      final userId = await _authService.getUserId();
      
      final response = await _apiService.post(
        '/garmin/disconnect.php',
        body: userId != null ? {'user_id': userId} : null,
      );

      return response;
    } catch (e) {
      // Логи отключены
      // if (kDebugMode) {
      //   debugPrint('Ошибка отключения Garmin: $e');
      // }
      rethrow;
    }
  }
}

/// Provider для GarminSyncService (singleton)
final garminSyncServiceProvider = Provider<GarminSyncService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return GarminSyncService(apiService);
});
