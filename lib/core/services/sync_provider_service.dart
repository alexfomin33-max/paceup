import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/services/api_provider.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// 🔹 Сервис для работы с способом синхронизации тренировок
/// Предоставляет методы для получения и установки активного способа синхронизации
class SyncProviderService {
  final ApiService _apiService;
  final AuthService _authService = AuthService();

  SyncProviderService(this._apiService);

  /// 🔹 Получение текущего способа синхронизации
  /// 
  /// Возвращает название активного способа синхронизации или null
  Future<String?> getSyncProvider() async {
    try {
      final response = await _apiService.post(
        '/get_sync_provider.php',
        body: null,
      );

      if (response['success'] == true) {
        return response['sync_provider'] as String?;
      }

      return null;
    } catch (e) {
      // Логи отключены
      // if (kDebugMode) {
      //   debugPrint('Ошибка получения способа синхронизации: $e');
      // }
      return null;
    }
  }

  /// 🔹 Установка способа синхронизации
  /// 
  /// [syncProvider] - Название способа синхронизации
  /// Возможные значения: 'health_connect', 'apple_health', 'garmin', 'coros', 'suunto', 'polar'
  /// null - отключить синхронизацию
  /// 
  /// Возвращает результат установки
  Future<Map<String, dynamic>> setSyncProvider(String? syncProvider) async {
    try {
      final response = await _apiService.post(
        '/set_sync_provider.php',
        body: {
          'sync_provider': syncProvider,
        },
      );

      return response;
    } catch (e) {
      // Логи отключены
      // if (kDebugMode) {
      //   debugPrint('Ошибка установки способа синхронизации: $e');
      // }
      rethrow;
    }
  }
}

/// Provider для SyncProviderService (singleton)
final syncProviderServiceProvider = Provider<SyncProviderService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return SyncProviderService(apiService);
});
