// ────────────────────────────────────────────────────────────────────────────
//  УТИЛИТА ДЛЯ ИМПОРТА ТРЕНИРОВОК ИЗ HEALTH CONNECT
//
//  Функции для сохранения тренировок из Health Connect/HealthKit в БД
//  через API endpoint create_activity.php
// ────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'package:health/health.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';

import '../../../../../../../providers/services/api_provider.dart';
import '../../../../../../../providers/services/auth_provider.dart';
import '../../../../../../../core/utils/error_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// ИМПОРТ ОДНОЙ ТРЕНИРОВКИ В БД
///
/// Загружает полные данные тренировки (дистанция, пульс, маршрут) и
/// сохраняет их в базу данных через API
/// ─────────────────────────────────────────────────────────────────────────
Future<ImportResult> importWorkout(
  HealthDataPoint workout,
  Health health,
  WidgetRef ref,
) async {
  try {
    // ──────────────────────────────────────────────────────────────
    // Извлекаем калории из WorkoutHealthValue
    // ──────────────────────────────────────────────────────────────
    double? caloriesFromWorkout;

    if (workout.value is WorkoutHealthValue) {
      final wv = workout.value as WorkoutHealthValue;

      // Извлекаем калории (totalEnergyBurned может быть int или double)
      final burned = wv.totalEnergyBurned;
      if (burned != null) {
        final burnedValue = burned.toDouble();
        if (burnedValue > 0) {
          caloriesFromWorkout = burnedValue;
        }
      }
    }

    final wStart = workout.dateFrom;
    final wEnd = workout.dateTo;

    // ─── Загружаем дистанцию за период тренировки ───
    final dists = await health.getHealthDataFromTypes(
      types: const [HealthDataType.DISTANCE_DELTA],
      startTime: wStart,
      endTime: wEnd,
    );
    double distanceMeters = 0;
    for (final p in dists) {
      final v = p.value;
      if (v is NumericHealthValue) {
        distanceMeters += v.numericValue.toDouble();
      }
    }

    // Пропускаем тренировки без дистанции
    if (distanceMeters <= 0) {
      return const ImportResult(
        success: false,
        message: 'Тренировка без дистанции пропущена',
      );
    }

    // ─── Загружаем пульс за период тренировки ───
    final hrPoints = await health.getHealthDataFromTypes(
      types: const [HealthDataType.HEART_RATE],
      startTime: wStart,
      endTime: wEnd,
    );
    double? hrAvg;
    double? hrMin;
    double? hrMax;
    if (hrPoints.isNotEmpty) {
      final hrValues = <double>[];
      for (final p in hrPoints) {
        final v = p.value;
        if (v is NumericHealthValue) {
          hrValues.add(v.numericValue.toDouble());
        }
      }
      if (hrValues.isNotEmpty) {
        hrAvg = hrValues.reduce((a, b) => a + b) / hrValues.length;
        hrMin = hrValues.reduce((a, b) => a < b ? a : b);
        hrMax = hrValues.reduce((a, b) => a > b ? a : b);
      }
    }

    // ─── Длительность ───
    final duration = wEnd.difference(wStart);

    // ─── Загружаем каденс за период тренировки ───
    // Вычисляем каденс из шагов (шагов в минуту)
    // Также сохраняем totalSteps для отправки на сервер
    double? cadenceAvg;
    int? totalStepsFromHealth;
    try {
      final stepsPoints = await health.getHealthDataFromTypes(
        types: const [HealthDataType.STEPS],
        startTime: wStart,
        endTime: wEnd,
      );
      if (stepsPoints.isNotEmpty) {
        int totalSteps = 0;
        for (final p in stepsPoints) {
          final v = p.value;
          if (v is NumericHealthValue) {
            // Health API может возвращать шаги как дельты (изменения за период)
            // или как накопительные значения. Суммируем все значения.
            final stepValue = v.numericValue.toInt();
            // Игнорируем отрицательные значения (могут быть артефактами)
            if (stepValue > 0) {
              totalSteps += stepValue;
            }
          }
        }

        // Вычисляем средний каденс: шаги / (длительность в минутах)
        // Используем дробные минуты для точности (не duration.inMinutes)
        final durationMinutes = duration.inSeconds / 60.0;

        // Проверяем разумность значений
        // Для бега каденс обычно 150-180 шагов/минуту
        // Если каденс получается слишком маленьким (< 50), возможно данные некорректны
        if (totalSteps > 0 && durationMinutes > 0) {
          final calculatedCadence = totalSteps / durationMinutes;

          // Если каденс разумный (>= 50 шагов/минуту), используем его
          // Иначе пытаемся вычислить шаги из дистанции (примерно 1300 шагов/км для бега)
          if (calculatedCadence >= 50) {
            cadenceAvg = calculatedCadence;
            totalStepsFromHealth = totalSteps;
          } else {
            // Каденс слишком маленький - возможно данные Health API некорректны
            // Вычисляем шаги из дистанции как альтернативу
            // Для бега: примерно 1300 шагов на километр
            final estimatedSteps = (distanceMeters / 1000.0 * 1300).round();
            if (estimatedSteps > 0 && durationMinutes > 0) {
              final estimatedCadence = estimatedSteps / durationMinutes;
              // Используем оценку только если она разумная
              if (estimatedCadence >= 50 && estimatedCadence <= 250) {
                cadenceAvg = estimatedCadence;
                totalStepsFromHealth = estimatedSteps;
              }
            }
          }
        } else if (totalSteps > 0) {
          // Если есть шаги, но длительность = 0, используем их как есть
          totalStepsFromHealth = totalSteps;
        }
      }
    } catch (_) {
      // Каденс недоступен — продолжаем без него
    }

    // ─── Загружаем маршрут (только для Android) ───
    List<LatLng> route = const [];
    List<Map<String, dynamic>> routeData = const [];
    if (Platform.isAndroid) {
      try {
        final routeStart = wStart.subtract(const Duration(minutes: 5));
        final routeEnd = wEnd.add(const Duration(minutes: 5));
        const channel = MethodChannel('paceup/route');
        final res = await channel
            .invokeMethod<List<dynamic>>('getExerciseRoute', <String, dynamic>{
              'start': routeStart.millisecondsSinceEpoch,
              'end': routeEnd.millisecondsSinceEpoch,
            });

        if (res != null && res.isNotEmpty) {
          routeData = res.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return {
              'lat': (m['lat'] as num).toDouble(),
              'lng': (m['lng'] as num).toDouble(),
              'alt': (m['alt'] as num?)?.toDouble(),
            };
          }).toList();

          route = routeData
              .where((p) => p['lat'] != null && p['lng'] != null)
              .map((p) => LatLng(p['lat']!, p['lng']!))
              .toList();
        }
      } catch (_) {
        // Маршрут недоступен — продолжаем без него
      }
    }

    // ─── Определяем тип активности ───
    final activityType = _mapWorkoutTypeToActivityType(workout);

    // ─── Формируем stats ───
    final stats = <String, dynamic>{
      'distance': distanceMeters,
      'duration': duration.inSeconds,
    };

    if (hrAvg != null) stats['avgHeartRate'] = hrAvg;
    if (hrMin != null) stats['minHeartRate'] = hrMin;
    if (hrMax != null) stats['maxHeartRate'] = hrMax;
    if (cadenceAvg != null) stats['avgCadence'] = cadenceAvg;
    if (caloriesFromWorkout != null) stats['calories'] = caloriesFromWorkout;
    if (totalStepsFromHealth != null) {
      stats['totalSteps'] = totalStepsFromHealth;
    }

    stats['startedAt'] = wStart.toIso8601String();
    stats['finishedAt'] = wEnd.toIso8601String();

    if (distanceMeters > 0 && duration.inSeconds > 0) {
      final avgSpeed = (distanceMeters / duration.inSeconds) * 3.6;
      final avgPace = (duration.inSeconds / (distanceMeters / 1000.0)) / 60.0;
      stats['avgSpeed'] = avgSpeed;
      stats['avgPace'] = avgPace;
    }

    // ─── Вычисляем статистику по высоте ───
    if (routeData.isNotEmpty) {
      final altitudeStats = _calculateAltitudeStats(routeData, distanceMeters);
      stats.addAll(altitudeStats);
    }

    final params = jsonEncode([
      {'stats': stats},
    ]);
    final pointsList = route
        .map((p) => 'LatLng(${p.latitude}, ${p.longitude})')
        .toList();
    final points = jsonEncode(pointsList);

    // ─── Форматируем даты ───
    String formatDateTime(DateTime dt) {
      return '${dt.year}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    }

    // ─── Получаем ID пользователя ───
    final authService = ref.read(authServiceProvider);
    final userId = await authService.getUserId();
    if (userId == null) {
      return const ImportResult(
        success: false,
        message: 'Пользователь не авторизован',
      );
    }

    // ─── Отправляем на сервер ───
    final body = <String, dynamic>{
      'user_id': userId,
      'type': activityType,
      'date_start': formatDateTime(wStart),
      'date_end': formatDateTime(wEnd),
      'params': params,
      'points': points,
      'privacy': '0',
      'equip_id': 0,
      'media': '',
    };

    final api = ref.read(apiServiceProvider);
    final response = await api.post('/create_activity.php', body: body);

    if (response['success'] == true) {
      return const ImportResult(
        success: true,
        message: 'Тренировка успешно импортирована',
      );
    } else {
      return ImportResult(
        success: false,
        message: response['message'] ?? 'Неизвестная ошибка',
      );
    }
  } catch (e) {
    return ImportResult(
      success: false,
      message: ErrorHandler.formatWithContext(e, context: 'импорте тренировки'),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// РЕЗУЛЬТАТ ИМПОРТА ТРЕНИРОВКИ
/// ─────────────────────────────────────────────────────────────────────────
class ImportResult {
  final bool success;
  final String message;

  const ImportResult({required this.success, required this.message});
}

/// ─────────────────────────────────────────────────────────────────────────
/// МАППИНГ ТИПА ТРЕНИРОВКИ
/// ─────────────────────────────────────────────────────────────────────────
String _mapWorkoutTypeToActivityType(HealthDataPoint workout) {
  final value = workout.value;
  if (value is WorkoutHealthValue) {
    final activityTypeName = value.workoutActivityType.name.toLowerCase();
    if (activityTypeName.contains('running') ||
        activityTypeName.contains('walking') ||
        activityTypeName.contains('hiking') ||
        activityTypeName.contains('jogging')) {
      return 'run';
    } else if (activityTypeName.contains('cycling') ||
        activityTypeName.contains('bike')) {
      return 'bike';
    } else if (activityTypeName.contains('swimming') ||
        activityTypeName.contains('swim')) {
      return 'swim';
    }
  }
  return 'run';
}

/// ─────────────────────────────────────────────────────────────────────────
/// ВЫЧИСЛЕНИЕ СТАТИСТИКИ ПО ВЫСОТЕ
/// ─────────────────────────────────────────────────────────────────────────
Map<String, dynamic> _calculateAltitudeStats(
  List<Map<String, dynamic>> routeData,
  double totalDistanceMeters,
) {
  final result = <String, dynamic>{};
  final validPoints = routeData
      .where((p) => p['alt'] != null && (p['alt'] as num).toDouble() >= 0)
      .toList();

  if (validPoints.isEmpty) {
    return {
      'minAltitude': 0.0,
      'minAltitudeCoords': null,
      'maxAltitude': 0.0,
      'maxAltitudeCoords': null,
      'cumulativeElevationGain': 0.0,
      'cumulativeElevationLoss': 0.0,
      'altPerKm': <String, double>{},
    };
  }

  double minAlt = double.infinity;
  double maxAlt = double.negativeInfinity;
  Map<String, dynamic>? minAltCoords;
  Map<String, dynamic>? maxAltCoords;

  for (final point in validPoints) {
    final alt = (point['alt'] as num).toDouble();
    if (alt < minAlt) {
      minAlt = alt;
      minAltCoords = {'lat': point['lat'], 'lng': point['lng']};
    }
    if (alt > maxAlt) {
      maxAlt = alt;
      maxAltCoords = {'lat': point['lat'], 'lng': point['lng']};
    }
  }

  result['minAltitude'] = minAlt.isFinite ? minAlt : 0.0;
  result['minAltitudeCoords'] = minAltCoords;
  result['maxAltitude'] = maxAlt.isFinite ? maxAlt : 0.0;
  result['maxAltitudeCoords'] = maxAltCoords;

  double cumulativeGain = 0.0;
  double cumulativeLoss = 0.0;

  for (int i = 1; i < validPoints.length; i++) {
    final prevAlt = (validPoints[i - 1]['alt'] as num).toDouble();
    final currAlt = (validPoints[i]['alt'] as num).toDouble();
    final diff = currAlt - prevAlt;

    if (diff > 0) {
      cumulativeGain += diff;
    } else if (diff < 0) {
      cumulativeLoss += diff.abs();
    }
  }

  result['cumulativeElevationGain'] = cumulativeGain;
  result['cumulativeElevationLoss'] = cumulativeLoss;

  final altPerKm = <String, double>{};
  if (totalDistanceMeters > 0 && validPoints.length > 1) {
    final totalKm = totalDistanceMeters / 1000.0;
    final pointsPerKm = (validPoints.length / totalKm).ceil();

    int kmIndex = 1;
    final currentKmAlts = <double>[];

    for (int i = 0; i < validPoints.length; i++) {
      final alt = (validPoints[i]['alt'] as num).toDouble();
      currentKmAlts.add(alt);

      if (currentKmAlts.length >= pointsPerKm || i == validPoints.length - 1) {
        if (currentKmAlts.isNotEmpty) {
          final avgAlt =
              currentKmAlts.reduce((a, b) => a + b) / currentKmAlts.length;
          final kmKey =
              i == validPoints.length - 1 && (totalKm - kmIndex + 1) < 1.0
              ? 'km_${kmIndex}_partial'
              : 'km_$kmIndex';
          altPerKm[kmKey] = avgAlt;
          currentKmAlts.clear();
          kmIndex++;
        }
      }
    }
  }

  result['altPerKm'] = altPerKm;
  return result;
}
