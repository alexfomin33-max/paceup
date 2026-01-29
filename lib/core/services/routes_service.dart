// lib/core/services/routes_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Сервис для сохранённых маршрутов: сохранение из тренировки, список избранного.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'api_service.dart';
import '../config/app_config.dart';
import '../utils/static_map_url_builder.dart';

/// Элемент маршрута из API (список «Избранное — Маршруты»).
class SavedRouteItem {
  const SavedRouteItem({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.distanceKm,
    required this.ascentM,
    this.routeMapUrl,
    this.bestDurationSec,
    this.lastDurationSec,
    this.durationText,
  });

  final int id;
  final String name;
  final String difficulty;
  final double distanceKm;
  final int ascentM;
  final String? routeMapUrl;
  final int? bestDurationSec;
  final int? lastDurationSec;
  final String? durationText;

  factory SavedRouteItem.fromJson(Map<String, dynamic> j) {
    return SavedRouteItem(
      id: (j['id'] as num).toInt(),
      name: (j['name'] as String?) ?? '',
      difficulty: (j['difficulty'] as String?) ?? 'medium',
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      ascentM: (j['ascent_m'] as num?)?.toInt() ?? 0,
      routeMapUrl: j['route_map_url'] as String?,
      bestDurationSec: j['best_duration_sec'] as int?,
      lastDurationSec: j['last_duration_sec'] as int?,
      durationText: j['duration_text'] as String?,
    );
  }
}

/// Автор маршрута (из API деталей маршрута).
class RouteAuthor {
  const RouteAuthor({
    required this.id,
    required this.name,
    required this.surname,
    required this.avatar,
  });

  final int id;
  final String name;
  final String surname;
  final String avatar;

  String get fullName => '${name.trim()} ${surname.trim()}'.trim();

  factory RouteAuthor.fromJson(Map<String, dynamic> j) {
    return RouteAuthor(
      id: (j['id'] as num).toInt(),
      name: (j['name'] as String?) ?? '',
      surname: (j['surname'] as String?) ?? '',
      avatar: (j['avatar'] as String?) ?? '',
    );
  }
}

/// Детали маршрута из API (экран описания маршрута).
class RouteDetail {
  const RouteDetail({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.distanceKm,
    required this.ascentM,
    this.routeMapUrl,
    this.createdAt,
    this.author,
    this.personalBestSec,
    this.personalBestText,
    this.myWorkoutsCount = 0,
    this.participantsCount = 0,
  });

  final int id;
  final String name;
  final String difficulty;
  final double distanceKm;
  final int ascentM;
  final String? routeMapUrl;
  final String? createdAt;
  final RouteAuthor? author;
  final int? personalBestSec;
  final String? personalBestText;
  final int myWorkoutsCount;
  final int participantsCount;

  factory RouteDetail.fromJson(Map<String, dynamic> j) {
    RouteAuthor? author;
    if (j['author'] is Map<String, dynamic>) {
      author = RouteAuthor.fromJson(
        Map<String, dynamic>.from(j['author'] as Map),
      );
    }
    return RouteDetail(
      id: (j['id'] as num).toInt(),
      name: (j['name'] as String?) ?? '',
      difficulty: (j['difficulty'] as String?) ?? 'medium',
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      ascentM: (j['ascent_m'] as num?)?.toInt() ?? 0,
      routeMapUrl: j['route_map_url'] as String?,
      createdAt: j['created_at'] as String?,
      author: author,
      personalBestSec: j['personal_best_sec'] as int?,
      personalBestText: j['personal_best_text'] as String?,
      myWorkoutsCount: (j['my_workouts_count'] as num?)?.toInt() ?? 0,
      participantsCount:
          (j['participants_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Элемент списка «Мои результаты» по маршруту (тренировка).
class RouteWorkoutItem {
  const RouteWorkoutItem({
    required this.activityId,
    required this.when,
    required this.durationText,
    this.routeMapUrl,
    required this.paceText,
    this.heartRate,
  });

  final int activityId;
  final String when;
  final String durationText;
  final String? routeMapUrl;
  final String paceText;
  final int? heartRate;

  factory RouteWorkoutItem.fromJson(Map<String, dynamic> j) {
    return RouteWorkoutItem(
      activityId: (j['activity_id'] as num?)?.toInt() ?? 0,
      when: (j['when'] as String?) ?? '',
      durationText: (j['duration_text'] as String?) ?? '—',
      routeMapUrl: j['route_map_url'] as String?,
      paceText: (j['pace_text'] as String?) ?? '—',
      heartRate: (j['heart_rate'] as num?)?.toInt(),
    );
  }
}

/// Результат сохранения маршрута.
class SaveRouteResult {
  const SaveRouteResult({
    required this.routeId,
    required this.addedToFavorite,
    this.route,
    this.message,
  });

  final int routeId;
  final bool addedToFavorite;
  final SavedRouteItem? route;
  final String? message;

  factory SaveRouteResult.fromJson(Map<String, dynamic> j) {
    SavedRouteItem? route;
    if (j['route'] is Map<String, dynamic>) {
      route = SavedRouteItem.fromJson(
        Map<String, dynamic>.from(j['route'] as Map),
      );
    }
    return SaveRouteResult(
      routeId: (j['route_id'] as num).toInt(),
      addedToFavorite: j['added_to_favorite'] as bool? ?? false,
      route: route,
      message: j['message'] as String?,
    );
  }
}

/// Сервис для работы с сохранёнными маршрутами.
class RoutesService {
  RoutesService._();
  static final RoutesService _instance = RoutesService._();
  factory RoutesService() => _instance;

  final ApiService _api = ApiService();

  /// Сохранить маршрут из тренировки.
  /// [mapboxImageUrl] — URL статичной карты Mapbox (если null, сервер не сохранит картинку).
  Future<SaveRouteResult> saveRoute({
    required int userId,
    required int activityId,
    required String name,
    required String difficulty,
    String? mapboxImageUrl,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'activity_id': activityId,
      'name': name,
      'difficulty': difficulty,
    };
    if (mapboxImageUrl != null && mapboxImageUrl.isNotEmpty) {
      body['mapbox_image_url'] = mapboxImageUrl;
    }
    final response = await _api.post('/save_route.php', body: body);
    return SaveRouteResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  /// Список маршрутов пользователя (избранное — маршруты).
  Future<List<SavedRouteItem>> getMyRoutes(int userId) async {
    final response = await _api.get(
      '/get_my_routes.php',
      queryParams: {'user_id': userId.toString()},
    );
    final list = response['routes'];
    if (list is! List) return [];
    return (list as List)
        .map((e) => SavedRouteItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// ID маршрута, созданного из данной тренировки (source_activity_id = activityId).
  /// null — маршрут по этой тренировке ещё не сохранён.
  Future<int?> getRouteIdBySourceActivity({
    required int activityId,
    int userId = 0,
  }) async {
    final queryParams = <String, String>{
      'activity_id': activityId.toString(),
    };
    if (userId > 0) {
      queryParams['user_id'] = userId.toString();
    }
    final response = await _api.get(
      '/get_route_by_source_activity.php',
      queryParams: queryParams,
    );
    final raw = response['route_id'];
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return (raw as num).toInt();
    return null;
  }

  /// Тренировки по выбранному маршруту (Мои результаты).
  /// Карты из uploads (route_map_url).
  Future<List<RouteWorkoutItem>> getRouteWorkouts({
    required int routeId,
    required int userId,
  }) async {
    final response = await _api.get(
      '/get_route_workouts.php',
      queryParams: {
        'route_id': routeId.toString(),
        'user_id': userId.toString(),
      },
    );
    final list = response['workouts'];
    if (list is! List) return [];
    return (list as List)
        .map((e) => RouteWorkoutItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// Одна тренировка по ID (для перехода на экран описания).
  /// Возвращает объект в формате get_training_activities (activity).
  Future<Map<String, dynamic>?> getActivityById({
    required int activityId,
    required int userId,
  }) async {
    final response = await _api.get(
      '/get_activity_by_id.php',
      queryParams: {
        'activity_id': activityId.toString(),
        'user_id': userId.toString(),
      },
    );
    final activity = response['activity'];
    if (activity is! Map<String, dynamic>) return null;
    return Map<String, dynamic>.from(activity);
  }

  /// Детали маршрута по ID (дата, автор, личный рекорд, мои результаты,
  /// участники). [userId] — текущий пользователь для персонализированных данных.
  Future<RouteDetail> getRouteDetail({
    required int routeId,
    int userId = 0,
  }) async {
    final queryParams = <String, String>{
      'route_id': routeId.toString(),
    };
    if (userId > 0) {
      queryParams['user_id'] = userId.toString();
    }
    final response = await _api.get(
      '/get_route.php',
      queryParams: queryParams,
    );
    final routeMap = response['route'];
    if (routeMap is! Map<String, dynamic>) {
      throw StateError('get_route: ожидался объект route');
    }
    return RouteDetail.fromJson(
      Map<String, dynamic>.from(routeMap as Map),
    );
  }
}

/// Строит URL статичной карты Mapbox по точкам маршрута (для сохранения на сервере).
String buildRouteMapboxImageUrl(List<LatLng> points) {
  if (points.isEmpty) return '';
  return StaticMapUrlBuilder.fromPoints(
    points: points,
    widthPx: 800,
    heightPx: 400,
  );
}
