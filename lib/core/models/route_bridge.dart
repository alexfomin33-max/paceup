import 'dart:io';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class RouteBridge {
  RouteBridge._();
  static final instance = RouteBridge._();

  static const _channel = MethodChannel('paceup/route');

  /// Поиск последней сессии за [days] дней, где реально доступен маршрут.
  /// На Android может показать системный консент.
  Future<List<LatLng>> getLatestRoutePoints({int days = 30}) async {
    if (!Platform.isAndroid) return const [];
    final res = await _channel.invokeMethod<List<dynamic>>(
      'getLatestRoute',
      <String, dynamic>{'days': days},
    );
    if (res == null) return const [];
    return res.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
    }).toList();
  }

  /// Старый метод по окну времени — оставлен на случай, если понадобится.
  Future<List<LatLng>> getRoutePoints({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!Platform.isAndroid) return const [];
    final res = await _channel.invokeMethod<List<dynamic>>(
      'getExerciseRoute',
      <String, dynamic>{
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      },
    );
    if (res == null) return const [];
    return res.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
    }).toList();
  }
}
