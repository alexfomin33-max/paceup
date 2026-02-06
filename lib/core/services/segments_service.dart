// lib/core/services/segments_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Сервис для создания участков маршрута (segments) по тренировкам.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:latlong2/latlong.dart' as ll;

import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 🔹 МОДЕЛИ ОТВЕТОВ API
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Участок с результатами текущего пользователя (Лента — Избранное — Участки).
// ─────────────────────────────────────────────────────────────────────────────

/// Лучшая попытка пользователя по участку (одна запись из user_segment_attempts).
class SegmentBestResult {
  const SegmentBestResult({
    required this.durationSec,
    required this.distanceKm,
    this.paceMinPerKm,
    this.avgHeartRate,
    this.avgCadence,
  });

  final int durationSec;
  final double distanceKm;
  final double? paceMinPerKm;
  final double? avgHeartRate;
  final double? avgCadence;

  static SegmentBestResult? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return SegmentBestResult(
      durationSec: (j['duration_sec'] as num?)?.toInt() ?? 0,
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      paceMinPerKm: (j['pace_min_per_km'] as num?)?.toDouble(),
      avgHeartRate: (j['avg_heart_rate'] as num?)?.toDouble(),
      avgCadence: (j['avg_cadence'] as num?)?.toDouble(),
    );
  }
}

/// Участок с лучшим результатом текущего пользователя и позицией в таблице.
class SegmentWithMyResult {
  const SegmentWithMyResult({
    required this.id,
    required this.name,
    required this.distanceKm,
    this.realDistanceKm,
    this.bestResult,
    this.position = 0,
    this.totalParticipants = 0,
  });

  final int id;
  final String name;
  final double distanceKm;
  final double? realDistanceKm;
  final SegmentBestResult? bestResult;
  final int position;
  final int totalParticipants;

  double get displayDistanceKm => realDistanceKm ?? distanceKm;

  static SegmentWithMyResult fromJson(Map<String, dynamic> j) {
    final best = j['best_result'];
    return SegmentWithMyResult(
      id: (j['id'] as num).toInt(),
      name: (j['name'] as String?) ?? '',
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      realDistanceKm: (j['real_distance_km'] as num?)?.toDouble(),
      bestResult: best is Map
          ? SegmentBestResult.fromJson(
              Map<String, dynamic>.from(best as Map),
            )
          : null,
      position: (j['position'] as num?)?.toInt() ?? 0,
      totalParticipants: (j['total_participants'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Два блока участков: мои и все (с результатами текущего пользователя).
class SegmentsWithMyResults {
  const SegmentsWithMyResults({
    required this.mySegments,
    required this.otherSegments,
  });

  final List<SegmentWithMyResult> mySegments;
  final List<SegmentWithMyResult> otherSegments;
}

// ─────────────────────────────────────────────────────────────────────────────
// Детали участка (экран описания участка).
// ─────────────────────────────────────────────────────────────────────────────
class SegmentDetail {
  const SegmentDetail({
    required this.id,
    required this.name,
    required this.distanceKm,
    this.realDistanceKm,
    required this.activityType,
    this.points = const [],
    this.personalBestDurationSec,
    this.personalBestText,
    this.personalBestActivityId,
    this.personalBestPaceMinPerKm,
    this.personalBestSpeedKmh,
    this.personalBestAvgHeartRate,
    this.personalBestElevationGainM,
    this.myAttemptsCount = 0,
  });

  final int id;
  final String name;
  final double distanceKm;
  final double? realDistanceKm;
  final String activityType;
  final List<ll.LatLng> points;
  final int? personalBestDurationSec;
  final String? personalBestText;
  final int? personalBestActivityId;
  final double? personalBestPaceMinPerKm;
  final double? personalBestSpeedKmh;
  final double? personalBestAvgHeartRate;
  final double? personalBestElevationGainM;
  final int myAttemptsCount;

  double get displayDistanceKm => realDistanceKm ?? distanceKm;

  factory SegmentDetail.fromJson(Map<String, dynamic> j) {
    final bestRaw = j['personal_best'];
    final best = bestRaw is Map
        ? Map<String, dynamic>.from(bestRaw as Map)
        : null;
    return SegmentDetail(
      id: (j['id'] as num).toInt(),
      name: (j['name'] as String?) ?? '',
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      realDistanceKm: (j['real_distance_km'] as num?)?.toDouble(),
      activityType: (j['activity_type'] as String?) ?? '',
      points: _parseSegmentPoints(
        j['segment_points'] ?? j['points'],
      ),
      personalBestDurationSec:
          (best?['duration_sec'] as num?)?.toInt(),
      personalBestText: best?['duration_text'] as String?,
      personalBestActivityId:
          (best?['activity_id'] as num?)?.toInt(),
      personalBestPaceMinPerKm:
          (best?['pace_min_per_km'] as num?)?.toDouble(),
      personalBestSpeedKmh:
          (best?['speed_kmh'] as num?)?.toDouble(),
      personalBestAvgHeartRate:
          (best?['avg_heart_rate'] as num?)?.toDouble(),
      personalBestElevationGainM:
          (best?['elevation_gain_m'] as num?)?.toDouble(),
      myAttemptsCount: (j['my_attempts_count'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Попытка пользователя по участку (Мои результаты).
// ─────────────────────────────────────────────────────────────────────────────
class SegmentAttemptItem {
  const SegmentAttemptItem({
    required this.activityId,
    required this.when,
    required this.durationText,
    required this.paceText,
    this.heartRate,
  });

  final int activityId;
  final String when;
  final String durationText;
  final String paceText;
  final int? heartRate;

  factory SegmentAttemptItem.fromJson(Map<String, dynamic> j) {
    return SegmentAttemptItem(
      activityId: (j['activity_id'] as num?)?.toInt() ?? 0,
      when: (j['when'] as String?) ?? '',
      durationText: (j['duration_text'] as String?) ?? '—',
      paceText: (j['pace_text'] as String?) ?? '—',
      heartRate: (j['heart_rate'] as num?)?.toInt(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Элемент лидерборда по участку (общие результаты).
// ─────────────────────────────────────────────────────────────────────────────
class SegmentLeaderboardItem {
  const SegmentLeaderboardItem({
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

  factory SegmentLeaderboardItem.fromJson(Map<String, dynamic> j) {
    return SegmentLeaderboardItem(
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

// ────────────────────────────────────────────────────────────────
// Парсер точек участка (поддержка разных форматов API)
// ────────────────────────────────────────────────────────────────
List<ll.LatLng> _parseSegmentPoints(dynamic v) {
  final out = <ll.LatLng>[];
  if (v is String) {
    try {
      final decoded = jsonDecode(v);
      return _parseSegmentPoints(decoded);
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
            ll.LatLng(
              double.tryParse(m.group(1)!) ?? 0,
              double.tryParse(m.group(2)!) ?? 0,
            ),
          );
        }
      } else if (e is Map<String, dynamic>) {
        out.add(
          ll.LatLng(
            (e['lat'] as num?)?.toDouble() ?? 0,
            (e['lng'] as num?)?.toDouble() ?? 0,
          ),
        );
      } else if (e is List && e.length >= 2) {
        out.add(
          ll.LatLng(
            (e[0] as num?)?.toDouble() ?? 0,
            (e[1] as num?)?.toDouble() ?? 0,
          ),
        );
      }
    }
  }
  return out;
}

/// Элемент участка из API (список «Избранное — Участки»).
/// Пока только название и расстояние; остальные параметры — позже.
/// Для отображения расстояния всегда используйте [displayDistanceKm]
/// (real_distance_km из БД, fallback на distance_km).
class ActivitySegmentItem {
  const ActivitySegmentItem({
    required this.id,
    required this.name,
    required this.distanceKm,
    this.realDistanceKm,
  });

  final int id;
  final String name;
  final double distanceKm;

  /// Реальная дистанция участка по треку, км (из БД).
  final double? realDistanceKm;

  /// Дистанция для отображения: всегда из real_distance_km, иначе distance_km.
  double get displayDistanceKm => realDistanceKm ?? distanceKm;

  factory ActivitySegmentItem.fromJson(Map<String, dynamic> j) {
    return ActivitySegmentItem(
      id: (j['id'] as num).toInt(),
      name: (j['name'] as String?) ?? '',
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      realDistanceKm: (j['real_distance_km'] as num?)?.toDouble(),
    );
  }
}

/// Участок тренировки для проверки дублей.
class ActivitySegmentDuplicateItem {
  const ActivitySegmentDuplicateItem({
    required this.id,
    required this.activityId,
    required this.startIndex,
    required this.endIndex,
    required this.startFraction,
    required this.endFraction,
  });

  final int id;
  final int activityId;
  final int startIndex;
  final int endIndex;
  final double startFraction;
  final double endFraction;

  factory ActivitySegmentDuplicateItem.fromJson(Map<String, dynamic> j) {
    return ActivitySegmentDuplicateItem(
      id: (j['id'] as num?)?.toInt() ?? 0,
      activityId: (j['activity_id'] as num?)?.toInt() ?? 0,
      startIndex: (j['start_index'] as num?)?.toInt() ?? 0,
      endIndex: (j['end_index'] as num?)?.toInt() ?? 0,
      startFraction: (j['start_fraction'] as num?)?.toDouble() ?? 0,
      endFraction: (j['end_fraction'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Участок для отрисовки на карте (BBOX).
class ActivitySegmentMapItem {
  const ActivitySegmentMapItem({
    required this.id,
    required this.name,
    required this.points,
    this.distanceKm,
    this.realDistanceKm,
  });

  final int id;
  final String name;
  final List<ll.LatLng> points;
  final double? distanceKm;
  final double? realDistanceKm;

  factory ActivitySegmentMapItem.fromJson(Map<String, dynamic> j) {
    final rawPoints = j['points'];
    final points = <ll.LatLng>[];
    if (rawPoints is List) {
      for (final item in rawPoints) {
        if (item is Map) {
          final lat = (item['lat'] as num?)?.toDouble();
          final lng = (item['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            points.add(ll.LatLng(lat, lng));
          }
        }
      }
    }
    return ActivitySegmentMapItem(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: (j['name'] as String?) ?? '',
      points: points,
      distanceKm: (j['distance_km'] as num?)?.toDouble(),
      realDistanceKm: (j['real_distance_km'] as num?)?.toDouble(),
    );
  }
}

/// Результат создания участка.
class SegmentCreateResult {
  const SegmentCreateResult({
    required this.segmentId,
    required this.activityId,
    required this.startIndex,
    required this.endIndex,
    required this.distanceKm,
    this.realDistanceKm,
    this.name,
  });

  /// ID созданного участка.
  final int segmentId;

  /// ID активности, из которой создан участок.
  final int activityId;

  /// Индекс начальной точки на треке.
  final int startIndex;

  /// Индекс конечной точки на треке.
  final int endIndex;

  /// Длина участка в километрах.
  final double distanceKm;

  /// Реальная дистанция участка по треку, км (из БД).
  final double? realDistanceKm;

  /// Название участка (может отсутствовать).
  final String? name;

  /// Парсинг результата из JSON.
  factory SegmentCreateResult.fromJson(Map<String, dynamic> j) {
    return SegmentCreateResult(
      segmentId: (j['segment_id'] as num?)?.toInt() ?? 0,
      activityId: (j['activity_id'] as num?)?.toInt() ?? 0,
      startIndex: (j['start_index'] as num?)?.toInt() ?? 0,
      endIndex: (j['end_index'] as num?)?.toInt() ?? 0,
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      realDistanceKm: (j['real_distance_km'] as num?)?.toDouble(),
      name: j['name'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🔹 СЕРВИС ДЛЯ РАБОТЫ С УЧАСТКАМИ
// ─────────────────────────────────────────────────────────────────────────────

/// Сервис создания участков маршрута.
class SegmentsService {
  SegmentsService._();

  static final SegmentsService _instance = SegmentsService._();

  factory SegmentsService() => _instance;

  // ────────────────────────────────────────────────────────────────
  // 🔹 API-КЛИЕНТ
  // ────────────────────────────────────────────────────────────────
  final ApiService _api = ApiService();

  // ────────────────────────────────────────────────────────────────
  // 🔹 СОЗДАНИЕ УЧАСТКА
  // ────────────────────────────────────────────────────────────────
  Future<SegmentCreateResult> createSegment({
    required int userId,
    required int activityId,
    required int startIndex,
    required int endIndex,
    required double startFraction,
    required double endFraction,
    String? name,
    double? realDistanceKm,
    List<ll.LatLng>? segmentPoints,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'activity_id': activityId,
      'start_index': startIndex,
      'end_index': endIndex,
      'start_fraction': startFraction,
      'end_fraction': endFraction,
    };
    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }
    if (realDistanceKm != null) {
      body['real_distance_km'] = realDistanceKm;
    }
    if (segmentPoints != null && segmentPoints.length >= 2) {
      body['segment_points'] = segmentPoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();
    }

    final response = await _api.post('/create_segment.php', body: body);

    return SegmentCreateResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  /// Список участков конкретной тренировки (для проверки дублей).
  Future<List<ActivitySegmentDuplicateItem>> getSegmentsForActivity({
    required int userId,
    required int activityId,
  }) async {
    final response = await _api.get(
      '/get_activity_segments.php',
      queryParams: {
        'user_id': userId.toString(),
        'activity_id': activityId.toString(),
      },
    );
    final list = response['segments'];
    if (list is! List) return [];
    return list
        .map((e) => ActivitySegmentDuplicateItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// Список участков пользователя (избранное — участки).
  Future<List<ActivitySegmentItem>> getMySegments(int userId) async {
    final response = await _api.get(
      '/get_activity_segments.php',
      queryParams: {'user_id': userId.toString()},
    );
    final list = response['segments'];
    if (list is! List) return [];
    return list
        .map((e) => ActivitySegmentItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// Участки с результатами текущего пользователя: «Мои участки» и «Все участки».
  /// my_segments — созданные текущим пользователем; other_segments — чужие,
  /// по которым у текущего есть попытки в user_segment_attempts.
  Future<SegmentsWithMyResults> getSegmentsWithMyResults(int userId) async {
    final response = await _api.get(
      '/get_segments_with_my_results.php',
      queryParams: {'user_id': userId.toString()},
    );
    final myList = response['my_segments'];
    final otherList = response['other_segments'];
    return SegmentsWithMyResults(
      mySegments: _parseSegmentWithMyResultList(myList),
      otherSegments: _parseSegmentWithMyResultList(otherList),
    );
  }

  static List<SegmentWithMyResult> _parseSegmentWithMyResultList(
    dynamic list,
  ) {
    if (list is! List) return [];
    return list
        .map((e) => SegmentWithMyResult.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 РЕДАКТИРОВАНИЕ НАЗВАНИЯ УЧАСТКА
  // ────────────────────────────────────────────────────────────────
  Future<void> updateSegmentName({
    required int segmentId,
    required int userId,
    required String name,
  }) async {
    // ── Нормализуем имя и проверяем, что оно не пустое
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('Название участка не может быть пустым');
    }
    // ── Отправляем запрос на сервер для сохранения нового имени
    await _api.post('/update_segment.php', body: {
      'segment_id': segmentId.toString(),
      'user_id': userId.toString(),
      'name': trimmedName,
    });
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ДЕТАЛИ УЧАСТКА
  // ────────────────────────────────────────────────────────────────
  Future<SegmentDetail> getSegmentDetail({
    required int segmentId,
    int userId = 0,
  }) async {
    final queryParams = <String, String>{
      'segment_id': segmentId.toString(),
    };
    if (userId > 0) {
      queryParams['user_id'] = userId.toString();
    }
    final response = await _api.get(
      '/get_segment.php',
      queryParams: queryParams,
    );
    final segmentMap = response['segment'];
    if (segmentMap is! Map<String, dynamic>) {
      throw StateError('get_segment: ожидался объект segment');
    }
    return SegmentDetail.fromJson(
      Map<String, dynamic>.from(segmentMap as Map),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 МОИ РЕЗУЛЬТАТЫ ПО УЧАСТКУ
  // ────────────────────────────────────────────────────────────────
  Future<List<SegmentAttemptItem>> getSegmentAttempts({
    required int segmentId,
    required int userId,
  }) async {
    final response = await _api.get(
      '/get_segment_attempts.php',
      queryParams: {
        'segment_id': segmentId.toString(),
        'user_id': userId.toString(),
      },
    );
    final list = response['attempts'];
    if (list is! List) return [];
    return list
        .map((e) => SegmentAttemptItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ЛИДЕРБОРД ПО УЧАСТКУ
  // ────────────────────────────────────────────────────────────────
  Future<List<SegmentLeaderboardItem>> getSegmentLeaderboard({
    required int segmentId,
    String filter = 'all',
    int userId = 0,
    String? gender,
  }) async {
    final queryParams = <String, String>{
      'segment_id': segmentId.toString(),
      'filter': filter,
    };
    if (userId > 0) {
      queryParams['user_id'] = userId.toString();
    }
    final normalizedGender = gender?.trim();
    if (normalizedGender != null && normalizedGender.isNotEmpty) {
      queryParams['gender'] = normalizedGender;
    }
    final response = await _api.get(
      '/get_segment_leaderboard.php',
      queryParams: queryParams,
    );
    final list = response['results'];
    if (list is! List) return [];
    return list
        .map((e) => SegmentLeaderboardItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// Участки в границах BBOX для карты.
  /// [activityType] — показывать только участки этого вида спорта (run, bike и т.д.).
  Future<List<ActivitySegmentMapItem>> getSegmentsByBbox({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    int limit = 200,
    String? activityType,
  }) async {
    final queryParams = <String, String>{
      'min_lat': minLat.toString(),
      'min_lng': minLng.toString(),
      'max_lat': maxLat.toString(),
      'max_lng': maxLng.toString(),
      'limit': limit.toString(),
    };
    if (activityType != null && activityType.trim().isNotEmpty) {
      queryParams['activity_type'] = activityType.trim();
    }
    final response = await _api.get(
      '/get_segments_by_bbox.php',
      queryParams: queryParams,
    );
    final list = response['segments'];
    if (list is! List) return [];
    return list
        .map((e) => ActivitySegmentMapItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .where((e) => e.points.length >= 2)
        .toList();
  }
}
