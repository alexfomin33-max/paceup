// lib/core/services/routes_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Сервис для сохранённых маршрутов: сохранение из тренировки, список избранного.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'api_service.dart';
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

// ────────────────────────────────────────────────────────────────
// Пакет маршрутов с пагинацией (список + флаг следующей страницы).
// ────────────────────────────────────────────────────────────────
class RoutesPage {
  const RoutesPage({
    required this.routes,
    required this.hasMore,
    required this.nextOffset,
  });

  /// Список маршрутов на текущей странице.
  final List<SavedRouteItem> routes;
  /// Есть ли следующая страница на сервере.
  final bool hasMore;
  /// Смещение для следующей страницы (offset).
  final int nextOffset;
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
/// [leader] — самый быстрый пользователь по этому маршруту (для блока «Лидер»).
/// [leaderBestDurationText] — лучшее время лидера (для блока «Лидер»).
class RouteDetail {
  const RouteDetail({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.distanceKm,
    required this.ascentM,
    this.points = const [],
    this.sourceActivityId,
    this.routeMapUrl,
    this.createdAt,
    this.author,
    this.leader,
    this.leaderBestDurationSec,
    this.leaderBestDurationText,
    this.personalBestSec,
    this.personalBestText,
    this.personalBestActivityId,
    this.personalBestDistanceM,
    this.personalBestAscentM,
    this.myWorkoutsCount = 0,
    this.participantsCount = 0,
    this.isSaved = false,
    this.isOwner = false,
  });

  final int id;
  final String name;
  final String difficulty;
  final double distanceKm;
  final int ascentM;
  /// Точки маршрута (для интерактивной карты).
  final List<LatLng> points;
  /// ID исходной тренировки, из которой сохранён маршрут.
  final int? sourceActivityId;
  final String? routeMapUrl;
  final String? createdAt;
  final RouteAuthor? author;
  /// Самый быстрый пользователь по маршруту (для отображения в блоке «Лидер»).
  final RouteAuthor? leader;
  final int? leaderBestDurationSec;
  final String? leaderBestDurationText;
  final int? personalBestSec;
  final String? personalBestText;
  /// Лучшая тренировка пользователя: id активности для перехода.
  final int? personalBestActivityId;
  /// Дистанция личного рекорда (в метрах, как в params).
  final double? personalBestDistanceM;
  /// Набор высоты личного рекорда (в метрах, как в params).
  final double? personalBestAscentM;
  final int myWorkoutsCount;
  final int participantsCount;
  /// Маршрут сохранён у текущего пользователя (избранное).
  final bool isSaved;
  /// Текущий пользователь — создатель маршрута.
  final bool isOwner;

  factory RouteDetail.fromJson(Map<String, dynamic> j) {
    RouteAuthor? author;
    if (j['author'] is Map<String, dynamic>) {
      author = RouteAuthor.fromJson(
        Map<String, dynamic>.from(j['author'] as Map),
      );
    }
    RouteAuthor? leader;
    if (j['leader'] is Map<String, dynamic>) {
      leader = RouteAuthor.fromJson(
        Map<String, dynamic>.from(j['leader'] as Map),
      );
    }
    return RouteDetail(
      id: (j['id'] as num).toInt(),
      name: (j['name'] as String?) ?? '',
      difficulty: (j['difficulty'] as String?) ?? 'medium',
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      ascentM: (j['ascent_m'] as num?)?.toInt() ?? 0,
      points: _parseRoutePoints(
        j['points'] ?? j['route_points'],
      ),
      sourceActivityId: (j['source_activity_id'] as num?)?.toInt() ??
          (j['activity_id'] as num?)?.toInt(),
      routeMapUrl: j['route_map_url'] as String?,
      createdAt: j['created_at'] as String?,
      author: author,
      leader: leader,
      leaderBestDurationSec: j['leader_best_duration_sec'] as int?,
      leaderBestDurationText: j['leader_best_duration_text'] as String?,
      personalBestSec: j['personal_best_sec'] as int?,
      personalBestText: j['personal_best_text'] as String?,
      personalBestActivityId:
          (j['personal_best_activity_id'] as num?)?.toInt(),
      personalBestDistanceM:
          (j['personal_best_distance_m'] as num?)?.toDouble(),
      personalBestAscentM:
          (j['personal_best_ascent_m'] as num?)?.toDouble(),
      myWorkoutsCount: (j['my_workouts_count'] as num?)?.toInt() ?? 0,
      participantsCount:
          (j['participants_count'] as num?)?.toInt() ?? 0,
      isSaved: j['is_saved'] == true || j['is_saved'] == 1,
      isOwner: j['is_owner'] == true || j['is_owner'] == 1,
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Парсер точек маршрута (поддержка разных форматов API)
// ────────────────────────────────────────────────────────────────
List<LatLng> _parseRoutePoints(dynamic v) {
  final out = <LatLng>[];
  // ────────────────────────────────────────────────────────────────
  // Сервер может вернуть points строкой (JSON); пробуем распарсить
  // ────────────────────────────────────────────────────────────────
  if (v is String) {
    try {
      final decoded = jsonDecode(v);
      return _parseRoutePoints(decoded);
    } catch (_) {
      return out;
    }
  }
  if (v is List) {
    final regex = RegExp(
      r'LatLng\(\s*([\-0-9\.]+)\s*,\s*([\-0-9\.]+)\s*\)',
    );
    for (final e in v) {
      if (e is String) {
        final m = regex.firstMatch(e);
        if (m != null) {
          out.add(
            LatLng(
              double.tryParse(m.group(1)!) ?? 0,
              double.tryParse(m.group(2)!) ?? 0,
            ),
          );
        }
      } else if (e is Map<String, dynamic>) {
        out.add(
          LatLng(
            (e['lat'] as num?)?.toDouble() ?? 0,
            (e['lng'] as num?)?.toDouble() ?? 0,
          ),
        );
      } else if (e is List && e.length >= 2) {
        out.add(
          LatLng(
            (e[0] as num?)?.toDouble() ?? 0,
            (e[1] as num?)?.toDouble() ?? 0,
          ),
        );
      }
    }
  }
  return out;
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

/// Элемент лидерборда по маршруту (общие результаты).
class RouteLeaderboardItem {
  const RouteLeaderboardItem({
    required this.rank,
    required this.userId,
    required this.name,
    required this.surname,
    required this.avatar,
    required this.bestDurationSec,
    required this.bestDate,
    required this.durationText,
    required this.dateText,
    this.paceText,
  });

  final int rank;
  final int userId;
  final String name;
  final String surname;
  final String avatar;
  final int bestDurationSec;
  final String bestDate;
  final String durationText;
  final String dateText;
  final String? paceText;

  String get fullName => '${name.trim()} ${surname.trim()}'.trim();

  factory RouteLeaderboardItem.fromJson(Map<String, dynamic> j) {
    return RouteLeaderboardItem(
      rank: (j['rank'] as num).toInt(),
      userId: (j['user_id'] as num).toInt(),
      name: (j['name'] as String?) ?? '',
      surname: (j['surname'] as String?) ?? '',
      avatar: (j['avatar'] as String?) ?? '',
      bestDurationSec: (j['best_duration_sec'] as num).toInt(),
      bestDate: (j['best_date'] as String?) ?? '',
      durationText: (j['duration_text'] as String?) ?? '—',
      dateText: (j['date_text'] as String?) ?? '',
      paceText: j['pace_text'] as String?,
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

/// Участник маршрута (для экрана "Все участники маршрута").
class RouteParticipant {
  const RouteParticipant({
    required this.userId,
    required this.name,
    required this.surname,
    required this.avatar,
    required this.distanceKm,
    required this.durationText,
    this.heartRate,
  });

  final int userId;
  final String name;
  final String surname;
  final String avatar;
  final double distanceKm;
  final String durationText;
  final int? heartRate;

  String get fullName => '${name.trim()} ${surname.trim()}'.trim();

  factory RouteParticipant.fromJson(Map<String, dynamic> j) {
    return RouteParticipant(
      userId: (j['user_id'] as num).toInt(),
      name: (j['name'] as String?) ?? '',
      surname: (j['surname'] as String?) ?? '',
      avatar: (j['avatar'] as String?) ?? '',
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      durationText: (j['duration_text'] as String?) ?? '—',
      heartRate: (j['heart_rate'] as num?)?.toInt(),
    );
  }
}

/// Группа участников по дате (для экрана "Все участники маршрута").
class RouteParticipantsByDate {
  const RouteParticipantsByDate({
    required this.date,
    required this.dateLabel,
    required this.participants,
  });

  final String date;
  final String dateLabel;
  final List<RouteParticipant> participants;

  factory RouteParticipantsByDate.fromJson(Map<String, dynamic> j) {
    final participantsList = j['participants'] as List? ?? [];
    return RouteParticipantsByDate(
      date: (j['date'] as String?) ?? '',
      dateLabel: (j['date_label'] as String?) ?? '',
      participants: participantsList
          .map((e) => RouteParticipant.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
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

  /// Добавить готовый маршрут в избранное (по route_id).
  /// Используется при сохранении маршрута из чата/деталей.
  Future<SaveRouteResult> saveRouteToFavorites({
    required int userId,
    required int routeId,
    required String name,
    required String difficulty,
  }) async {
    final response = await _api.post(
      '/save_route_to_favorites.php',
      body: {
        'user_id': userId.toString(),
        'route_id': routeId.toString(),
        'name': name,
        'difficulty': difficulty,
      },
    );
    return SaveRouteResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  /// Список маршрутов пользователя (избранное — маршруты).
  Future<List<SavedRouteItem>> getMyRoutes(int userId) async {
    // ── Загружаем все страницы пакетами, чтобы сохранить старое поведение
    const pageLimit = 100;
    var offset = 0;
    var hasMore = true;
    final out = <SavedRouteItem>[];
    while (hasMore) {
      final page = await getMyRoutesPage(
        userId: userId,
        limit: pageLimit,
        offset: offset,
      );
      out.addAll(page.routes);
      hasMore = page.hasMore;
      offset = page.nextOffset;
      if (page.routes.isEmpty) {
        break;
      }
    }
    return out;
  }

  /// Пакет маршрутов пользователя (избранное — маршруты).
  /// [limit] и [offset] используются для постраничной загрузки.
  Future<RoutesPage> getMyRoutesPage({
    required int userId,
    required int limit,
    required int offset,
  }) async {
    final response = await _api.get(
      '/get_my_routes.php',
      queryParams: {
        'user_id': userId.toString(),
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
    final list = response['routes'];
    final routes = list is List
        ? list
            .map((e) => SavedRouteItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList()
        : <SavedRouteItem>[];
    final rawHasMore = response['has_more'];
    final hasMore = rawHasMore == true || rawHasMore == 1;
    final rawNextOffset = response['next_offset'];
    final nextOffset = rawNextOffset is num
        ? rawNextOffset.toInt()
        : (offset + routes.length);
    return RoutesPage(
      routes: routes,
      hasMore: hasMore,
      nextOffset: nextOffset,
    );
  }

  /// Обновление маршрута (название и сложность). Маршрут должен быть в избранном.
  Future<void> updateRoute({
    required int routeId,
    required int userId,
    required String name,
    required String difficulty,
  }) async {
    await _api.post('/update_route.php', body: {
      'route_id': routeId.toString(),
      'user_id': userId.toString(),
      'name': name,
      'difficulty': difficulty,
    });
  }

  /// Удаление маршрута пользователя (из избранного).
  Future<void> deleteRoute({
    required int routeId,
    required int userId,
  }) async {
    await _api.post('/delete_route.php', body: {
      'route_id': routeId.toString(),
      'user_id': userId.toString(),
    });
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
    if (raw is num) return raw.toInt();
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
    return list
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

  /// Лидерборд по маршруту (общие результаты).
  /// [filter] — "all" или "friends" (по умолчанию "all").
  /// [userId] — текущий пользователь (обязателен для фильтра "friends").
  Future<List<RouteLeaderboardItem>> getRouteLeaderboard({
    required int routeId,
    String filter = 'all',
    int userId = 0,
  }) async {
    final queryParams = <String, String>{
      'route_id': routeId.toString(),
      'filter': filter,
    };
    if (userId > 0) {
      queryParams['user_id'] = userId.toString();
    }
    final response = await _api.get(
      '/get_route_leaderboard.php',
      queryParams: queryParams,
    );
    final list = response['results'];
    if (list is! List) return [];
    return list
        .map((e) => RouteLeaderboardItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// Участники маршрута с группировкой по датам.
  /// [date] — опциональная дата фильтрации (формат YYYY-MM-DD).
  /// Если null, возвращаются данные за всё время.
  Future<List<RouteParticipantsByDate>> getRouteParticipants({
    required int routeId,
    String? date,
  }) async {
    final queryParams = <String, String>{
      'route_id': routeId.toString(),
    };
    if (date != null && date.isNotEmpty) {
      queryParams['date'] = date;
    }
    final response = await _api.get(
      '/get_route_participants.php',
      queryParams: queryParams,
    );
    final list = response['participants_by_date'];
    if (list is! List) return [];
    return list
        .map((e) => RouteParticipantsByDate.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
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
