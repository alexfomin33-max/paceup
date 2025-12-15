import '../../../../core/services/api_service.dart';

/// Модель метрик статистики
class StatsMetrics {
  final String activitiesCount;
  final String totalTime;
  final String distance;
  final String? avgHeartRate;
  final String? avgPace;
  final String? avgCadence;
  final String? relativeEffort;
  final String? elevationGain;
  final String? avgSpeed;

  StatsMetrics({
    required this.activitiesCount,
    required this.totalTime,
    required this.distance,
    this.avgHeartRate,
    this.avgPace,
    this.avgCadence,
    this.relativeEffort,
    this.elevationGain,
    this.avgSpeed,
  });

  factory StatsMetrics.fromJson(Map<String, dynamic> json) {
    return StatsMetrics(
      activitiesCount: json['activitiesCount'] ?? '0',
      totalTime: json['totalTime'] ?? '0 мин',
      distance: json['distance'] ?? '0 км',
      avgHeartRate: json['avgHeartRate'],
      avgPace: json['avgPace'],
      avgCadence: json['avgCadence'],
      relativeEffort: json['relativeEffort'],
      elevationGain: json['elevationGain'],
      avgSpeed: json['avgSpeed'],
    );
  }
}

/// Модель данных для графиков
class StatsCharts {
  final List<double> distance; // 12 месяцев в км
  final List<int> activeDays; // 12 месяцев
  final List<int> activeTime; // 12 месяцев в минутах

  StatsCharts({
    required this.distance,
    required this.activeDays,
    required this.activeTime,
  });

  factory StatsCharts.fromJson(Map<String, dynamic> json) {
    return StatsCharts(
      distance: (json['distance'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          List.filled(12, 0.0),
      activeDays: (json['activeDays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          List.filled(12, 0),
      activeTime: (json['activeTime'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          List.filled(12, 0),
    );
  }
}

/// Модель полной статистики
class StatsData {
  final StatsMetrics metrics;
  final StatsCharts charts;

  StatsData({
    required this.metrics,
    required this.charts,
  });

  factory StatsData.fromJson(Map<String, dynamic> json) {
    return StatsData(
      metrics: StatsMetrics.fromJson(json['metrics'] ?? {}),
      charts: StatsCharts.fromJson(json['charts'] ?? {}),
    );
  }
}

/// Сервис для загрузки статистики
class StatsService {
  final ApiService _api = ApiService();

  /// Загружает статистику для указанного пользователя
  ///
  /// [userId] - ID пользователя
  /// [period] - период: 'week', 'month', 'year'
  /// [sportType] - тип спорта: 'run', 'bike', 'swim' или null (все)
  /// [year] - год для графиков (по умолчанию текущий)
  Future<StatsData> getStats({
    required int userId,
    required String period,
    String? sportType,
    int? year,
  }) async {
    try {
      final response = await _api.post(
        '/get_stats.php',
        body: {
          'userId': userId,
          'period': period,
          if (sportType != null) 'sportType': sportType,
          if (year != null) 'year': year,
        },
      );

      if (response['success'] == true) {
        return StatsData.fromJson(response);
      } else {
        throw Exception(response['message'] ?? 'Ошибка загрузки статистики');
      }
    } catch (e) {
      // В случае ошибки возвращаем пустые данные
      return StatsData(
        metrics: StatsMetrics(
          activitiesCount: '—',
          totalTime: '—',
          distance: '—',
        ),
        charts: StatsCharts(
          distance: List.filled(12, 0.0),
          activeDays: List.filled(12, 0),
          activeTime: List.filled(12, 0),
        ),
      );
    }
  }
}
