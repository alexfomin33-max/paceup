// ────────────────────────────────────────────────────────────────────────────
//  TRAINING PROVIDER
//
//  Провайдеры для получения тренировок пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/activity_lenta.dart' as al;
import '../../../../providers/services/api_provider.dart';

/// Модель тренировки
class TrainingActivity {
  final int id;
  final DateTime when; // Дата и время тренировки
  final int sportType; // 0=бег, 1=вело, 2=плавание, 3=лыжи
  final double distance; // км
  final String distanceText; // "21,24 км"
  final int duration; // секунды
  final int? movingDuration; // секунды - время в движении (если есть и > 0, используется вместо duration)
  final String durationText; // "1:48:52"
  final double pace; // средний темп
  final String paceText; // "4:15 /км"
  final List<RoutePoint> points; // Точки маршрута для карты
  final bool hasValidTrack; // Есть ли валидный трек маршрута
  final String? firstImageUrl; // URL первого изображения (если есть)
  // ────────────────────────────────────────────────────────────────
  // ✅ ПОЛНЫЕ ДАННЫЕ: пульс, каденс, набор высоты, разбивка по км
  // ────────────────────────────────────────────────────────────────
  final double? avgHeartRate;
  final double? avgCadence;
  final double? cumulativeElevationGain;
  final double? cumulativeElevationLoss;
  final double? minAltitude;
  final double? maxAltitude;
  final double? calories;
  final int? steps;
  final Map<String, double> heartRatePerKm;
  final Map<String, double> pacePerKm;
  final Map<String, double> elevationPerKm;
  final Map<String, double> wattsPerKm; // мощность (ватты) по километрам
  final Map<String, dynamic>? stats; // Полный объект stats для совместимости

  TrainingActivity({
    required this.id,
    required this.when,
    required this.sportType,
    required this.distance,
    required this.distanceText,
    required this.duration,
    this.movingDuration,
    required this.durationText,
    required this.pace,
    required this.paceText,
    required this.points,
    required this.hasValidTrack,
    this.firstImageUrl,
    this.avgHeartRate,
    this.avgCadence,
    this.cumulativeElevationGain,
    this.cumulativeElevationLoss,
    this.minAltitude,
    this.maxAltitude,
    this.calories,
    this.steps,
    this.heartRatePerKm = const {},
    this.pacePerKm = const {},
    this.elevationPerKm = const {},
    this.wattsPerKm = const {},
    this.stats,
  });

  /// ────────────────────────────────────────────────────────────────
  /// ⏱️ ПОЛУЧЕНИЕ ПРАВИЛЬНОГО DURATION: если есть movingDuration и он > 0,
  /// используем его, иначе используем duration
  /// ────────────────────────────────────────────────────────────────
  int get effectiveDuration {
    if (movingDuration != null && movingDuration! > 0) {
      return movingDuration!;
    }
    return duration;
  }

  factory TrainingActivity.fromJson(Map<String, dynamic> json) {
    // Парсим дату/время
    DateTime whenDate;
    try {
      whenDate = DateTime.parse(json['when'] as String);
    } catch (e) {
      whenDate = DateTime.now();
    }

    // Парсим точки маршрута
    final pointsList = <RoutePoint>[];
    if (json['points'] is List) {
      for (final p in json['points'] as List) {
        if (p is Map<String, dynamic>) {
          final lat = (p['lat'] as num?)?.toDouble() ?? 0.0;
          final lng = (p['lng'] as num?)?.toDouble() ?? 0.0;
          if (lat != 0.0 || lng != 0.0) {
            pointsList.add(RoutePoint(lat: lat, lng: lng));
          }
        }
      }
    }

    // ────────────────────────────────────────────────────────────────
    // ✅ ПАРСИНГ ПОЛНЫХ ДАННЫХ: пульс, каденс, набор высоты, разбивка по км
    // ────────────────────────────────────────────────────────────────
    final avgHeartRate = json['avgHeartRate'] != null 
        ? (json['avgHeartRate'] as num).toDouble() 
        : null;
    final avgCadence = json['avgCadence'] != null 
        ? (json['avgCadence'] as num).toDouble() 
        : null;
    final cumulativeElevationGain = json['cumulativeElevationGain'] != null 
        ? (json['cumulativeElevationGain'] as num).toDouble() 
        : null;
    final cumulativeElevationLoss = json['cumulativeElevationLoss'] != null 
        ? (json['cumulativeElevationLoss'] as num).toDouble() 
        : null;
    final minAltitude = json['minAltitude'] != null 
        ? (json['minAltitude'] as num).toDouble() 
        : null;
    final maxAltitude = json['maxAltitude'] != null 
        ? (json['maxAltitude'] as num).toDouble() 
        : null;
    final calories = json['calories'] != null 
        ? (json['calories'] as num).toDouble() 
        : null;
    final steps = json['steps'] != null 
        ? (json['steps'] as num).toInt() 
        : null;
    
    // Парсим разбивку по километрам
    final heartRatePerKm = <String, double>{};
    if (json['heartRatePerKm'] is Map) {
      (json['heartRatePerKm'] as Map).forEach((key, value) {
        if (value is num) {
          heartRatePerKm[key.toString()] = value.toDouble();
        }
      });
    }
    
    final pacePerKm = <String, double>{};
    if (json['pacePerKm'] is Map) {
      (json['pacePerKm'] as Map).forEach((key, value) {
        if (value is num) {
          pacePerKm[key.toString()] = value.toDouble();
        }
      });
    }
    
    // 🏔️ ПАРСИНГ ВЫСОТЫ: поддерживаем оба варианта (elevationPerKm и ElevationPerKm)
    // В базе данных в поле params может быть как elevationPerKm, так и ElevationPerKm
    final elevationPerKm = <String, double>{};
    final elevationData = json['elevationPerKm'] ?? json['ElevationPerKm'];
    if (elevationData is Map) {
      (elevationData as Map).forEach((key, value) {
        if (value is num) {
          elevationPerKm[key.toString()] = value.toDouble();
        }
      });
    }
    
    final wattsPerKm = <String, double>{};
    if (json['wattsPerKm'] is Map) {
      (json['wattsPerKm'] as Map).forEach((key, value) {
        if (value is num) {
          wattsPerKm[key.toString()] = value.toDouble();
        }
      });
    }
    
    final stats = json['stats'] is Map<String, dynamic> 
        ? json['stats'] as Map<String, dynamic> 
        : null;

    return TrainingActivity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      when: whenDate,
      sportType: (json['sportType'] as num?)?.toInt() ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      distanceText: json['distanceText'] as String? ?? '0 км',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      movingDuration: json['movingDuration'] != null ? (json['movingDuration'] as num).toInt() : null,
      durationText: json['durationText'] as String? ?? '0:00',
      pace: (json['pace'] as num?)?.toDouble() ?? 0.0,
      paceText: json['paceText'] as String? ?? '',
      points: pointsList,
      hasValidTrack: (json['hasValidTrack'] as bool?) ?? false,
      firstImageUrl: json['firstImageUrl'] as String?,
      avgHeartRate: avgHeartRate,
      avgCadence: avgCadence,
      cumulativeElevationGain: cumulativeElevationGain,
      cumulativeElevationLoss: cumulativeElevationLoss,
      minAltitude: minAltitude,
      maxAltitude: maxAltitude,
      calories: calories,
      steps: steps,
      heartRatePerKm: heartRatePerKm,
      pacePerKm: pacePerKm,
      elevationPerKm: elevationPerKm,
      wattsPerKm: wattsPerKm,
      stats: stats,
    );
  }

  /// Конвертирует в al.Activity для экрана описания тренировки
  /// (например, при переходе из «Мои результаты» по маршруту).
  al.Activity toLentaActivity(int userId, String userName, String userAvatar) {
    final sportTypeStr = sportType == 0
        ? 'run'
        : (sportType == 1
            ? 'bike'
            : (sportType == 2 ? 'swim' : (sportType == 3 ? 'ski' : 'run')));
    double calculatedAvgSpeed = 0.0;
    if (pace > 0) calculatedAvgSpeed = 60.0 / pace;
    final statsData = stats;
    if (statsData != null &&
        statsData.containsKey('avgSpeed') &&
        statsData['avgSpeed'] != null) {
      final v = statsData['avgSpeed'];
      if (v is num) calculatedAvgSpeed = v.toDouble();
    }
    al.Coord? minAltitudeCoords;
    al.Coord? maxAltitudeCoords;
    if (statsData != null) {
      if (statsData['minAltitudeCoords'] is Map) {
        final c = statsData['minAltitudeCoords'] as Map;
        if (c['lat'] != null && c['lng'] != null) {
          minAltitudeCoords = al.Coord(
            lat: (c['lat'] as num).toDouble(),
            lng: (c['lng'] as num).toDouble(),
          );
        }
      }
      if (statsData['maxAltitudeCoords'] is Map) {
        final c = statsData['maxAltitudeCoords'] as Map;
        if (c['lat'] != null && c['lng'] != null) {
          maxAltitudeCoords = al.Coord(
            lat: (c['lat'] as num).toDouble(),
            lng: (c['lng'] as num).toDouble(),
          );
        }
      }
    }
    List<al.Coord> boundsList = [];
    if (statsData != null && statsData['bounds'] is List) {
      for (final b in statsData['bounds'] as List) {
        if (b is Map && b['lat'] != null && b['lng'] != null) {
          boundsList.add(al.Coord(
            lat: (b['lat'] as num).toDouble(),
            lng: (b['lng'] as num).toDouble(),
          ));
        }
      }
    }
    if (boundsList.isEmpty && points.length >= 2) {
      boundsList = [
        al.Coord(lat: points.first.lat, lng: points.first.lng),
        al.Coord(lat: points.last.lat, lng: points.last.lng),
      ];
    }
    DateTime? startedAt = when;
    DateTime? finishedAt = when.add(Duration(seconds: effectiveDuration));
    if (statsData != null) {
      if (statsData['startedAt'] != null) {
        try {
          startedAt = DateTime.parse(statsData['startedAt'].toString());
        } catch (_) {}
      }
      if (statsData['finishedAt'] != null) {
        try {
          finishedAt = DateTime.parse(statsData['finishedAt'].toString());
        } catch (_) {}
      }
    }
    al.Coord? startedAtCoords;
    al.Coord? finishedAtCoords;
    if (statsData != null) {
      if (statsData['startedAtCoords'] is Map) {
        final c = statsData['startedAtCoords'] as Map;
        if (c['lat'] != null && c['lng'] != null) {
          startedAtCoords = al.Coord(
            lat: (c['lat'] as num).toDouble(),
            lng: (c['lng'] as num).toDouble(),
          );
        }
      }
      if (statsData['finishedAtCoords'] is Map) {
        final c = statsData['finishedAtCoords'] as Map;
        if (c['lat'] != null && c['lng'] != null) {
          finishedAtCoords = al.Coord(
            lat: (c['lat'] as num).toDouble(),
            lng: (c['lng'] as num).toDouble(),
          );
        }
      }
    }
    if (startedAtCoords == null && points.isNotEmpty) {
      startedAtCoords = al.Coord(lat: points.first.lat, lng: points.first.lng);
    }
    if (finishedAtCoords == null && points.isNotEmpty) {
      finishedAtCoords = al.Coord(lat: points.last.lat, lng: points.last.lng);
    }
    double realDistance = distance * 1000;
    if (statsData != null &&
        statsData['realDistance'] != null &&
        statsData['realDistance'] is num) {
      realDistance = (statsData['realDistance'] as num).toDouble();
    }
    final activityStats = al.ActivityStats(
      distance: distance * 1000,
      realDistance: realDistance,
      avgSpeed: calculatedAvgSpeed,
      avgPace: pace,
      minAltitude: minAltitude ?? 0.0,
      minAltitudeCoords: minAltitudeCoords,
      maxAltitude: maxAltitude ?? 0.0,
      maxAltitudeCoords: maxAltitudeCoords,
      cumulativeElevationGain: cumulativeElevationGain ?? 0.0,
      cumulativeElevationLoss: cumulativeElevationLoss ?? 0.0,
      startedAt: startedAt,
      startedAtCoords: startedAtCoords,
      finishedAt: finishedAt,
      finishedAtCoords: finishedAtCoords,
      duration: duration,
      movingDuration: movingDuration,
      bounds: boundsList,
      avgHeartRate: avgHeartRate,
      avgCadence: avgCadence,
      heartRatePerKm: heartRatePerKm,
      pacePerKm: pacePerKm,
      elevationPerKm: elevationPerKm,
      wattsPerKm: wattsPerKm,
      calories: calories,
      totalSteps: steps,
    );
    final coordPoints = points
        .map((p) => al.Coord(lat: p.lat, lng: p.lng))
        .toList();
    return al.Activity(
      id: id,
      type: sportTypeStr,
      dateStart: when,
      dateEnd: when.add(Duration(seconds: effectiveDuration)),
      lentaId: id,
      lentaDate: when,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      likes: 0,
      comments: 0,
      userGroup: 0,
      equipments: const [],
      stats: activityStats,
      points: coordPoints,
      postDateText: '',
      postMediaUrl: '',
      postContent: '',
      islike: false,
      mediaImages: const [],
      mediaVideos: const [],
    );
  }
}

/// Точка маршрута
class RoutePoint {
  final double lat;
  final double lng;

  RoutePoint({required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

/// Данные календаря (год-месяц => день => дистанция)
/// Пример: {"2025-06": {"15": "21,2", "18": "8,5"}}
typedef CalendarData = Map<String, Map<String, String>>;

/// Результат запроса тренировок
class TrainingData {
  final List<TrainingActivity> activities;
  final CalendarData calendar; // день => "X,XX" км
  final String? lastWorkoutMonth; // "2025-06" для начального месяца

  TrainingData({
    required this.activities,
    required this.calendar,
    this.lastWorkoutMonth,
  });
}

/// Провайдер для получения тренировок пользователя
/// Принимает кортеж (userId, sports) для поддержки просмотра профилей других пользователей
final trainingActivitiesProvider =
    FutureProvider.family<TrainingData, ({int userId, Set<int> sports})>((ref, params) async {
  final api = ref.watch(apiServiceProvider);
  final userId = params.userId;
  final sports = params.sports;

  try {
    // Преобразуем Set<int> в List для JSON
    final sportsList = sports.toList();

    final response = await api.post(
      '/get_training_activities.php',
      body: {
        'userId': userId,
        'sports': sportsList,
      },
    );

    // Парсим ответ
    final activitiesList = <TrainingActivity>[];
    if (response['activities'] is List) {
      final activitiesRaw = response['activities'] as List;
      
      for (final item in activitiesRaw) {
        if (item is Map<String, dynamic>) {
          try {
            activitiesList.add(TrainingActivity.fromJson(item));
          } catch (e) {
            // Игнорируем ошибки парсинга отдельных тренировок
          }
        }
      }
    }

    // Парсим календарь
    // Формат: {"2025-06": {"15": "21,2", "18": "8,5"}}
    final calendarData = <String, Map<String, String>>{};
    if (response['calendar'] is Map) {
      for (final entry in (response['calendar'] as Map).entries) {
        final monthKey = entry.key as String?;
        final daysMap = entry.value;
        if (monthKey != null && daysMap is Map) {
          final days = <String, String>{};
          for (final dayEntry in daysMap.entries) {
            final day = dayEntry.key.toString();
            final dist = dayEntry.value?.toString();
            if (dist != null) {
              days[day] = dist;
            }
          }
          calendarData[monthKey] = days;
        }
      }
    }

    final lastMonth = response['lastWorkoutMonth'] as String?;

    return TrainingData(
      activities: activitiesList,
      calendar: calendarData,
      lastWorkoutMonth: lastMonth,
    );
  } catch (e) {
    return TrainingData(
      activities: [],
      calendar: {},
    );
  }
});

