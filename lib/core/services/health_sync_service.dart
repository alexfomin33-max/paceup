// ────────────────────────────────────────────────────────────────────────────
//  СЕРВИС АВТОМАТИЧЕСКОЙ СИНХРОНИЗАЦИИ HEALTH CONNECT
//
//  Автоматически импортирует новые тренировки из Health Connect в БД
//  Синхронизация запускается при загрузке LentaScreen
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import '../../../providers/services/auth_provider.dart';
import '../../../features/lenta/providers/lenta_provider.dart';
import '../../../features/profile/screens/state/settings/connected_trackers/utils/workout_importer.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// СЕРВИС АВТОМАТИЧЕСКОЙ СИНХРОНИЗАЦИИ ТРЕНИРОВОК
/// ─────────────────────────────────────────────────────────────────────────
class HealthSyncService {
  final Health _health = Health();
  static const MethodChannel _syncChannel = MethodChannel('paceup/health_sync');
  
  /// Получает время последней синхронизации
  Future<DateTime?> getLastSyncTime() async {
    if (!Platform.isAndroid) return null;
    
    try {
      final timestamp = await _syncChannel.invokeMethod<int>('getLastSyncTime');
      if (timestamp != null && timestamp > 0) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('Ошибка при получении времени синхронизации: $e');
    }
    return null;
  }
  
  /// Сохраняет время последней успешной синхронизации
  Future<void> setLastSyncTime(DateTime time) async {
    if (!Platform.isAndroid) return;
    
    try {
      await _syncChannel.invokeMethod('setLastSyncTime', {'timeMillis': time.millisecondsSinceEpoch});
    } catch (e) {
      debugPrint('Ошибка при сохранении времени синхронизации: $e');
    }
  }
  
  /// Автоматически синхронизирует новые тренировки из Health Connect
  /// 
  /// Проверяет тренировки с момента последней синхронизации и импортирует только новые
  Future<SyncResult> syncNewWorkouts(WidgetRef ref) async {
    try {
      // Проверяем доступность Health Connect
      if (Platform.isAndroid) {
        await _health.configure();
        
        final hasHC = await _health.isHealthConnectAvailable();
        if (hasHC == false) {
          return const SyncResult(
            success: false,
            importedCount: 0,
            message: 'Health Connect недоступен',
          );
        }
      }
      
      // Проверяем разрешения
      final types = <HealthDataType>[HealthDataType.WORKOUT];
      final hasPermissions = await _health.hasPermissions(
        types,
        permissions: List.generate(types.length, (_) => HealthDataAccess.READ),
      );
      
      if (hasPermissions != true) {
        return const SyncResult(
          success: false,
          importedCount: 0,
          message: 'Разрешения не выданы',
        );
      }
      
      // Получаем время последней синхронизации
      final lastSyncTime = await getLastSyncTime();
      final syncStartTime = lastSyncTime ?? DateTime.now().subtract(const Duration(days: 7));
      
      // Получаем тренировки с момента последней синхронизации
      final now = DateTime.now();
      final workouts = await _health.getHealthDataFromTypes(
        types: types,
        startTime: syncStartTime,
        endTime: now,
      );
      
      if (workouts.isEmpty) {
        return const SyncResult(
          success: true,
          importedCount: 0,
          message: 'Новых тренировок не найдено',
        );
      }
      
      // Сортируем по дате начала (старые первыми)
      workouts.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      
      // Фильтруем только новые тренировки (после последней синхронизации)
      final List<dynamic> newWorkouts;
      
      if (lastSyncTime != null) {
        newWorkouts = workouts.where((w) {
          return w.dateTo.isAfter(lastSyncTime) || w.dateFrom.isAfter(lastSyncTime);
        }).toList();
      } else {
        newWorkouts = workouts;
      }
      
      if (newWorkouts.isEmpty) {
        return const SyncResult(
          success: true,
          importedCount: 0,
          message: 'Все тренировки уже импортированы',
        );
      }
      
      // Импортируем новые тренировки
      int importedCount = 0;
      int failedCount = 0;
      
      for (final workout in newWorkouts) {
        try {
          final result = await importWorkout(workout, _health, ref);
          
          if (result.success) {
            importedCount++;
          } else {
            failedCount++;
          }
          
          // Небольшая задержка между импортами
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          failedCount++;
          debugPrint('Ошибка импорта тренировки: $e');
        }
      }
      
      // Сохраняем время последней синхронизации
      if (importedCount > 0 || newWorkouts.isEmpty) {
        await setLastSyncTime(DateTime.now());
      }
      
      // Обновляем ленту после успешного импорта
      if (importedCount > 0) {
        final authService = ref.read(authServiceProvider);
        final userId = await authService.getUserId();
        
        if (userId != null) {
          // Задержка перед обновлением - даём серверу время обработать
          await Future.delayed(const Duration(milliseconds: 500));
          ref.read(lentaProvider(userId).notifier).forceRefresh();
        }
      }
      
      return SyncResult(
        success: true,
        importedCount: importedCount,
        failedCount: failedCount,
        message: importedCount > 0
            ? 'Импортировано тренировок: $importedCount${failedCount > 0 ? ', ошибок: $failedCount' : ''}'
            : 'Новых тренировок не найдено',
      );
    } catch (e, stackTrace) {
      debugPrint('Ошибка синхронизации: $e');
      debugPrint('Stack trace: $stackTrace');
      return SyncResult(
        success: false,
        importedCount: 0,
        message: 'Ошибка синхронизации: $e',
      );
    }
  }
}

/// Результат синхронизации
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

/// Provider для HealthSyncService (singleton)
final healthSyncServiceProvider = Provider<HealthSyncService>((ref) {
  return HealthSyncService();
});
