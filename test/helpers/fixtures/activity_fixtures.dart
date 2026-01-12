// ────────────────────────────────────────────────────────────────────────────
//  ACTIVITY FIXTURES
//
//  Фикстуры для создания тестовых данных активностей
//  Используются в unit и widget тестах
// ────────────────────────────────────────────────────────────────────────────

import 'package:paceup/domain/models/activity_lenta.dart';

/// Фикстуры для создания тестовых активностей
class ActivityFixtures {
  /// Создаёт базовую активность для тестов
  static Activity createActivity({
    int? id,
    String? type,
    DateTime? dateStart,
    DateTime? dateEnd,
    int? lentaId,
    DateTime? lentaDate,
    int? userId,
    String? userName,
    String? userAvatar,
    int? likes,
    int? comments,
    List<Equipment>? equipments,
    ActivityStats? stats,
    List<Coord>? points,
  }) {
    return Activity(
      id: id ?? 1,
      type: type ?? 'running',
      dateStart: dateStart ?? DateTime.now().subtract(Duration(hours: 1)),
      dateEnd: dateEnd ?? DateTime.now(),
      lentaId: lentaId ?? 1,
      lentaDate: lentaDate ?? DateTime.now(),
      userId: userId ?? 1,
      userName: userName ?? 'Test User',
      userAvatar: userAvatar ?? 'https://example.com/avatar.jpg',
      likes: likes ?? 0,
      comments: comments ?? 0,
      userGroup: 0,
      equipments: equipments ?? [],
      stats: stats ?? createActivityStats(),
      points: points ?? [],
    );
  }

  /// Создаёт активность бега
  static Activity createRunningActivity({
    int? id,
    int? lentaId,
    int? userId,
    double? distance,
    int? duration,
  }) {
    return createActivity(
      id: id,
      type: 'running',
      lentaId: lentaId,
      userId: userId,
      stats: createActivityStats(
        distance: distance,
        duration: duration,
      ),
    );
  }

  /// Создаёт активность велосипеда
  static Activity createCyclingActivity({
    int? id,
    int? lentaId,
    int? userId,
    double? distance,
  }) {
    return createActivity(
      id: id,
      type: 'cycling',
      lentaId: lentaId,
      userId: userId,
      stats: createActivityStats(distance: distance),
    );
  }

  /// Создаёт список активностей для тестов
  static List<Activity> createActivityList({
    int count = 3,
    int? userId,
  }) {
    return List.generate(
      count,
      (index) => createActivity(
        id: index + 1,
        lentaId: index + 1,
        userId: userId ?? 1,
        lentaDate: DateTime.now().subtract(Duration(hours: index)),
      ),
    );
  }

  /// Создаёт ActivityStats для тестов
  static ActivityStats createActivityStats({
    double? distance,
    double? avgSpeed,
    double? avgPace,
    int? duration,
  }) {
    return ActivityStats(
      distance: distance ?? 5.0,
      realDistance: distance ?? 5.0,
      avgSpeed: avgSpeed ?? 10.0,
      avgPace: avgPace ?? 6.0,
      minAltitude: 0.0,
      minAltitudeCoords: null,
      maxAltitude: 100.0,
      maxAltitudeCoords: null,
      cumulativeElevationGain: 50.0,
      cumulativeElevationLoss: 30.0,
      startedAt: DateTime.now().subtract(Duration(hours: 1)),
      startedAtCoords: null,
      finishedAt: DateTime.now(),
      finishedAtCoords: null,
      duration: duration ?? 3600,
      bounds: [],
      avgHeartRate: null,
      heartRatePerKm: {},
      pacePerKm: {},
    );
  }

  /// Создаёт Equipment для тестов
  static Equipment createEquipment({
    String? name,
    String? brand,
    int? mileage,
    String? type,
  }) {
    return Equipment(
      name: name ?? 'Test Equipment',
      brand: brand ?? 'Test Brand',
      mileage: mileage ?? 100,
      img: 'https://example.com/equipment.jpg',
      main: true,
      myRating: 4.5,
      type: type ?? 'running_shoes',
    );
  }

  /// Создаёт Coord для тестов
  static Coord createCoord({
    double? lat,
    double? lng,
  }) {
    return Coord(
      lat: lat ?? 55.7558,
      lng: lng ?? 37.6173,
    );
  }

  /// Создаёт список координат для маршрута
  static List<Coord> createRoutePoints({
    int count = 10,
  }) {
    return List.generate(
      count,
      (index) => createCoord(
        lat: 55.7558 + (index * 0.001),
        lng: 37.6173 + (index * 0.001),
      ),
    );
  }

  /// Создаёт JSON для API ответа с активностями
  static Map<String, dynamic> createApiResponse({
    List<Activity>? activities,
    bool success = true,
  }) {
    final activitiesList = activities ?? createActivityList();
    
    return {
      'success': success,
      'data': activitiesList.map((activity) => _activityToJson(activity)).toList(),
    };
  }

  /// Конвертирует Activity в JSON (упрощённая версия)
  static Map<String, dynamic> _activityToJson(Activity activity) {
    return {
      'id': activity.id,
      'type': activity.type,
      'date_start': activity.dateStart?.toIso8601String(),
      'date_end': activity.dateEnd?.toIso8601String(),
      'lenta_id': activity.lentaId,
      'lenta_date': activity.lentaDate?.toIso8601String(),
      'user_id': activity.userId,
      'user_name': activity.userName,
      'user_avatar': activity.userAvatar,
      'likes': activity.likes,
      'comments': activity.comments,
      'user_group': activity.userGroup,
      'equpments': activity.equipments.map((e) => {
        'name': e.name,
        'brand': e.brand,
        'mileage': e.mileage,
        'img': e.img,
        'main': e.main ? 1 : 0,
        'myraiting': e.myRating,
        'type': e.type,
      }).toList(),
      'params': activity.stats != null ? {
        'distance': activity.stats!.distance,
        'realDistance': activity.stats!.realDistance,
        'avgSpeed': activity.stats!.avgSpeed,
        'avgPace': activity.stats!.avgPace,
        'duration': activity.stats!.duration,
      } : null,
      'points': activity.points.map((p) => 'LatLng(${p.lat}, ${p.lng})').toList(),
      'islike': activity.islike ? 1 : 0,
      'media': {
        'images': activity.mediaImages,
        'videos': activity.mediaVideos,
      },
    };
  }
}
