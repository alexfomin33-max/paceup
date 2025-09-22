import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Простая точка (широта/долгота)
class Coord {
  final double lat;
  final double lng;

  const Coord({required this.lat, required this.lng});

  factory Coord.fromJson(Map<String, dynamic> j) => Coord(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

/// Статистика активности (из поля "stats")
class ActivityStats {
  final double distance;
  final double realDistance;
  final double avgSpeed;
  final double avgPace;

  final double minAltitude;
  final Coord minAltitudeCoords;

  final double maxAltitude;
  final Coord maxAltitudeCoords;

  final double cumulativeElevationGain;
  final double cumulativeElevationLoss;

  final DateTime startedAt;
  final Coord startedAtCoords;

  final DateTime finishedAt;
  final Coord finishedAtCoords;

  final double duration;

  final List<Coord> bounds;

  final double? avgHeartRate;

  final Map<String, double>? heartRatePerKm;
  final Map<String, double>? pacePerKm;

  ActivityStats({
    required this.distance,
    required this.realDistance,
    required this.avgSpeed,
    required this.avgPace,
    required this.minAltitude,
    required this.minAltitudeCoords,
    required this.maxAltitude,
    required this.maxAltitudeCoords,
    required this.cumulativeElevationGain,
    required this.cumulativeElevationLoss,
    required this.startedAt,
    required this.startedAtCoords,
    required this.finishedAt,
    required this.finishedAtCoords,
    required this.duration,
    required this.bounds,
    this.avgHeartRate,
    this.heartRatePerKm,
    this.pacePerKm,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> j) {
    List<Coord> parseBounds(dynamic v) {
      if (v is List) {
        return v
            .whereType<Map<String, dynamic>>()
            .map((e) => Coord.fromJson(e))
            .toList();
      }
      return const <Coord>[];
    }

    Map<String, double>? toDoubleMap(dynamic v) {
      if (v is Map<String, dynamic>) {
        return v.map((k, val) => MapEntry(k, (val as num).toDouble()));
      }
      return null;
    }

    return ActivityStats(
      distance: (j['distance'] as num).toDouble(),
      realDistance: (j['realDistance'] as num).toDouble(),
      avgSpeed: (j['avgSpeed'] as num).toDouble(),
      avgPace: (j['avgPace'] as num).toDouble(),
      minAltitude: (j['minAltitude'] as num).toDouble(),
      minAltitudeCoords:
          Coord.fromJson(j['minAltitudeCoords'] as Map<String, dynamic>),
      maxAltitude: (j['maxAltitude'] as num).toDouble(),
      maxAltitudeCoords:
          Coord.fromJson(j['maxAltitudeCoords'] as Map<String, dynamic>),
      cumulativeElevationGain:
          (j['cumulativeElevationGain'] as num).toDouble(),
      cumulativeElevationLoss:
          (j['cumulativeElevationLoss'] as num).toDouble(),
      startedAt: DateTime.parse(j['startedAt'] as String),
      startedAtCoords:
          Coord.fromJson(j['startedAtCoords'] as Map<String, dynamic>),
      finishedAt: DateTime.parse(j['finishedAt'] as String),
      finishedAtCoords:
          Coord.fromJson(j['finishedAtCoords'] as Map<String, dynamic>),
      duration: (j['duration'] as num).toDouble(),
      bounds: parseBounds(j['bounds']),
      avgHeartRate: j['avgHeartRate'] == null
          ? null
          : (j['avgHeartRate'] as num).toDouble(),
      heartRatePerKm: toDoubleMap(j['heartRatePerKm']),
      pacePerKm: toDoubleMap(j['pacePerKm']),
    );
  }
}

/// Главная модель активности
class Activity {
  final int id;
  final String type;
  final DateTime dateStart;
  final DateTime dateEnd;

  // Новые поля
  final int lentaId;
  final int userId;
  final String userName;
  final String userAvatar;
  final int likes;
  final int comments;
  final int userGroup;
  final List<dynamic>? equpments;

  final String? paramsRaw;
  final String? pointsRaw;
  final ActivityStats? stats;
  final List<LatLng> route;

  Activity({
    required this.id,
    required this.type,
    required this.dateStart,
    required this.dateEnd,
    required this.lentaId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.likes,
    required this.comments,
    required this.userGroup,
    this.equpments,
    this.paramsRaw,
    this.pointsRaw,
    this.stats,
    this.route = const <LatLng>[],
  });

  factory Activity.fromApi(Map<String, dynamic> j) {
    // базовые
    final id = j['id'] as int;
    final type = j['type'] as String;
    final dateStart = DateTime.parse(j['date_start'] as String);
    final dateEnd = DateTime.parse(j['date_end'] as String);

    // новые
    final lentaId = j['lenta_id'] as int;
    final userId = j['user_id'] as int;
    final userName = j['user_name'] as String;
    final userAvatar = j['user_avatar'] as String;
    final likes = j['likes'] as int;
    final comments = j['comments'] as int;
    final userGroup = j['user_group'] as int;
    final equpments = j['equpments'] as List<dynamic>?;

    // stats (если есть)
    ActivityStats? stats;
    final params = j['params'];
    String? paramsRaw;
    if (params is String) {
      paramsRaw = params;
      try {
        final decoded = jsonDecode(params);
        if (decoded is List && decoded.isNotEmpty) {
          final first = decoded.first;
          if (first is Map && first['stats'] is Map) {
            stats =
                ActivityStats.fromJson(first['stats'] as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }

    // points / route
    String? pointsRaw;
    List<LatLng> route = const <LatLng>[];
    final points = j['points'];
    if (points is String) {
      pointsRaw = points;
      try {
        final decoded = jsonDecode(points);
        if (decoded is List) {
          route = decoded
              .whereType<Map<String, dynamic>>()
              .map((e) =>
                  LatLng((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble()))
              .toList();
        }
      } catch (_) {}
    }

    return Activity(
      id: id,
      type: type,
      dateStart: dateStart,
      dateEnd: dateEnd,
      lentaId: lentaId,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      likes: likes,
      comments: comments,
      userGroup: userGroup,
      equpments: equpments,
      paramsRaw: paramsRaw,
      pointsRaw: pointsRaw,
      stats: stats,
      route: route,
    );
  }
}
