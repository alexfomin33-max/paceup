// lib/features/lenta/screens/activity/fullscreen_route_map_screen.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';

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
  // Контроллер карты для возможного управления камерой в будущем
  // ignore: unused_field
  MapboxMap? _mapboxMap;
  final flutter_map.MapController _flutterMapController =
      flutter_map.MapController();
  final ll.Distance _distance = const ll.Distance();
  List<double> _prefixDistancesM = [];
  List<double> _elevationValues = [];
  // ────────────────────────────────────────────────────────────────
  // 🔹 ПОРОГ ПО ВЫСОТЕ: меньше — считаем участок «ровным»
  // ────────────────────────────────────────────────────────────────
  static const double _elevationThresholdM = 3.0;
  // ────────────────────────────────────────────────────────────────
  // 🔹 ФЛАГ ГОТОВНОСТИ: скрываем карту до полной инициализации маршрута
  // ────────────────────────────────────────────────────────────────
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _prefixDistancesM = _buildPrefixDistances(widget.points);
    _elevationValues = _parseElevationPerKm(widget.elevationPerKm);
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
          // ────────────────────────────────────────────────────────────────
          // 🔹 ЛЕГЕНДА ВЫСОТЫ: подъём/спуск (если есть данные высоты)
          // ────────────────────────────────────────────────────────────────
          if (_canColorByElevation())
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: SafeArea(
                child: _ElevationLegend(
                  upColor: AppColors.error,
                  downColor: AppColors.success,
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
    // 🔹 ЕСЛИ НЕТ ДАННЫХ ВЫСОТЫ — РИСУЕМ ОДИН ЦВЕТ
    // ──────────────────────────────────────────────────────────────
    if (!_canColorByElevation()) {
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
      return;
    }

    // ──────────────────────────────────────────────────────────────
    // 🔹 РИСУЕМ УЧАСТКИ С РАЗНЫМИ ЦВЕТАМИ
    // ──────────────────────────────────────────────────────────────
    final segments = _buildColoredSegments();
    for (final segment in segments) {
      final coordinates = segment.points
          .map((p) => Position(p.longitude, p.latitude))
          .toList();
      await _polylineAnnotationManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coordinates),
          lineColor: segment.color.toARGB32(),
          lineWidth: 3.0,
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 FLUTTER_MAP: ПОЛИЛИНИИ С ОКРАСКОЙ
  // ────────────────────────────────────────────────────────────────
  List<flutter_map.Polyline> _buildFlutterMapPolylines() {
    if (!_canColorByElevation()) {
      return [
        flutter_map.Polyline(
          points: widget.points,
          strokeWidth: 3.0,
          color: AppColors.brandPrimary,
        ),
      ];
    }

    final segments = _buildColoredSegments();
    return segments
        .map(
          (segment) => flutter_map.Polyline(
            points: segment.points,
            strokeWidth: 3.0,
            color: segment.color,
          ),
        )
        .toList();
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 СЕГМЕНТАЦИЯ ЛИНИИ ПО ВЫСОТЕ
  // ────────────────────────────────────────────────────────────────
  List<_ColoredSegment> _buildColoredSegments() {
    if (widget.points.length < 2) return [];

    final segments = <_ColoredSegment>[];
    Color? currentColor;
    List<ll.LatLng> currentPoints = [];

    for (int i = 0; i < widget.points.length - 1; i++) {
      final segmentColor = _colorForSegment(i);
      final start = widget.points[i];
      final end = widget.points[i + 1];

      if (currentColor == null) {
        currentColor = segmentColor;
        currentPoints = [start, end];
        continue;
      }

      if (segmentColor == currentColor) {
        currentPoints.add(end);
        continue;
      }

      segments.add(
        _ColoredSegment(points: currentPoints, color: currentColor),
      );
      currentColor = segmentColor;
      currentPoints = [start, end];
    }

    if (currentColor != null && currentPoints.length >= 2) {
      segments.add(
        _ColoredSegment(points: currentPoints, color: currentColor),
      );
    }

    return segments;
  }

  Color _colorForSegment(int segmentIndex) {
    if (!_canColorByElevation()) return AppColors.brandPrimary;

    final midDistanceKm = _segmentMidDistanceKm(segmentIndex);
    final kmIndex =
        midDistanceKm.floor().clamp(0, _elevationValues.length - 1);
    final diff = _elevationDiffForIndex(kmIndex);

    // ──────────────────────────────────────────────────────────────
    // 🔹 ЕСЛИ ИЗМЕНЕНИЕ МЕНЬШЕ ПОРОГА — РИСУЕМ БАЗОВЫМ ЦВЕТОМ
    // ──────────────────────────────────────────────────────────────
    if (diff.abs() < _elevationThresholdM) {
      return AppColors.brandPrimary;
    }

    if (diff > 0) return AppColors.error;
    if (diff < 0) return AppColors.success;
    return AppColors.brandPrimary;
  }

  double _segmentMidDistanceKm(int segmentIndex) {
    if (_prefixDistancesM.length != widget.points.length ||
        _prefixDistancesM.isEmpty) {
      return segmentIndex.toDouble();
    }
    final segmentLen = _distance(
      widget.points[segmentIndex],
      widget.points[segmentIndex + 1],
    );
    final startDist = _prefixDistancesM[segmentIndex];
    return (startDist + segmentLen / 2) / 1000.0;
  }

  double _elevationDiffForIndex(int index) {
    if (_elevationValues.length <= 1) return 0;
    if (index <= 0) {
      return _elevationValues[1] - _elevationValues[0];
    }
    if (index >= _elevationValues.length - 1) {
      return _elevationValues[index] - _elevationValues[index - 1];
    }
    return _elevationValues[index + 1] - _elevationValues[index];
  }

  bool _canColorByElevation() {
    final type = widget.activityType?.toLowerCase() ?? '';
    final isSwim = type == 'swim' || type == 'swimming';
    return !isSwim && _elevationValues.length >= 2;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПАРСИНГ ВЫСОТЫ ПО КМ
  // ────────────────────────────────────────────────────────────────
  List<double> _parseElevationPerKm(Map<String, double> data) {
    if (data.isEmpty) return [];

    final entries = <MapEntry<int, double>>[];
    final regex = RegExp(r'(\d+)');

    data.forEach((key, value) {
      final match = regex.firstMatch(key);
      if (match == null) return;
      final idx = int.tryParse(match.group(1) ?? '');
      if (idx == null || idx <= 0) return;
      entries.add(MapEntry(idx, value));
    });

    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => e.value).toList();
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПРЕФИКСНЫЕ ДИСТАНЦИИ
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

class _ColoredSegment {
  const _ColoredSegment({
    required this.points,
    required this.color,
  });

  final List<ll.LatLng> points;
  final Color color;
}

class _ElevationLegend extends StatelessWidget {
  const _ElevationLegend({
    required this.upColor,
    required this.downColor,
  });

  final Color upColor;
  final Color downColor;

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────────────────────────────────
    // 🔹 КОНТЕЙНЕР ЛЕГЕНДЫ: СТИЛЬ ПО ТЕМЕ
    // ──────────────────────────────────────────────────────────────
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.getBorderColor(context),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendItem(
            color: upColor,
            label: 'Подъём',
          ),
          SizedBox(height: AppSpacing.xs),
          _LegendItem(
            color: downColor,
            label: 'Спуск',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────────────────────────────────
    // 🔹 СТРОКА ЛЕГЕНДЫ: ЦВЕТ + ТЕКСТ
    // ──────────────────────────────────────────────────────────────
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.sm,
          height: AppSpacing.sm,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.h13w5.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ],
    );
  }
}
