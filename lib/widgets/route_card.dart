// lib/widgets/route_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

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

    // Формируем финальный URL с подставленным API ключом
    final finalUrlTemplate = AppConfig.mapTilesUrl.replaceAll(
      '{apiKey}',
      AppConfig.mapTilerApiKey,
    );

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

        return SizedBox(
          width: double.infinity,
          height: widget.height,
          // Полностью отключаем взаимодействие — это "картинка", а не интерактивная карта
          child: IgnorePointer(
            ignoring: true,
            child: FlutterMap(
              key: ValueKey('route_card_${points.length}'),
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12,
                // Жесты отключены (дублируем через InteractionOptions на всякий случай)
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
                // Фоновый цвет карты (серый, если тайлы не загрузились)
                backgroundColor: AppColors.surfaceMuted,

                // Приготовим «вписывание» в onMapReady, когда размер уже известен
                onMapReady: () {
                  // Небольшая задержка перед fitCamera для гарантии, что карта полностью инициализирована
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final fit = CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(12),
                    );
                    _mapController.fitCamera(fit);
                  });
                },
              ),

              // Слои карты (тайлы + трек)
              children: [
                // Тайл-слой MapTiler Streets
                // Используем финальный URL с подставленным ключом
                TileLayer(
                  urlTemplate: finalUrlTemplate,
                  keepBuffer: 1,
                  retinaMode: true,
                  maxZoom: 18,
                  minZoom: 3,
                  userAgentPackageName: 'paceup.ru',

                  // Обработка ошибок загрузки тайлов (тихо игнорируем)
                  errorTileCallback: (tile, error, stackTrace) {
                    // Ошибки загрузки тайлов логируются только в debug режиме
                  },
                ),

                // Атрибуция — корректно показываем источник данных
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('MapTiler © OpenStreetMap'),
                  ],
                ),

                // Линия трека
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 3.0,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
              ],
            ),
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
