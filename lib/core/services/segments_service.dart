// lib/core/services/segments_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Сервис для создания участков маршрута (segments) по тренировкам.
// ─────────────────────────────────────────────────────────────────────────────

import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 🔹 МОДЕЛИ ОТВЕТОВ API
// ─────────────────────────────────────────────────────────────────────────────

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
}
