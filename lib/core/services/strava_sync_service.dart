// ────────────────────────────────────────────────────────────────────────────
//  СЕРВИС АВТОМАТИЧЕСКОЙ СИНХРОНИЗАЦИИ STRAVA
//
//  Автоматически синхронизирует новые тренировки из Strava в БД
//  Синхронизация запускается при загрузке LentaScreen вместе с Health Connect
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/services/auth_provider.dart';
import '../../../providers/services/api_provider.dart';
import '../../../features/lenta/providers/lenta_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// СЕРВИС АВТОМАТИЧЕСКОЙ СИНХРОНИЗАЦИИ ТРЕНИРОВОК ИЗ STRAVA
/// ─────────────────────────────────────────────────────────────────────────
class StravaSyncService {
  /// Синхронизирует новые тренировки из Strava
  /// 
  /// Проверяет, настроена ли синхронизация Strava для пользователя,
  /// и если да - получает новые тренировки из Strava API через сервер
  Future<SyncResult> syncNewWorkouts(WidgetRef ref) async {
    try {
      // Получаем ID пользователя
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();
      
      if (userId == null) {
        return const SyncResult(
          success: false,
          importedCount: 0,
          message: 'Пользователь не авторизован',
        );
      }
      
      // Вызываем API синхронизации Strava на сервере
      final api = ref.read(apiServiceProvider);
      
      final response = await api.post(
        '/strava_sync_activities.php',
        body: {'user_id': userId},
      );
      
      if (response['success'] == true) {
        final syncedCount = response['synced_count'] ?? 0;
        final failedCount = response['failed_count'] ?? 0;
        final message = response['message'] ?? 'Синхронизация завершена';
        
        // Обновляем ленту после успешного импорта
        if (syncedCount > 0) {
          // Задержка перед обновлением - даём серверу время обработать
          await Future.delayed(const Duration(milliseconds: 500));
          ref.read(lentaProvider(userId).notifier).forceRefresh();
        }
        
        return SyncResult(
          success: true,
          importedCount: syncedCount,
          failedCount: failedCount,
          message: message,
        );
      } else {
        final message = response['message'] ?? 'Ошибка синхронизации Strava';
        return SyncResult(
          success: false,
          importedCount: 0,
          message: message,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Ошибка синхронизации Strava: $e');
      debugPrint('Stack trace: $stackTrace');
      return SyncResult(
        success: false,
        importedCount: 0,
        message: 'Ошибка синхронизации: $e',
      );
    }
  }
}

/// Результат синхронизации (используется тот же класс что и для HealthSyncService)
class SyncResult {
  final bool success;
  final int importedCount;
  final int failedCount;
  final String message;
  
  const SyncResult({
    required this.success,
    required this.importedCount,
    this.failedCount = 0,
    required this.message,
  });
}

/// Provider для StravaSyncService (singleton)
final stravaSyncServiceProvider = Provider<StravaSyncService>((ref) {
  return StravaSyncService();
});
