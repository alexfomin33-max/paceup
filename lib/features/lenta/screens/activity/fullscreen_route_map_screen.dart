// lib/features/lenta/screens/activity/fullscreen_route_map_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../map/services/marker_assets.dart';

/// Полноэкранный экран с картой маршрута тренировки.
/// Показывает интерактивную карту с треком, позволяет масштабировать и перемещаться.
class FullscreenRouteMapScreen extends StatefulWidget {
  final List<ll.LatLng> points;
  final String? activityType;
  final Map<String, double> elevationPerKm;

  const FullscreenRouteMapScreen({
    super.key,
    required this.points,
    this.activityType,
    this.elevationPerKm = const {},
  });

  @override
  State<FullscreenRouteMapScreen> createState() =>
      _FullscreenRouteMapScreenState();
}

class _FullscreenRouteMapScreenState extends State<FullscreenRouteMapScreen> {
  PolylineAnnotationManager? _polylineAnnotationManager;
  PointAnnotationManager? _pointAnnotationManager;
  // ignore: unused_field — храним для возможного обновления/удаления маркеров
  PointAnnotation? _routeStartAnnotation;
  PointAnnotation? _routeEndAnnotation;
  Uint8List? _routeStartMarkerImage;
  Uint8List? _routeEndMarkerImage;
  Uint8List? _arrowImage;
  List<PointAnnotation> _arrowAnnotations = [];
  // Контроллер карты для возможного управления камерой в будущем
  // ignore: unused_field
  MapboxMap? _mapboxMap;
  final flutter_map.MapController _flutterMapController =
      flutter_map.MapController();
  final ll.Distance _distance = const ll.Distance();
  List<double> _prefixDistancesM = [];
  // ────────────────────────────────────────────────────────────────
  // 🔹 ФЛАГ ГОТОВНОСТИ: скрываем карту до полной инициализации маршрута
  // ────────────────────────────────────────────────────────────────
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _prefixDistancesM = _buildPrefixDistances(widget.points);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: const Center(child: Text('Нет точек маршрута')),
      );
    }

    final center = _centerFromPoints(widget.points);
    final bounds = _boundsFromPoints(widget.points);

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: Stack(
        children: [
          // Карта на весь экран
          _buildMap(center, bounds),
          // Кнопка назад с круглым фоном в верхнем левом углу
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.scrim40,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.back,
                      color: AppColors.surface,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(ll.LatLng center, LatLngBounds bounds) {
    // Используем flutter_map для macOS
    if (Platform.isMacOS) {
      return flutter_map.FlutterMap(
        mapController: _flutterMapController,
        options: flutter_map.MapOptions(
          initialCenter: center,
          initialZoom: 12.0,
          minZoom: 3.0,
          maxZoom: 18.0,
        ),
        children: [
          flutter_map.TileLayer(
            urlTemplate: AppConfig.mapTilesUrl.replaceAll(
              '{apiKey}',
              AppConfig.mapTilerApiKey,
            ),
            userAgentPackageName: 'com.example.paceup',
          ),
          flutter_map.PolylineLayer(
            polylines: _buildFlutterMapPolylines(),
          ),
          flutter_map.MarkerLayer(
            markers: _buildFlutterMapArrowMarkers(),
          ),
          flutter_map.MarkerLayer(
            markers: _buildFlutterMapRouteMarkers(),
          ),
        ],
      );
    }

    // Используем Mapbox для Android/iOS
    return Stack(
      children: [
        // ────────────────────────────────────────────────────────────────
        // 🔹 ФОН: показываем до готовности карты (цвет фона экрана)
        // ────────────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.getBackgroundColor(context),
        ),
        // ────────────────────────────────────────────────────────────────
        // 🔹 КАРТА: появляется с fade-эффектом после полной инициализации
        // ────────────────────────────────────────────────────────────────
        AnimatedOpacity(
          opacity: _isMapReady ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: MapWidget(
            key: ValueKey('fullscreen_route_${widget.points.length}'),
            onMapCreated: (MapboxMap mapboxMap) async {
              _mapboxMap = mapboxMap;

              // ────────────────────────── Отключаем масштабную линейку ──────────────────────────
              try {
                await mapboxMap.scaleBar.updateSettings(
                  ScaleBarSettings(enabled: false),
                );
              } catch (e) {
                // Если метод недоступен, игнорируем ошибку
              }

              // Ждём полной инициализации карты перед созданием аннотаций
              // Увеличиваем задержку для гарантии готовности каналов Mapbox
              await Future.delayed(const Duration(milliseconds: 300));

              // Создаем менеджер полилиний с обработкой ошибок
              try {
                _polylineAnnotationManager = await mapboxMap.annotations
                    .createPolylineAnnotationManager();

                await _drawTrackPolylines();
              } catch (annotationError) {
                // Игнорируем ошибки создания полилинии
              }

              try {
                _pointAnnotationManager =
                    await mapboxMap.annotations.createPointAnnotationManager();
                await _drawRouteStartEndMarkers();
                await _drawArrowMarkers();
              } catch (_) {}

              // Подстраиваем камеру под границы с обработкой ошибок канала
              try {
                final camera = await mapboxMap.cameraForCoordinateBounds(
                  CoordinateBounds(
                    southwest: Point(
                      coordinates: Position(
                        bounds.southwest.longitude,
                        bounds.southwest.latitude,
                      ),
                    ),
                    northeast: Point(
                      coordinates: Position(
                        bounds.northeast.longitude,
                        bounds.northeast.latitude,
                      ),
                    ),
                    infiniteBounds: false,
                  ),
                  MbxEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
                  null,
                  null,
                  null,
                  null,
                );
                await mapboxMap.setCamera(camera);
              } catch (cameraError) {
                // Если канал еще не готов, продолжаем работу
                // Карта отобразится с начальной позицией из cameraOptions
              }

              // ────────────────────────────────────────────────────────────────
              // 🔹 ПОКАЗЫВАЕМ КАРТУ: устанавливаем флаг готовности после
              // полной инициализации маршрута и камеры
              // ────────────────────────────────────────────────────────────────
              if (mounted) {
                setState(() {
                  _isMapReady = true;
                });
              }
            },
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(center.longitude, center.latitude),
              ),
              zoom: 12,
            ),
            styleUri: MapboxStyles.MAPBOX_STREETS,
          ),
        ),
      ],
    );
  }

  // ────────────────────── ВНУТРЕННИЕ ХЕЛПЕРЫ ──────────────────────

  // ────────────────────────────────────────────────────────────────
  // 🔹 ОТРИСОВКА ТРЕКА: ОКРАСКА ПО ВЫСОТЕ
  // ────────────────────────────────────────────────────────────────
  Future<void> _drawTrackPolylines() async {
    if (_polylineAnnotationManager == null || widget.points.length < 2) {
      return;
    }

    await _polylineAnnotationManager!.deleteAll();

    // ──────────────────────────────────────────────────────────────
    // 🔹 ТРЕК ОДИН ЦВЕТ (СИНИЙ) — БЕЗ ОКРАСКИ ПО ВЫСОТЕ
    // ──────────────────────────────────────────────────────────────
    final coordinates = widget.points
        .map((p) => Position(p.longitude, p.latitude))
        .toList();
    await _polylineAnnotationManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: coordinates),
        lineColor: AppColors.brandPrimary.toARGB32(),
        lineWidth: 3.0,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 FLUTTER_MAP: ПОЛИЛИНИИ
  // ────────────────────────────────────────────────────────────────
  List<flutter_map.Polyline> _buildFlutterMapPolylines() {
    // ──────────────────────────────────────────────────────────────
    // 🔹 ТРЕК ОДИН ЦВЕТ (СИНИЙ) — БЕЗ ОКРАСКИ ПО ВЫСОТЕ
    // ──────────────────────────────────────────────────────────────
    return [
      flutter_map.Polyline(
        points: widget.points,
        strokeWidth: 3.0,
        color: AppColors.brandPrimary,
      ),
    ];
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 FLUTTER_MAP: МАРКЕРЫ СТАРТА И ФИНИША МАРШРУТА
  // ────────────────────────────────────────────────────────────────
  List<flutter_map.Marker> _buildFlutterMapRouteMarkers() {
    if (widget.points.length < 2) return [];
    return [
      _routeMarker(
        widget.points.first,
        'С',
        AppColors.success,
      ),
      _routeMarker(
        widget.points.last,
        'Ф',
        AppColors.error,
      ),
    ];
  }

  flutter_map.Marker _routeMarker(
    ll.LatLng point,
    String label,
    Color color,
  ) {
    return flutter_map.Marker(
      point: point,
      width: AppSpacing.xl,
      height: AppSpacing.xl,
      child: Container(
        width: AppSpacing.xl,
        height: AppSpacing.xl,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.h14w6.copyWith(
            color: AppColors.surface,
          ),
        ),
      ),
    );
  }

  Future<void> _ensureRouteMarkerImages() async {
    if (_routeStartMarkerImage == null) {
      _routeStartMarkerImage = await MarkerAssets.createMarkerImage(
        AppColors.success,
        'С',
      );
    }
    if (_routeEndMarkerImage == null) {
      _routeEndMarkerImage = await MarkerAssets.createMarkerImage(
        AppColors.error,
        'Ф',
      );
    }
  }

  /// Отрисовка точек старта и финиша маршрута на Mapbox.
  Future<void> _drawRouteStartEndMarkers() async {
    if (_pointAnnotationManager == null || widget.points.length < 2) return;
    await _ensureRouteMarkerImages();
    if (_routeStartMarkerImage == null || _routeEndMarkerImage == null) return;

    final first = widget.points.first;
    final last = widget.points.last;

    _routeStartAnnotation = await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(first.longitude, first.latitude),
        ),
        image: _routeStartMarkerImage!,
        iconSize: 1.0,
      ),
    );
    _routeEndAnnotation = await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(last.longitude, last.latitude),
        ),
        image: _routeEndMarkerImage!,
        iconSize: 1.0,
      ),
    );
  }

  List<({ll.LatLng point, double bearingDeg})> _computeArrowPositions() {
    if (widget.points.length < 2 ||
        _prefixDistancesM.length != widget.points.length) {
      return [];
    }
    const stepM = 300.0;
    final totalM = _prefixDistancesM.last;
    if (totalM < stepM) return [];
    final out = <({ll.LatLng point, double bearingDeg})>[];
    for (var d = stepM; d < totalM; d += stepM) {
      final idx = _indexAtDistanceM(d);
      if (idx == null || idx >= widget.points.length - 1) continue;
      final p = widget.points[idx];
      final next = widget.points[idx + 1];
      final bearing = _bearingDegrees(p, next);
      out.add((point: _pointAtDistanceM(d), bearingDeg: bearing));
    }
    return out;
  }

  int? _indexAtDistanceM(double distanceM) {
    for (int i = 0; i < _prefixDistancesM.length - 1; i++) {
      if (_prefixDistancesM[i] <= distanceM &&
          distanceM < _prefixDistancesM[i + 1]) {
        return i;
      }
    }
    return null;
  }

  ll.LatLng _pointAtDistanceM(double distanceM) {
    final idx = _indexAtDistanceM(distanceM);
    if (idx == null || idx >= widget.points.length - 1) {
      return widget.points.first;
    }
    final t = (distanceM - _prefixDistancesM[idx]) /
        (_prefixDistancesM[idx + 1] - _prefixDistancesM[idx]);
    final a = widget.points[idx];
    final b = widget.points[idx + 1];
    return ll.LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  double _bearingDegrees(ll.LatLng from, ll.LatLng to) {
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    var b = math.atan2(y, x) * 180 / math.pi;
    return (b + 360) % 360;
  }

  Future<void> _drawArrowMarkers() async {
    if (_pointAnnotationManager == null || widget.points.length < 2) return;
    for (final a in _arrowAnnotations) {
      await _pointAnnotationManager!.delete(a);
    }
    _arrowAnnotations = [];
    _arrowImage ??= await MarkerAssets.createArrowImage();
    if (_arrowImage == null) return;
    final positions = _computeArrowPositions();
    for (final pos in positions) {
      final ann = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              pos.point.longitude,
              pos.point.latitude,
            ),
          ),
          image: _arrowImage!,
          iconSize: 0.8,
          iconRotate: pos.bearingDeg,
        ),
      );
      _arrowAnnotations.add(ann);
    }
  }

  List<flutter_map.Marker> _buildFlutterMapArrowMarkers() {
    final positions = _computeArrowPositions();
    return positions
        .map(
          (pos) => flutter_map.Marker(
            point: pos.point,
            width: 20,
            height: 20,
            child: Transform.rotate(
              angle: (pos.bearingDeg - 90) * math.pi / 180,
              child: const Icon(
                CupertinoIcons.arrow_up,
                color: AppColors.brandPrimary,
                size: 20,
              ),
            ),
          ),
        )
        .toList();
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПРЕФИКСНЫЕ ДИСТАНЦИИ (для границ и стрелок)
  // ────────────────────────────────────────────────────────────────
  List<double> _buildPrefixDistances(List<ll.LatLng> pts) {
    if (pts.isEmpty) return [];
    final prefix = List<double>.filled(pts.length, 0, growable: false);
    for (int i = 1; i < pts.length; i++) {
      prefix[i] = prefix[i - 1] + _distance(pts[i - 1], pts[i]);
    }
    return prefix;
  }

  /// Средняя точка — подстраховка на момент инициализации
  ll.LatLng _centerFromPoints(List<ll.LatLng> pts) {
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    final n = pts.length.toDouble();
    return ll.LatLng(lat / n, lng / n);
  }

  /// Прямоугольник, который охватывает весь трек
  LatLngBounds _boundsFromPoints(List<ll.LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(ll.LatLng(minLat, minLng), ll.LatLng(maxLat, maxLng));
  }
}

/// Вспомогательный класс для границ (аналог LatLngBounds из flutter_map)
class LatLngBounds {
  final ll.LatLng southwest;
  final ll.LatLng northeast;

  LatLngBounds(this.southwest, this.northeast);
}
