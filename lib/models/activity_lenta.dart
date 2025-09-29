// Single-file rewrite of activity_lenta.dart
// - Robust parsing for server JSON (array or {"data":[...]})
// - Safe parsing of SQL-like datetime ("YYYY-MM-DD HH:mm:ss")
// - Handles params as an object; maps numbers to double
// - Parses points from ["LatLng(lat, lng)"] strings
// - Network helper with utf8 decode, timeout, error handling

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// ======== MODELS ========

class Activity {
  final int id;
  final String type;
  final DateTime? dateStart; // top-level date_start (SQL-like string)
  final DateTime? dateEnd;   // top-level date_end (SQL-like string)
  final int lentaId;
  final int userId;
  final String userName;
  final String userAvatar;
  final int likes;
  final int comments;
  final int userGroup;
  final List<Equipment> equipments; // note: server key is 'equpments'
  final ActivityStats? stats; // server key 'params'
  final List<Coord> points;
  final String postDateText;  // from "dates"
  final String postMediaUrl;  // from "media"
  final String postContent;   // from "content"
  final bool islike;

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
    required this.equipments,
    required this.stats,
    required this.points,
    this.postDateText = '',
    this.postMediaUrl = '',
    this.postContent = '',
    this.islike = false,
  });

  factory Activity.fromApi(Map<String, dynamic> j) {
    final paramsRaw = j['params'];

    return Activity(
      id: _asInt(j['id']),
      type: j['type']?.toString() ?? '',
      dateStart: _parseSqlDateTime(j['date_start']?.toString()),
      dateEnd: _parseSqlDateTime(j['date_end']?.toString()),
      lentaId: _asInt(j['lenta_id']),
      userId: _asInt(j['user_id']),
      userName: j['user_name']?.toString() ?? '',
      userAvatar: j['user_avatar']?.toString() ?? '',
      likes: _asInt(j['likes']),
      comments: _asInt(j['comments']),
      userGroup: _asInt(j['user_group']),
      equipments: _parseEquipments(j['equpments']),
      stats: paramsRaw is Map<String, dynamic>
          ? ActivityStats.fromJson(paramsRaw)
          : null,
      points: _parsePoints(j['points']),
      postDateText: j['dates']?.toString() ?? '',
      postMediaUrl: j['media']?.toString() ?? '',
      postContent: j['content']?.toString() ?? '',
      islike: _asBool(j['islike'] ?? j['isLiked'] ?? j['is_like'] ?? j['liked']),
    );
  }
}

class Equipment {
  final String name;
  final int mileage;
  final String img;
  final bool main;
  final double myRating;
  final String type;

  Equipment({
    required this.name,
    required this.mileage,
    required this.img,
    required this.main,
    required this.myRating,
    required this.type,
  });

  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
        name: j['name']?.toString() ?? '',
        mileage: _asInt(j['mileage']),
        img: j['img']?.toString() ?? '',
        main: j['main'].toString() == '1' || j['main'] == true,
        myRating: _asDouble(j['myraiting']),
        type: j['type']?.toString() ?? '',
      );
}

class Coord {
  final double lat;
  final double lng;

  const Coord({required this.lat, required this.lng});

  factory Coord.fromJson(Map<String, dynamic> j) => Coord(
        lat: _asDouble(j['lat']),
        lng: _asDouble(j['lng']),
      );
}

class ActivityStats {
  final double distance;
  final double realDistance;
  final double avgSpeed;
  final double avgPace;
  final double minAltitude;
  final Coord? minAltitudeCoords;
  final double maxAltitude;
  final Coord? maxAltitudeCoords;
  final double cumulativeElevationGain;
  final double cumulativeElevationLoss;
  final DateTime? startedAt; // ISO with timezone
  final Coord? startedAtCoords;
  final DateTime? finishedAt; // ISO with timezone
  final Coord? finishedAtCoords;
  final int duration; // seconds
  final List<Coord> bounds; // usually 2 points
  final double? avgHeartRate;
  final Map<String, double> heartRatePerKm;
  final Map<String, double> pacePerKm;

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
    required this.avgHeartRate,
    required this.heartRatePerKm,
    required this.pacePerKm,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> j) => ActivityStats(
        distance: _asDouble(j['distance']),
        realDistance: _asDouble(j['realDistance']),
        avgSpeed: _asDouble(j['avgSpeed']),
        avgPace: _asDouble(j['avgPace']),
        minAltitude: _asDouble(j['minAltitude']),
        minAltitudeCoords: j['minAltitudeCoords'] is Map<String, dynamic>
            ? Coord.fromJson(j['minAltitudeCoords'] as Map<String, dynamic>)
            : null,
        maxAltitude: _asDouble(j['maxAltitude']),
        maxAltitudeCoords: j['maxAltitudeCoords'] is Map<String, dynamic>
            ? Coord.fromJson(j['maxAltitudeCoords'] as Map<String, dynamic>)
            : null,
        cumulativeElevationGain: _asDouble(j['cumulativeElevationGain']),
        cumulativeElevationLoss: _asDouble(j['cumulativeElevationLoss']),
        startedAt: _parseIsoDateTime(j['startedAt']?.toString()),
        startedAtCoords: j['startedAtCoords'] is Map<String, dynamic>
            ? Coord.fromJson(j['startedAtCoords'] as Map<String, dynamic>)
            : null,
        finishedAt: _parseIsoDateTime(j['finishedAt']?.toString()),
        finishedAtCoords: j['finishedAtCoords'] is Map<String, dynamic>
            ? Coord.fromJson(j['finishedAtCoords'] as Map<String, dynamic>)
            : null,
        duration: _asInt(j['duration']),
        bounds: _parseCoordList(j['bounds']),
        avgHeartRate: j['avgHeartRate'] == null ? null : _asDouble(j['avgHeartRate']),
        heartRatePerKm: _parseNumMap(j['heartRatePerKm']),
        pacePerKm: _parseNumMap(j['pacePerKm']),
      );
}

// ======== NETWORK ========

/// Top-level helper instead of using widget.userId inside a State class
Future<List<Activity>> loadActivities({
  required int userId,
  int limit = 20,
  int page = 1,
  Uri? endpoint,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final uri = endpoint ?? Uri.parse('https://api.paceup.ru/activities_lenta.php');

  try {
    final res = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: json.encode({'userId': userId, 'limit': limit, 'page': page}),
        )
        .timeout(timeout);

    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}: ${res.body}', uri: uri);
    }

    final dynamic decoded = json.decode(utf8.decode(res.bodyBytes));

    final List rawList = decoded is Map<String, dynamic>
        ? (decoded['data'] as List? ?? const [])
        : (decoded as List);

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(Activity.fromApi)
        .toList();
  } on TimeoutException {
    rethrow; // let the caller decide; or wrap: throw Exception('Request timeout');
  } on SocketException catch (e) {
    throw Exception('Network error: ${e.message}');
  } on FormatException catch (e) {
    throw Exception('Bad JSON: ${e.message}');
  }
}

// ======== PARSING HELPERS ========

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

DateTime? _parseSqlDateTime(String? s) {
  // Accepts "YYYY-MM-DD HH:mm:ss" -> converts to ISO-local: "YYYY-MM-DDTHH:mm:ss"
  if (s == null || s.isEmpty) return null;
  final normalized = s.replaceFirst(' ', 'T');
  try {
    return DateTime.parse(normalized);
  } catch (_) {
    return null;
  }
}

DateTime? _parseIsoDateTime(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

List<Equipment> _parseEquipments(dynamic v) {
  if (v is List) {
    return v
        .whereType<Map<String, dynamic>>()
        .map(Equipment.fromJson)
        .toList();
  }
  return const [];
}

List<Coord> _parseCoordList(dynamic v) {
  final out = <Coord>[];
  if (v is List) {
    for (final e in v) {
      if (e is Map<String, dynamic>) {
        out.add(Coord.fromJson(e));
      } else if (e is List && e.length >= 2) {
        // fallback: [lat, lng]
        out.add(Coord(lat: _asDouble(e[0]), lng: _asDouble(e[1])));
      }
    }
  }
  return out;
}

List<Coord> _parsePoints(dynamic v) {
  final result = <Coord>[];
  if (v is List) {
    final regex = RegExp(r'LatLng\(\s*([\-0-9\.]+)\s*,\s*([\-0-9\.]+)\s*\)');
    for (final e in v) {
      if (e is String) {
        final m = regex.firstMatch(e);
        if (m != null) {
          result.add(Coord(
            lat: double.tryParse(m.group(1)!) ?? 0,
            lng: double.tryParse(m.group(2)!) ?? 0,
          ));
        }
      } else if (e is Map<String, dynamic>) {
        // Just in case server one day returns [{"lat":..,"lng":..}]
        result.add(Coord.fromJson(e));
      }
    }
  }
  return result;
}

Map<String, double> _parseNumMap(dynamic v) {
  final out = <String, double>{};
  if (v is Map) {
    v.forEach((key, value) {
      if (key == null) return;
      final k = key.toString();
      final d = _asDouble(value);
      out[k] = d;
    });
  }
  return out;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString().trim().toLowerCase();
  if (s == null || s.isEmpty) return false;
  return s == '1' || s == 'true' || s == 'yes' || s == 'on';
}

