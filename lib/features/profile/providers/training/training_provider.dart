// ────────────────────────────────────────────────────────────────────────────
//  TRAINING PROVIDER
//
//  Провайдеры для получения тренировок пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/services/auth_provider.dart';
import '../../../../providers/services/api_provider.dart';

/// Модель тренировки
class TrainingActivity {
  final int id;
  final DateTime when; // Дата и время тренировки
  final int sportType; // 0=бег, 1=вело, 2=плавание
  final double distance; // км
  final String distanceText; // "21,24 км"
  final int duration; // секунды
  final String durationText; // "1:48:52"
  final double pace; // средний темп
  final String paceText; // "4:15 /км"
  final List<RoutePoint> points; // Точки маршрута для карты

  TrainingActivity({
    required this.id,
    required this.when,
    required this.sportType,
    required this.distance,
    required this.distanceText,
    required this.duration,
    required this.durationText,
    required this.pace,
    required this.paceText,
    required this.points,
  });

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

    return TrainingActivity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      when: whenDate,
      sportType: (json['sportType'] as num?)?.toInt() ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      distanceText: json['distanceText'] as String? ?? '0 км',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      durationText: json['durationText'] as String? ?? '0:00',
      pace: (json['pace'] as num?)?.toDouble() ?? 0.0,
      paceText: json['paceText'] as String? ?? '',
      points: pointsList,
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
final trainingActivitiesProvider =
    FutureProvider.family<TrainingData, Set<int>>((ref, sports) async {
  final api = ref.watch(apiServiceProvider);
  final auth = ref.watch(authServiceProvider);

  final userId = await auth.getUserId();
  if (userId == null) {
    return TrainingData(
      activities: [],
      calendar: {},
    );
  }

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

