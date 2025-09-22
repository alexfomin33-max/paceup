// lib/models/activity.dart
//
// Готовая модель Activity с вложенными типами,
// парсингом stats/params/points и маршрутом route для карты.
//
// Использование:
//   import 'package:paceup/models/activity_lenta.dart';
//
//   final a = Activity.fromApi(jsonMap);
//   final pts = a.route; // List<LatLng> для Polyline(points: pts, ...)

import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Обычная точка широта/долгота как объект (удобно для stats.bounds и т.п.)
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

/// Статистика активности (то, что лежит в "stats").
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

  /// Длительность в секундах (как число с плавающей точкой, если приходит float)
  final double duration;

  /// bounds — массив из 2 точек (как отдаёт бек)
  final List<Coord> bounds;

  final double? avgHeartRate;

  /// {"km_1": 5.5, ...}
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
      avgHeartRate:
          j['avgHeartRate'] == null ? null : (j['avgHeartRate'] as num).toDouble(),
      heartRatePerKm: toDoubleMap(j['heartRatePerKm']),
      pacePerKm: toDoubleMap(j['pacePerKm']),
    );
  }

  Map<String, dynamic> toJson() => {
        'distance': distance,
        'realDistance': realDistance,
        'avgSpeed': avgSpeed,
        'avgPace': avgPace,
        'minAltitude': minAltitude,
        'minAltitudeCoords': minAltitudeCoords.toJson(),
        'maxAltitude': maxAltitude,
        'maxAltitudeCoords': maxAltitudeCoords.toJson(),
        'cumulativeElevationGain': cumulativeElevationGain,
        'cumulativeElevationLoss': cumulativeElevationLoss,
        'startedAt': startedAt.toIso8601String(),
        'startedAtCoords': startedAtCoords.toJson(),
        'finishedAt': finishedAt.toIso8601String(),
        'finishedAtCoords': finishedAtCoords.toJson(),
        'duration': duration,
        'bounds': bounds.map((e) => e.toJson()).toList(),
        if (avgHeartRate != null) 'avgHeartRate': avgHeartRate,
        if (heartRatePerKm != null) 'heartRatePerKm': heartRatePerKm,
        if (pacePerKm != null) 'pacePerKm': pacePerKm,
      };
}

/// ===== Утилиты парсинга маршрута (List<LatLng>) =====

List<LatLng> _parseLatLngStringList(dynamic v) {
  // Ждём List<String> вида ["LatLng(56.130535, 40.289521)", ...]
  if (v is! List) return const <LatLng>[];
  final reg = RegExp(
      r'LatLng\(\s*([+-]?\d+(?:\.\d+)?)\s*,\s*([+-]?\d+(?:\.\d+)?)\s*\)');
  final out = <LatLng>[];
  for (final item in v) {
    if (item is! String) continue;
    final m = reg.firstMatch(item);
    if (m != null) {
      final lat = double.parse(m.group(1)!);
      final lng = double.parse(m.group(2)!);
      out.add(LatLng(lat, lng));
    } else {
      // fallback: "56.13,40.28"
      final cleaned =
          item.replaceAll(RegExp(r'[^\d\.\,\-\+\s]'), '');
      final parts = cleaned.split(',');
      if (parts.length >= 2) {
        final lat = double.parse(parts[0].trim());
        final lng = double.parse(parts[1].trim());
        out.add(LatLng(lat, lng));
      }
    }
  }
  return out;
}

List<LatLng> _parseLatLngObjectList(dynamic v) {
  // Ждём List<Map> вида [{"lat":..,"lng":..}, ...]
  if (v is! List) return const <LatLng>[];
  final out = <LatLng>[];
  for (final p in v) {
    if (p is Map && p['lat'] != null && p['lng'] != null) {
      out.add(LatLng((p['lat'] as num).toDouble(),
          (p['lng'] as num).toDouble()));
    }
  }
  return out;
}

List<LatLng> _extractRouteFromPoints(dynamic points) {
  // points может быть:
  //  - JSON-строкой
  //  - List<String> "LatLng(...)" — сразу вернём
  //  - List<Map{geoPoints:[{lat,lng},...]}> — соберём все geoPoints
  if (points is String) {
    try {
      final decoded = jsonDecode(points);
      return _extractRouteFromPoints(decoded);
    } catch (_) {
      // Вытащим все "LatLng(...)" из строки
      final matches = RegExp(r'LatLng\([^)]+\)')
          .allMatches(points)
          .map((m) => m.group(0)!)
          .toList();
      return _parseLatLngStringList(matches);
    }
  }

  if (points is List) {
    // 1) Сразу массив строк LatLng(...)
    final asStrings = _parseLatLngStringList(points);
    if (asStrings.isNotEmpty) return asStrings;

    // 2) Массив сегментов с geoPoints
    final out = <LatLng>[];
    for (final seg in points) {
      if (seg is Map && seg['geoPoints'] is List) {
        out.addAll(_parseLatLngObjectList(seg['geoPoints']));
      } else if (seg is Map && seg['route'] is List) {
        out.addAll(_parseLatLngStringList(seg['route']));
      }
    }
    return out;
  }

  if (points is Map) {
    // Может быть {"route":[ "LatLng(...)", ... ]} или {"geoPoints":[{lat,lng},...]}
    if (points['route'] is List) return _parseLatLngStringList(points['route']);
    if (points['geoPoints'] is List) {
      return _parseLatLngObjectList(points['geoPoints']);
    }
  }

  return const <LatLng>[];
}

/// Главная модель «Активность».
class Activity {
  final int id;
  final String type;

  /// Даты в удобном формате Dart
  final DateTime dateStart;
  final DateTime dateEnd;

  /// Сырая строка JSON из поля `params` (если нужно хранить как есть)
  final String? paramsRaw;

  /// Сырая строка JSON из поля `points` (если приходит/нужна)
  final String? pointsRaw;

  /// Подробная статистика из `params` -> ... -> `stats`
  final ActivityStats? stats;

  /// Готовый маршрут для карты (flutter_map: Polyline(points: route, ...))
  final List<LatLng> route;

  Activity({
    required this.id,
    required this.type,
    required this.dateStart,
    required this.dateEnd,
    this.paramsRaw,
    this.pointsRaw,
    this.stats,
    this.route = const <LatLng>[],
  });

  /// Если у тебя уже есть объект вида {"stats": {...}} (как в tracksJson)
  factory Activity.fromJson(Map<String, dynamic> j) {
    final statsMap = j['stats'] as Map<String, dynamic>;
    return Activity(
      id: -1,
      type: 'unknown',
      dateStart: DateTime.parse(statsMap['startedAt'] as String),
      dateEnd: DateTime.parse(statsMap['finishedAt'] as String),
      paramsRaw: null,
      pointsRaw: null,
      stats: ActivityStats.fromJson(statsMap),
      route: const <LatLng>[],
    );
  }

  /// Основной вариант под твой бек:
  /// { id, type, date_start, date_end, params, points? / route? / route_coords? }
  factory Activity.fromApi(Map<String, dynamic> j) {
    final id = (j['id'] as num).toInt();
    final type = j['type'] as String;
    final dateStart = DateTime.parse(j['date_start'] as String);
    final dateEnd = DateTime.parse(j['date_end'] as String);

    // ---- params ----
    final params = j['params'];
    String? paramsRaw;
    ActivityStats? stats;
    dynamic decodedParams;

    if (params is String) {
      paramsRaw = params;
      try {
        decodedParams = jsonDecode(params);
      } catch (_) {}
    } else if (params is Map || params is List) {
      decodedParams = params;
      paramsRaw = jsonEncode(params);
    }

    if (decodedParams is List && decodedParams.isNotEmpty) {
      final first = decodedParams.first;
      if (first is Map && first['stats'] is Map) {
        stats =
            ActivityStats.fromJson(first['stats'] as Map<String, dynamic>);
      }
    } else if (decodedParams is Map && decodedParams['stats'] is Map) {
      stats = ActivityStats.fromJson(
          decodedParams['stats'] as Map<String, dynamic>);
    }

    // ---- route (из разных возможных полей) ----
    List<LatLng> route = const <LatLng>[];
    if (j['route'] != null) {
      route = _parseLatLngStringList(j['route']);
    } else if (j['route_coords'] != null) {
      route = _parseLatLngStringList(j['route_coords']);
    } else if (j['points'] != null) {
      route = _extractRouteFromPoints(j['points']);
    } else if (decodedParams != null) {
      // на случай, если маршрут положили внутрь params
      if (decodedParams is Map && decodedParams['route'] is List) {
        route = _parseLatLngStringList(decodedParams['route']);
      } else if (decodedParams is List) {
        route = _extractRouteFromPoints(decodedParams);
      }
    }

    // ---- pointsRaw (если нужно хранить сырьё) ----
    String? pointsRaw;
    final points = j['points'];
    if (points is String) {
      pointsRaw = points;
    } else if (points != null) {
      pointsRaw = jsonEncode(points);
    }

    return Activity(
      id: id,
      type: type,
      dateStart: dateStart,
      dateEnd: dateEnd,
      paramsRaw: paramsRaw,
      pointsRaw: pointsRaw,
      stats: stats,
      route: route,
    );
  }
}
