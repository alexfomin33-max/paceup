// ────────────────────────────────────────────────────────────────────────────
//  CONNECTED TRACKERS NOTIFIER
//
//  StateNotifier для управления состоянием экрана подключенных трекеров
//  Возможности:
//  • Конфигурация Health
//  • Синхронизация данных за 7 дней
//  • Импорт тренировок
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/error_handler.dart';
import '../../screens/profile/state/settings/connected_trackers/utils/workout_importer.dart';
import 'connected_trackers_state.dart';

class ConnectedTrackersNotifier extends StateNotifier<ConnectedTrackersState> {
  // Типы данных Health
  static const List<HealthDataType> _types = <HealthDataType>[
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  ConnectedTrackersNotifier() : super(ConnectedTrackersState.initial());

  /// Утилита для получения ключа дня
  DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Конфигурация Health
  Future<void> ensureConfigured(Health health) async {
    try {
      await health.configure();
      state = state.copyWith(configured: true);

      if (Platform.isAndroid) {
        final hasHC = await health.isHealthConnectAvailable();

        if (hasHC == false) {
          await health.installHealthConnect();
          state = state.copyWith(
            status:
                'Health Connect не был установлен. Установите его и вернитесь.',
          );
        } else {
          state = state.copyWith(status: 'Health Connect найден.');
        }
      } else {
        state = state.copyWith(
          status: 'Готово к синхронизации с Apple Здоровьем.',
        );
      }
    } catch (e) {
      state = state.copyWith(status: 'Ошибка инициализации: $e');
    }
  }

  /// Запрос разрешений (требует контекст для диалогов)
  Future<bool> requestPermissions(
    Health health,
    BuildContext context,
  ) async {
    if (!state.configured) {
      await ensureConfigured(health);
    }

    final has = await health.hasPermissions(
      _types,
      permissions: List.generate(_types.length, (_) => HealthDataAccess.READ),
    );
    if (has == true) return true;

    final granted = await health.requestAuthorization(
      _types,
      permissions: List.generate(_types.length, (_) => HealthDataAccess.READ),
    );
    if (granted) return true;

    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text('Нужен доступ к данным'),
        content: Text(
          Platform.isIOS
              ? 'Разрешите доступ в системном диалоге, чтобы импортировать тренировки, пульс и ккал.'
              : 'Откроется Health Connect — включите разрешения на чтение (тренировки, дистанция, пульс и активные калории — если доступны источником).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );

    if (retry != true) return false;

    final ok2 = await health.requestAuthorization(
      _types,
      permissions: List.generate(_types.length, (_) => HealthDataAccess.READ),
    );

    if (!ok2) {
      final hint = Platform.isIOS
          ? 'Настройки → Здоровье → Доступ к данным → PaceUp.'
          : 'Приложение «Health Connect» → Права доступа → PaceUp.';
      showSnackBar('Доступ не выдан. Проверьте $hint');
    }
    return ok2;
  }

  /// Показать сообщение в SnackBar
  void showSnackBar(String message) {
    state = state.copyWith(snackBarMessage: message);
  }

  /// Очистить сообщение SnackBar
  void clearSnackBar() {
    state = state.copyWith(clearSnackBar: true);
  }

  /// Синхронизация за 7 дней
  Future<void> fetchLast7Days(
    Health health,
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (state.busy) return;

    state = state.copyWith(
      busy: true,
      status: 'Запрашиваю доступ…',
      clearMetrics: true,
    );

    try {
      final ok = await requestPermissions(health, context);
      if (!ok) {
        state = state.copyWith(
          status: 'Доступ к данным не выдан.',
          busy: false,
        );
        return;
      }

      state = state.copyWith(status: 'Синхронизация за 7 дней…');
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final points = await health.getHealthDataFromTypes(
        types: _types,
        startTime: weekAgo,
        endTime: now,
      );

      points.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      // Разложим по типам
      final byType = <HealthDataType, List<HealthDataPoint>>{};
      for (final p in points) {
        byType.putIfAbsent(p.type, () => <HealthDataPoint>[]).add(p);
      }

      // Шаги — сумма за весь период
      int stepsTotal = 0;
      for (final p in byType[HealthDataType.STEPS] ?? const <HealthDataPoint>[]) {
        final v = p.value;
        if (v is NumericHealthValue) {
          stepsTotal += v.numericValue.toInt();
        }
      }

      // Тренировки
      final workouts =
          byType[HealthDataType.WORKOUT] ?? const <HealthDataPoint>[];

      final workoutWindows = <DateTimeRange>[];
      final workoutInfos = <WorkoutInfo>[];

      double distanceMeters = 0;
      double activeKcal = 0;

      // Пульс — только во время тренировок
      final hrValsAllWorkouts = <double>[];
      final hrSumByDay = <DateTime, double>{};
      final hrCountByDay = <DateTime, int>{};
      final distanceByDayMeters = <DateTime, double>{};
      final distanceTimeByDay = <DateTime, Duration>{};

      // Для каждой тренировки получаем её данные
      for (final workout in workouts) {
        final wStart = workout.dateFrom;
        final wEnd = workout.dateTo;
        final wDuration = wEnd.difference(wStart);

        // Определяем вид тренировки
        final v = workout.value;
        String kind = 'Тренировка';
        if (v is WorkoutHealthValue) {
          kind = v.workoutActivityType.name;
        } else {
          final raw = v.toString().toLowerCase();
          if (raw.contains('running')) {
            kind = 'Бег';
          } else if (raw.contains('walking')) {
            kind = 'Ходьба';
          } else if (raw.contains('cycling')) {
            kind = 'Велосипед';
          } else if (raw.contains('swimming')) {
            kind = 'Плавание';
          }
        }

        // Сохраняем информацию о тренировке
        final start = wStart.subtract(const Duration(minutes: 5));
        final end = wEnd.add(const Duration(minutes: 5));
        workoutWindows.add(DateTimeRange(start: start, end: end));
        workoutInfos.add(WorkoutInfo(start: wStart, end: wEnd, kind: kind));

        // Запрашиваем дистанцию для этой тренировки
        try {
          final dists = await health.getHealthDataFromTypes(
            types: const [HealthDataType.DISTANCE_DELTA],
            startTime: wStart,
            endTime: wEnd,
          );
          double workoutDistance = 0;
          for (final p in dists) {
            final val = p.value;
            if (val is NumericHealthValue) {
              workoutDistance += val.numericValue.toDouble();
            }
          }
          distanceMeters += workoutDistance;

          // Добавляем в разбивку по дням
          final day = _dayKey(wStart);
          distanceByDayMeters.update(
            day,
            (old) => old + workoutDistance,
            ifAbsent: () => workoutDistance,
          );
          distanceTimeByDay.update(
            day,
            (old) => old + wDuration,
            ifAbsent: () => wDuration,
          );
        } catch (_) {
          // Если не удалось получить дистанцию, продолжаем
        }

        // Запрашиваем калории для этой тренировки
        try {
          final calories = await health.getHealthDataFromTypes(
            types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
            startTime: wStart,
            endTime: wEnd,
          );
          for (final p in calories) {
            final val = p.value;
            if (val is NumericHealthValue) {
              activeKcal += val.numericValue.toDouble();
            }
          }
        } catch (_) {
          // Если не удалось получить калории, продолжаем
        }

        // Запрашиваем пульс для этой тренировки
        try {
          final hrPoints = await health.getHealthDataFromTypes(
            types: const [HealthDataType.HEART_RATE],
            startTime: wStart,
            endTime: wEnd,
          );
          if (hrPoints.isNotEmpty) {
            final day = _dayKey(wStart);

            for (final p in hrPoints) {
              final val = p.value;
              if (val is NumericHealthValue) {
                final hr = val.numericValue.toDouble();
                hrValsAllWorkouts.add(hr);
                hrSumByDay.update(day, (old) => old + hr, ifAbsent: () => hr);
                hrCountByDay.update(day, (old) => old + 1, ifAbsent: () => 1);
              }
            }
          }
        } catch (_) {
          // Если не удалось получить пульс, продолжаем
        }
      }

      // Вычисляем средний пульс по всем тренировкам
      double? hrAvg;
      if (hrValsAllWorkouts.isNotEmpty) {
        final sum = hrValsAllWorkouts.reduce((a, b) => a + b);
        hrAvg = sum / hrValsAllWorkouts.length;
      }

      // Обновляем разбивку по дням: средний пульс = сумма / количество
      final hrAvgByDay = <DateTime, double>{};
      hrSumByDay.forEach((k, sum) {
        final count = hrCountByDay[k] ?? 1;
        hrAvgByDay[k] = sum / count;
      });

      state = state.copyWith(
        stepsTotal: stepsTotal,
        sumDistanceMeters: distanceMeters,
        sumActiveKcal: activeKcal,
        hrAvg: hrAvg,
        distanceByDayMeters: distanceByDayMeters,
        distanceTimeByDay: distanceTimeByDay,
        hrAvgByDay: hrAvgByDay,
        workouts: workouts.length,
        workoutWindows: workoutWindows,
        workoutInfos: workoutInfos,
        periodStart: weekAgo,
        periodEnd: now,
        status:
            'Готово: синх за 7 дней выполнен. Найдено тренировок: ${workouts.length}',
        busy: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: 'Ошибка: $e',
        busy: false,
      );
      showSnackBar(ErrorHandler.format(e));
    }
  }

  /// Импорт всех найденных тренировок
  Future<void> importAllWorkouts(
    Health health,
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (state.importing) return;

    state = state.copyWith(
      importing: true,
      importedCount: 0,
      failedCount: 0,
      status: 'Импорт тренировок…',
    );

    try {
      final ok = await requestPermissions(health, context);
      if (!ok) {
        state = state.copyWith(
          status: 'Доступ к данным не выдан.',
          importing: false,
        );
        return;
      }

      // Получаем все тренировки за период
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final workouts = await health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT],
        startTime: weekAgo,
        endTime: now,
      );

      if (workouts.isEmpty) {
        state = state.copyWith(
          status: 'Тренировки не найдены.',
          importing: false,
        );
        return;
      }

      // Сортируем по дате начала (старые первыми)
      workouts.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      int importedCount = 0;
      int failedCount = 0;

      // Импортируем каждую тренировку
      for (int i = 0; i < workouts.length; i++) {
        final workout = workouts[i];
        state = state.copyWith(
          status: 'Импорт тренировки ${i + 1} из ${workouts.length}…',
        );

        final result = await importWorkout(workout, health, ref);

        if (result.success) {
          importedCount++;
        } else {
          failedCount++;
        }

        // Небольшая задержка между импортами
        await Future.delayed(const Duration(milliseconds: 500));
      }

      state = state.copyWith(
        status:
            'Импорт завершён: успешно $importedCount, ошибок $failedCount',
        importing: false,
        importedCount: importedCount,
        failedCount: failedCount,
      );

      showSnackBar(
        'Импортировано тренировок: $importedCount${failedCount > 0 ? ', ошибок: $failedCount' : ''}',
      );
    } catch (e) {
      state = state.copyWith(
        status: 'Ошибка импорта: $e',
        importing: false,
      );
      showSnackBar(
        ErrorHandler.formatWithContext(e, context: 'импорте тренировок'),
      );
    }
  }
}

