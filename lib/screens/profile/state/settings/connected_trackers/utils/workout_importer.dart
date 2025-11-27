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

import '../../../../../../service/api_service.dart';
import '../../../../../../service/auth_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// ИМПОРТ ОДНОЙ ТРЕНИРОВКИ В БД
///
/// Загружает полные данные тренировки (дистанция, пульс, маршрут) и
/// сохраняет их в базу данных через API
/// ─────────────────────────────────────────────────────────────────────────
Future<ImportResult> importWorkout(
  HealthDataPoint workout,
  Health health,
) async {
  try {
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

    // ─── Загружаем маршрут (только для Android) ───
    List<LatLng> route = const [];
    List<Map<String, dynamic>> routeData = const [];
    if (Platform.isAndroid) {
      try {
        final routeStart = wStart.subtract(const Duration(minutes: 5));
        final routeEnd = wEnd.add(const Duration(minutes: 5));
        const channel = MethodChannel('paceup/route');
        final res = await channel.invokeMethod<List<dynamic>>(
          'getExerciseRoute',
          <String, dynamic>{
            'start': routeStart.millisecondsSinceEpoch,
            'end': routeEnd.millisecondsSinceEpoch,
          },
        );

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

    final params = jsonEncode([{'stats': stats}]);
    final pointsList =
        route.map((p) => 'LatLng(${p.latitude}, ${p.longitude})').toList();
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
    final authService = AuthService();
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

    final api = ApiService();
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
      message: 'Ошибка импорта: $e',
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// РЕЗУЛЬТАТ ИМПОРТА ТРЕНИРОВКИ
/// ─────────────────────────────────────────────────────────────────────────
class ImportResult {
  final bool success;
  final String message;

  const ImportResult({
    required this.success,
    required this.message,
  });
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

      if (currentKmAlts.length >= pointsPerKm ||
          i == validPoints.length - 1) {
        if (currentKmAlts.isNotEmpty) {
          final avgAlt =
              currentKmAlts.reduce((a, b) => a + b) / currentKmAlts.length;
          final kmKey = i == validPoints.length - 1 &&
                  (totalKm - kmIndex + 1) < 1.0
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

