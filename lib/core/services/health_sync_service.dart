// ────────────────────────────────────────────────────────────────────────────
//  СЕРВИС АВТОМАТИЧЕСКОЙ СИНХРОНИЗАЦИИ HEALTH CONNECT
//
//  Автоматически импортирует новые тренировки из Health Connect в БД
//  Синхронизация запускается при загрузке LentaScreen
// ────────────────────────────────────────────────────────────────────────────

import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/services/auth_provider.dart';
import '../../../features/lenta/providers/lenta_provider.dart';
import '../../../features/profile/screens/state/settings/connected_trackers/utils/workout_importer.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// СЕРВИС АВТОМАТИЧЕСКОЙ СИНХРОНИЗАЦИИ ТРЕНИРОВОК
/// ─────────────────────────────────────────────────────────────────────────
class HealthSyncService {
  final Health _health = Health();
  static const MethodChannel _syncChannel = MethodChannel('paceup/health_sync');
  static const String _prefsKeyLastSyncTime = 'health_last_sync_time';
  
  /// Получает время последней синхронизации
  Future<DateTime?> getLastSyncTime() async {
    try {
      if (Platform.isAndroid) {
        // На Android используем MethodChannel
        final timestamp = await _syncChannel.invokeMethod<int>('getLastSyncTime');
        if (timestamp != null && timestamp > 0) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      } else {
        // На iOS используем SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final timestamp = prefs.getInt(_prefsKeyLastSyncTime);
        if (timestamp != null && timestamp > 0) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
    } catch (e) {
      debugPrint('Ошибка при получении времени синхронизации: $e');
    }
    return null;
  }
  
  /// Сохраняет время последней успешной синхронизации
  Future<void> setLastSyncTime(DateTime time) async {
    try {
      if (Platform.isAndroid) {
        // На Android используем MethodChannel
        await _syncChannel.invokeMethod('setLastSyncTime', {'timeMillis': time.millisecondsSinceEpoch});
      } else {
        // На iOS используем SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefsKeyLastSyncTime, time.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('Ошибка при сохранении времени синхронизации: $e');
    }
  }
  
  /// Автоматически синхронизирует новые тренировки из Health Connect/Apple Health
  /// 
  /// Ищет тренировки за последние 2 дня и импортирует те, которых ещё нет в базе.
  /// Сервер сам проверит дубликаты и вернет ошибку, если тренировка уже существует.
  Future<SyncResult> syncNewWorkouts(WidgetRef ref) async {
    try {
      // Конфигурируем Health плагин
      await _health.configure();
      
      // Проверяем доступность Health Connect на Android
      if (Platform.isAndroid) {
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
      
      // ────────────────────────────────────────────────────────────────
      // 🔄 НОВАЯ ЛОГИКА: всегда ищем тренировки за последние 2 дня
      // ────────────────────────────────────────────────────────────────
      // Импортируем все найденные тренировки за последние 2 дня
      // Сервер сам проверит дубликаты и вернет ошибку, если тренировка уже есть
      final now = DateTime.now();
      final syncStartTime = now.subtract(const Duration(days: 2));
      
      developer.log(
        '[HEALTH_SYNC] Поиск тренировок за последние 2 дня: '
        'с ${syncStartTime.toIso8601String()} '
        'по ${now.toIso8601String()}',
        name: 'HealthSyncService',
      );
      
      final workouts = await _health.getHealthDataFromTypes(
        types: types,
        startTime: syncStartTime,
        endTime: now,
      );
      
      developer.log(
        '[HEALTH_SYNC] Получено тренировок от Health Connect: ${workouts.length}',
        name: 'HealthSyncService',
      );
      
      if (workouts.isEmpty) {
        return const SyncResult(
          success: true,
          importedCount: 0,
          message: 'Тренировок за последние 2 дня не найдено',
        );
      }
      
      // Сортируем по дате начала по убыванию (новые первыми)
      workouts.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      
      // ────────────────────────────────────────────────────────────────
      // 🔍 ЛОГИРОВАНИЕ: выводим информацию о всех найденных тренировках
      // ────────────────────────────────────────────────────────────────
      developer.log(
        '[HEALTH_SYNC] Найдено тренировок за последние 2 дня: ${workouts.length}',
        name: 'HealthSyncService',
      );
      
      for (int i = 0; i < workouts.length; i++) {
        final workout = workouts[i];
        String workoutType = 'unknown';
        if (workout.value is WorkoutHealthValue) {
          final wv = workout.value as WorkoutHealthValue;
          workoutType = wv.workoutActivityType.name;
        }
        
        developer.log(
          '[HEALTH_SYNC] Тренировка ${i + 1}/${workouts.length}: '
          'тип=$workoutType, '
          'дата начала=${workout.dateFrom.toIso8601String()}, '
          'дата окончания=${workout.dateTo.toIso8601String()}, '
          'длительность=${workout.dateTo.difference(workout.dateFrom).inMinutes} мин',
          name: 'HealthSyncService',
        );
      }
      
      // Импортируем все найденные тренировки
      // Сервер проверит дубликаты и вернет ошибку, если тренировка уже есть
      final newWorkouts = workouts;
      
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
      
      developer.log(
        '[HEALTH_SYNC] Начинаем импорт ${newWorkouts.length} тренировок',
        name: 'HealthSyncService',
      );
      
      for (int i = 0; i < newWorkouts.length; i++) {
        final workout = newWorkouts[i];
        String workoutType = 'unknown';
        if (workout.value is WorkoutHealthValue) {
          final wv = workout.value as WorkoutHealthValue;
          workoutType = wv.workoutActivityType.name;
        }
        
        developer.log(
          '[HEALTH_SYNC] Импорт тренировки ${i + 1}/${newWorkouts.length}: '
          'тип=$workoutType, '
          'дата=${workout.dateFrom.toIso8601String()}',
          name: 'HealthSyncService',
        );
        
        try {
          final result = await importWorkout(workout, _health, ref);
          
          if (result.success) {
            importedCount++;
            developer.log(
              '[HEALTH_SYNC] ✅ Тренировка ${i + 1} успешно импортирована',
              name: 'HealthSyncService',
            );
          } else {
            failedCount++;
            developer.log(
              '[HEALTH_SYNC] ❌ Ошибка импорта тренировки ${i + 1}: ${result.message}',
              name: 'HealthSyncService',
            );
          }
          
          // Небольшая задержка между импортами
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          failedCount++;
          developer.log(
            '[HEALTH_SYNC] ❌ Исключение при импорте тренировки ${i + 1}: $e',
            name: 'HealthSyncService',
          );
        }
      }
      
      developer.log(
        '[HEALTH_SYNC] Импорт завершен: успешно=$importedCount, ошибок=$failedCount',
        name: 'HealthSyncService',
      );
      
      // Сохраняем время последней синхронизации только при успешном импорте
      // Не сохраняем, если все тренировки уже были в базе (failedCount == newWorkouts.length)
      if (importedCount > 0) {
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
