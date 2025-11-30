// lib/widgets/route_card.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import '../theme/app_theme.dart';
import '../config/app_config.dart';

/// Карточка маршрута.
/// - Рендерит статичную карту с треком (без интерактива).
/// - Автовписывает камеру по границам трека.
/// - Никаких скруглений: контейнер занимает всю ширину.
/// - Безопасно переживает пустой список точек.
class RouteCard extends StatefulWidget {
  const RouteCard({super.key, required this.points, this.height = 200});

  /// Точки трека в порядке следования.
  final List<LatLng> points;

  /// Высота карты (по макету у тебя ~200).
  final double height;

  @override
  State<RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard> {
  PolylineAnnotationManager? _polylineAnnotationManager;
  // ────────────────────────────────────────────────────────────────
  // 🔹 ФЛАГ ГОТОВНОСТИ: скрываем карту до полной инициализации маршрута
  // ────────────────────────────────────────────────────────────────
  bool _isMapReady = false;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;

    // Пустой маршрут — отдаём компактный плейсхолдер
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('Нет точек маршрута'),
      );
    }

    final center = _centerFromPoints(points);
    final bounds = _boundsFromPoints(points);

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasValidSize =
            constraints.maxWidth > 0 && constraints.maxHeight > 0;

        // Если размер невалидный, показываем плейсхолдер
        if (!hasValidSize) {
          return SizedBox(
            width: double.infinity,
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            ),
          );
        }

        // Используем flutter_map для macOS
        if (Platform.isMacOS) {
          return SizedBox(
            width: double.infinity,
            height: widget.height,
            child: flutter_map.FlutterMap(
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
                      points: points,
                      strokeWidth: 3.0,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          height: widget.height,
          child: Stack(
            children: [
              // ────────────────────────────────────────────────────────────────
              // 🔹 ФОН: показываем до готовности карты (цвет карточки)
              // ────────────────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                height: widget.height,
                color: AppColors.getSurfaceColor(context),
              ),
              // ────────────────────────────────────────────────────────────────
              // 🔹 КАРТА: появляется с fade-эффектом после полной инициализации
              // ────────────────────────────────────────────────────────────────
              IgnorePointer(
                ignoring: true,
                child: AnimatedOpacity(
                  opacity: _isMapReady ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: MapWidget(
                    key: ValueKey('route_card_${points.length}'),
                    onMapCreated: (MapboxMap mapboxMap) async {
                      // ────────────────────────── Отключаем масштабную линейку ──────────────────────────
                      // Отключаем горизонтальную линию масштаба, которая отображается сверху слева
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
                        final coordinates = points
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
                        // Если не удалось создать полилинию, логируем ошибку
                        // Карта всё равно отобразится, просто без трека
                        debugPrint(
                          '⚠️ Не удалось создать полилинию на карте: $annotationError',
                        );
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
                        // Если канал еще не готов, логируем и продолжаем работу
                        // Карта отобразится с начальной позицией из cameraOptions
                        debugPrint(
                          '⚠️ Не удалось настроить камеру карты: $cameraError',
                        );
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
              ),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────── ВНУТРЕННИЕ ХЕЛПЕРЫ ──────────────────────

  /// Средняя точка — подстраховка на момент инициализации
  LatLng _centerFromPoints(List<LatLng> pts) {
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    final n = pts.length.toDouble();
    return LatLng(lat / n, lng / n);
  }

  /// Прямоугольник, который охватывает весь трек
  LatLngBounds _boundsFromPoints(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }
}

/// Вспомогательный класс для границ (аналог LatLngBounds из flutter_map)
class LatLngBounds {
  final LatLng southwest;
  final LatLng northeast;

  LatLngBounds(this.southwest, this.northeast);
}
