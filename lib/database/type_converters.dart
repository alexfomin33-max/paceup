// ────────────────────────────────────────────────────────────────────────────
//  DRIFT TYPE CONVERTERS
//
//  Конвертеры для хранения сложных Dart объектов в SQLite
//  • Coord → JSON String
//  • List<Coord> → JSON String
//  • List<Equipment> → JSON String
//  • ActivityStats → JSON String
//  • Map<String, double> → JSON String
// ────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:drift/drift.dart';
import '../models/activity_lenta.dart';

// ────────────────────────── Coord Converter ──────────────────────────

/// Конвертер для одиночной координаты (Coord)
/// Хранит как JSON строку: {"lat":55.751244,"lng":37.618423}
class CoordConverter extends TypeConverter<Coord?, String> {
  const CoordConverter();

  @override
  Coord? fromSql(String fromDb) {
    if (fromDb.isEmpty) return null;
    try {
      final json = jsonDecode(fromDb) as Map<String, dynamic>;
      return Coord.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  String toSql(Coord? value) {
    if (value == null) return '';
    return jsonEncode({'lat': value.lat, 'lng': value.lng});
  }
}

// ────────────────────────── List<Coord> Converter ──────────────────────────

/// Конвертер для списка координат (маршрут)
/// Хранит как JSON массив: [{"lat":55.751244,"lng":37.618423},...]
class CoordListConverter extends TypeConverter<List<Coord>, String> {
  const CoordListConverter();

  @override
  List<Coord> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    try {
      final jsonList = jsonDecode(fromDb) as List;
      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((e) => Coord.fromJson(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  String toSql(List<Coord> value) {
    if (value.isEmpty) return '[]';
    return jsonEncode(
      value.map((c) => {'lat': c.lat, 'lng': c.lng}).toList(),
    );
  }
}

// ────────────────────────── List<Equipment> Converter ──────────────────────────

/// Конвертер для списка снаряжения
/// Хранит как JSON массив объектов
class EquipmentListConverter extends TypeConverter<List<Equipment>, String> {
  const EquipmentListConverter();

  @override
  List<Equipment> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    try {
      final jsonList = jsonDecode(fromDb) as List;
      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((e) => Equipment.fromJson(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  String toSql(List<Equipment> value) {
    if (value.isEmpty) return '[]';
    return jsonEncode(
      value.map((e) {
        return {
          'name': e.name,
          'mileage': e.mileage,
          'img': e.img,
          'main': e.main,
          'myraiting': e.myRating,
          'type': e.type,
        };
      }).toList(),
    );
  }
}

// ────────────────────────── ActivityStats Converter ──────────────────────────

/// Конвертер для статистики активности
/// Хранит все поля ActivityStats как JSON объект
class ActivityStatsConverter extends TypeConverter<ActivityStats?, String> {
  const ActivityStatsConverter();

  @override
  ActivityStats? fromSql(String fromDb) {
    if (fromDb.isEmpty) return null;
    try {
      final json = jsonDecode(fromDb) as Map<String, dynamic>;
      return ActivityStats.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  String toSql(ActivityStats? value) {
    if (value == null) return '';

    return jsonEncode({
      'distance': value.distance,
      'realDistance': value.realDistance,
      'avgSpeed': value.avgSpeed,
      'avgPace': value.avgPace,
      'minAltitude': value.minAltitude,
      'minAltitudeCoords': value.minAltitudeCoords == null
          ? null
          : {'lat': value.minAltitudeCoords!.lat, 'lng': value.minAltitudeCoords!.lng},
      'maxAltitude': value.maxAltitude,
      'maxAltitudeCoords': value.maxAltitudeCoords == null
          ? null
          : {'lat': value.maxAltitudeCoords!.lat, 'lng': value.maxAltitudeCoords!.lng},
      'cumulativeElevationGain': value.cumulativeElevationGain,
      'cumulativeElevationLoss': value.cumulativeElevationLoss,
      'startedAt': value.startedAt?.toIso8601String(),
      'startedAtCoords': value.startedAtCoords == null
          ? null
          : {'lat': value.startedAtCoords!.lat, 'lng': value.startedAtCoords!.lng},
      'finishedAt': value.finishedAt?.toIso8601String(),
      'finishedAtCoords': value.finishedAtCoords == null
          ? null
          : {'lat': value.finishedAtCoords!.lat, 'lng': value.finishedAtCoords!.lng},
      'duration': value.duration,
      'bounds': value.bounds.map((c) => {'lat': c.lat, 'lng': c.lng}).toList(),
      'avgHeartRate': value.avgHeartRate,
      'heartRatePerKm': value.heartRatePerKm,
      'pacePerKm': value.pacePerKm,
    });
  }
}

// ────────────────────────── List<String> Converter ──────────────────────────

/// Конвертер для списка строк (mediaImages, mediaVideos)
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    try {
      final jsonList = jsonDecode(fromDb) as List;
      return jsonList.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  String toSql(List<String> value) {
    return jsonEncode(value);
  }
}

