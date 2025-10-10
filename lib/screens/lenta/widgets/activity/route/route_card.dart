// lib/screens/lenta/widgets/route/route_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
    // MapController не держит тяжёлых ресурсов, но оставим для симметрии жизненного цикла
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

    return SizedBox(
      width: double.infinity,
      height: widget.height,

      // Полностью отключаем взаимодействие — это "картинка", а не интерактивная карта
      child: IgnorePointer(
        ignoring: true,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
            // Жесты отключены (дублируем через InteractionOptions на всякий случай)
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
            backgroundColor: Colors.transparent,

            // Приготовим «вписывание» в onMapReady, когда размер уже известен
            onMapReady: () {
              final fit = CameraFit.bounds(
                bounds: _boundsFromPoints(points),
                padding: const EdgeInsets.all(12),
              );
              _mapController.fitCamera(fit);
            },
          ),

          // Слои карты (тайлы + трек)
          children: [
            // Тайл-слой MapTiler Streets (как у тебя)
            TileLayer(
              urlTemplate:
                  'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={apiKey}',
              additionalOptions: {
                // !!! Вынеси ключ в конфиг/секреты, это просто демонстрация
                'apiKey': '5Ssg96Nz79IHOCKB0MLL',
              },
              keepBuffer: 1,
              retinaMode: true,
              maxZoom: 18,
              minZoom: 3,
              userAgentPackageName: 'paceup.ru',
            ),

            // Атрибуция — корректно показываем источник данных
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('MapTiler © OpenStreetMap')],
            ),

            // Линия трека
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 3.0,
                  color: const Color(
                    0xFF0080FF,
                  ), // сплошной синий без прозрачности
                ),
              ],
            ),
          ],
        ),
      ),
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
