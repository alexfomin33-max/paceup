import 'package:latlong2/latlong.dart' as latlong;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// ──────────── Сервис подстройки камеры и расчетов расстояния ────────────
/// Чистые функции без зависимости от BuildContext, чтобы легче тестировать.
class MapFitService {
  MapFitService._();

  /// Автоматическая подстройка границ под список маркеров.
  static Future<void> fitBoundsToMarkers(
    MapboxMap? mapboxMap,
    List<Map<String, dynamic>> markers,
  ) async {
    if (markers.isEmpty || mapboxMap == null) return;

    final points = markers
        .map((m) => m['point'] as latlong.LatLng?)
        .whereType<latlong.LatLng>()
        .toList();

    if (points.isEmpty) return;

    if (points.length == 1) {
      await mapboxMap.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              points.first.longitude,
              points.first.latitude,
            ),
          ),
          zoom: 12.0,
        ),
        MapAnimationOptions(duration: 500, startDelay: 0),
      );
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    try {
      final camera = await mapboxMap.cameraForCoordinateBounds(
        CoordinateBounds(
          southwest: Point(coordinates: Position(minLng, minLat)),
          northeast: Point(coordinates: Position(maxLng, maxLat)),
          infiniteBounds: false,
        ),
        MbxEdgeInsets(left: 30, right: 30, top: 160, bottom: 130),
        null,
        null,
        null,
        null,
      );
      await mapboxMap.setCamera(camera);
    } catch (error) {
      // Ошибка канала не критична — карта останется на месте.
    }
  }

  /// Быстрый расчет расстояния на плоскости (используется для поиска ближайшего маркера).
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = (lat1 - lat2).abs();
    final dLng = (lng1 - lng2).abs();
    return dLat * dLat + dLng * dLng;
  }
}

