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

  const FullscreenRouteMapScreen({super.key, required this.points});

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
  // ────────────────────────────────────────────────────────────────
  // 🔹 ФЛАГ ГОТОВНОСТИ: скрываем карту до полной инициализации маршрута
  // ────────────────────────────────────────────────────────────────
  bool _isMapReady = false;

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
            polylines: [
              flutter_map.Polyline(
                points: widget.points,
                strokeWidth: 3.0,
                color: AppColors.brandPrimary,
              ),
            ],
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

                // Создаем полилинию из точек
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
