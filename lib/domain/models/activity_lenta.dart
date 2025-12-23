// Single-file rewrite of activity_lenta.dart
// - Robust parsing for server JSON (array or {"data":[...]})
// - Safe parsing of SQL-like datetime ("YYYY-MM-DD HH:mm:ss")
// - Handles params as an object; maps numbers to double
// - Parses points from ["LatLng(lat, lng)"] strings
// - Network helper with utf8 decode, timeout, error handling

import '../../core/services/api_service.dart';

// ======== MODELS ========

class Activity {
  final int id;
  final String type;
  final DateTime? dateStart; // top-level date_start (SQL-like string)
  final DateTime? dateEnd; // top-level date_end (SQL-like string)
  final int lentaId;
  final DateTime? lentaDate; // ✅ Дата из таблицы lenta для единой сортировки
  final int userId;
  final String userName;
  final String userAvatar;
  final int likes;
  final int comments;
  final int userGroup;
  final List<Equipment> equipments; // note: server key is 'equpments'
  final ActivityStats? stats; // server key 'params'
  final List<Coord> points;
  final String postDateText; // from "dates"
  final String postMediaUrl; // from "media"
  final String postContent; // from "content"
  final bool islike;
  final List<String> mediaImages; // полные URL картинок
  final List<String> mediaVideos; // полные URL видео

  Activity({
    required this.id,
    required this.type,
    required this.dateStart,
    required this.dateEnd,
    required this.lentaId,
    this.lentaDate,
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
    this.mediaImages = const [],
    this.mediaVideos = const [],
  });

  factory Activity.fromApi(Map<String, dynamic> j) {
    final paramsRaw = j['params'];

    // --- разбор media ---
    List<String> mediaImages = const [];
    List<String> mediaVideos = const [];

    final media = j['media'];
    if (media is Map<String, dynamic>) {
      final imgs = media['images'];
      final vids = media['videos'];
      if (imgs is List) {
        mediaImages = imgs.whereType<String>().toList(growable: false);
      }
      if (vids is List) {
        mediaVideos = vids.whereType<String>().toList(growable: false);
      }
    }

    return Activity(
      id: _asInt(j['id']),
      type: j['type']?.toString() ?? '',
      dateStart: _parseSqlDateTime(j['date_start']?.toString()),
      dateEnd: _parseSqlDateTime(j['date_end']?.toString()),
      lentaId: _asInt(j['lenta_id']),
      lentaDate: _parseSqlDateTime(
        j['lenta_date']?.toString(),
      ), // ✅ Дата из таблицы lenta
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
      islike: _asBool(
        j['islike'] ?? j['isLiked'] ?? j['is_like'] ?? j['liked'],
      ),
      mediaImages: mediaImages,
      mediaVideos: mediaVideos,
    );
  }

  // ────────────────────────── Copy With ──────────────────────────

  /// Создаёт копию с обновлённым счётчиком лайков
  Activity copyWithLikes(int newLikes) {
    return Activity(
      id: id,
      type: type,
      dateStart: dateStart,
      dateEnd: dateEnd,
      lentaId: lentaId,
      lentaDate: lentaDate,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      likes: newLikes,
      comments: comments,
      userGroup: userGroup,
      equipments: equipments,
      stats: stats,
      points: points,
      postDateText: postDateText,
      postMediaUrl: postMediaUrl,
      postContent: postContent,
      islike: islike,
      mediaImages: mediaImages,
      mediaVideos: mediaVideos,
    );
  }

  /// Создаёт копию с обновлённым счётчиком комментариев
  Activity copyWithComments(int newComments) {
    return Activity(
      id: id,
      type: type,
      dateStart: dateStart,
      dateEnd: dateEnd,
      lentaId: lentaId,
      lentaDate: lentaDate,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      likes: likes,
      comments: newComments,
      userGroup: userGroup,
      equipments: equipments,
      stats: stats,
      points: points,
      postDateText: postDateText,
      postMediaUrl: postMediaUrl,
      postContent: postContent,
      islike: islike,
      mediaImages: mediaImages,
      mediaVideos: mediaVideos,
    );
  }

  /// Создаёт копию с обновлёнными медиафайлами
  Activity copyWithMedia({List<String>? images, List<String>? videos}) {
    return Activity(
      id: id,
      type: type,
      dateStart: dateStart,
      dateEnd: dateEnd,
      lentaId: lentaId,
      lentaDate: lentaDate,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      likes: likes,
      comments: comments,
      userGroup: userGroup,
      equipments: equipments,
      stats: stats,
      points: points,
      postDateText: postDateText,
      postMediaUrl: postMediaUrl,
      postContent: postContent,
      islike: islike,
      mediaImages: images ?? mediaImages,
      mediaVideos: videos ?? mediaVideos,
    );
  }

  /// Создаёт копию с обновлённой экипировкой
  Activity copyWithEquipments(List<Equipment> newEquipments) {
    return Activity(
      id: id,
      type: type,
      dateStart: dateStart,
      dateEnd: dateEnd,
      lentaId: lentaId,
      lentaDate: lentaDate,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      likes: likes,
      comments: comments,
      userGroup: userGroup,
      equipments: newEquipments,
      stats: stats,
      points: points,
      postDateText: postDateText,
      postMediaUrl: postMediaUrl,
      postContent: postContent,
      islike: islike,
      mediaImages: mediaImages,
      mediaVideos: mediaVideos,
    );
  }
}

class Equipment {
  final String name;
  final String brand; // название бренда из БД
  final int mileage;
  final String img;
  final bool main;
  final double myRating;
  final String type;
  final int? equipUserId; // ID записи из таблицы equip_user (для замены эквипа)

  Equipment({
    required this.name,
    this.brand = '', // по умолчанию пустая строка
    required this.mileage,
    required this.img,
    required this.main,
    required this.myRating,
    required this.type,
    this.equipUserId,
  });

  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
    name: j['name']?.toString() ?? '',
    brand: j['brand']?.toString() ?? '', // парсим brand из JSON
    mileage: _asInt(j['mileage']),
    img: j['img']?.toString() ?? '',
    main: j['main'].toString() == '1' || j['main'] == true,
    myRating: _asDouble(j['myraiting']),
    type: j['type']?.toString() ?? '',
    equipUserId: j['equip_user_id'] != null ? _asInt(j['equip_user_id']) : null,
  );
}

class Coord {
  final double lat;
  final double lng;

  const Coord({required this.lat, required this.lng});

  factory Coord.fromJson(Map<String, dynamic> j) =>
      Coord(lat: _asDouble(j['lat']), lng: _asDouble(j['lng']));
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
  final double? avgCadence; // шагов в минуту (spm)
  final double? calories; // калории (ккал)
  final int? totalSteps; // общее количество шагов
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
    this.avgCadence,
    this.calories,
    this.totalSteps,
    required this.heartRatePerKm,
    required this.pacePerKm,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> j) {
    final stats = ActivityStats(
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
      avgHeartRate: j['avgHeartRate'] == null
          ? null
          : _asDouble(j['avgHeartRate']),
      avgCadence: j['avgCadence'] == null ? null : _asDouble(j['avgCadence']),
      calories: j['calories'] == null ? null : _asDouble(j['calories']),
      totalSteps: j['totalSteps'] == null ? null : _asInt(j['totalSteps']),
      heartRatePerKm: _parseNumMap(j['heartRatePerKm']),
      pacePerKm: _parseNumMap(j['pacePerKm']),
    );

    return stats;
  }

  // ────────────────────────────────────────────────────────────────
  // Вспомогательные методы для проверки наличия данных о сегментах
  // ────────────────────────────────────────────────────────────────

  /// Проверяет, есть ли данные о сегментах (отрезках по километрам)
  bool hasSplitsData() {
    return pacePerKm.isNotEmpty || heartRatePerKm.isNotEmpty;
  }

  /// Возвращает количество сегментов (километров) с данными
  int get splitsCount {
    final allKeys = <String>{...pacePerKm.keys, ...heartRatePerKm.keys};
    return allKeys.length;
  }

  /// Проверяет, есть ли данные о темпе для сегментов
  bool hasPaceSplits() => pacePerKm.isNotEmpty;

  /// Проверяет, есть ли данные о пульсе для сегментов
  bool hasHeartRateSplits() => heartRatePerKm.isNotEmpty;
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
  final api = ApiService();

  try {
    final data = await api.post(
      '/activities_lenta.php',
      body: {
        'userId': '$userId', // 🔹 PHP ожидает строки
        'limit': '$limit', // 🔹 PHP ожидает строки
        'page': '$page', // 🔹 PHP ожидает строки
      },
      timeout: timeout,
    );

    final List rawList = data['data'] as List? ?? const [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(Activity.fromApi)
        .toList();
  } on ApiException {
    rethrow;
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
  // ✅ Универсальный парсер: поддерживает оба формата
  // - "YYYY-MM-DD HH:mm:ss" (SQL формат)
  // - "YYYY-MM-DDTHH:mm:ss" или "YYYY-MM-DDTHH:mm:ss.000" (ISO формат)
  if (s == null || s.isEmpty) return null;

  // Убираем лишние пробелы и нормализуем строку
  String normalized = s.trim();

  // Убираем миллисекунды если есть (формат .000 или .123456)
  if (normalized.contains('.')) {
    final dotIndex = normalized.indexOf('.');
    // Проверяем, что после точки идут цифры (миллисекунды)
    if (dotIndex > 0 && dotIndex < normalized.length - 1) {
      // Находим конец миллисекунд (до пробела, 'Z', '+' или конца строки)
      final afterDot = normalized.substring(dotIndex + 1);
      final endIndex = afterDot.indexOf(RegExp(r'[^0-9]'));
      if (endIndex > 0) {
        // Убираем миллисекунды
        normalized =
            normalized.substring(0, dotIndex) +
            normalized.substring(dotIndex + 1 + endIndex);
      } else {
        // Миллисекунды в конце строки - просто убираем их
        normalized = normalized.substring(0, dotIndex);
      }
    }
  }

  try {
    // Если уже содержит 'T' - это ISO формат
    if (normalized.contains('T')) {
      return DateTime.parse(normalized);
    }
    // Иначе это SQL формат - заменяем пробел на 'T'
    final withT = normalized.replaceFirst(' ', 'T');
    return DateTime.parse(withT);
  } catch (e) {
    // Если парсинг не удался, пробуем ручной парсинг
    try {
      // Формат: "YYYY-MM-DD HH:mm:ss" или "YYYY-MM-DDTHH:mm:ss"
      final parts = normalized.split(RegExp(r'[T ]'));
      if (parts.length >= 2) {
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        if (dateParts.length == 3 && timeParts.length >= 2) {
          return DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
            timeParts.length >= 3 ? int.parse(timeParts[2]) : 0,
          );
        }
      }
    } catch (_) {
      return null;
    }
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
    return v.whereType<Map<String, dynamic>>().map(Equipment.fromJson).toList();
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
          result.add(
            Coord(
              lat: double.tryParse(m.group(1)!) ?? 0,
              lng: double.tryParse(m.group(2)!) ?? 0,
            ),
          );
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
