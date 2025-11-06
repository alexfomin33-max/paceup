import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../config/app_config.dart';

// контент вкладок
import 'events/events_screen.dart' as ev;
import 'events/events_filters_bottom_sheet.dart';
import 'clubs/clubs_screen.dart' as clb;
import 'slots/slots_screen.dart' as slt;
import 'travelers/travelers_screen.dart' as trv;

// нижние выезжающие окна
import 'events/events_bottom_sheet.dart' as ebs;
import 'clubs/clubs_bottom_sheet.dart' as cbs;
import 'slots/slots_bottom_sheet.dart' as sbs;
import 'travelers/travelers_bottom_sheet.dart' as tbs;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedIndex = 0;

  /// Контроллер карты для управления zoom и центром
  final MapController _mapController = MapController();

  final tabs = const ["События", "Клубы", "Слоты", "Попутчики"];

  /// Параметры фильтра событий (для обновления карты при применении фильтров)
  EventsFilterParams? _eventsFilterParams;

  /// Ключ для FutureBuilder событий (обновляется при изменении фильтров)
  Key _eventsMarkersKey = const ValueKey('events_markers_default');

  /// Цвета маркеров по вкладкам
  final markerColors = const {
    0: AppColors.accentBlue, // события
    1: AppColors.error, // клубы
    2: AppColors.success, // слоты
    3: AppColors.accentPurple, // попутчики
  };

  List<Map<String, dynamic>> _markersForTabSync(BuildContext context) {
    switch (_selectedIndex) {
      case 1:
        // Клубы теперь асинхронные, не используется здесь
        return [];
      case 2:
        return slt.slotsMarkers(context);
      case 3:
      default:
        return trv.travelersMarkers(context);
    }
  }

  /// ──────────── Автоматическая подстройка zoom под маркеры ────────────
  /// Вычисляет границы всех маркеров и подстраивает карту
  void _fitBoundsToMarkers(List<Map<String, dynamic>> markers) {
    if (markers.isEmpty) return;

    // Извлекаем точки из маркеров
    final points = markers
        .map((m) => m['point'] as LatLng?)
        .whereType<LatLng>()
        .toList();

    if (points.isEmpty) return;

    // Если маркер один, устанавливаем центр и разумный zoom
    if (points.length == 1) {
      _mapController.move(
        points.first,
        12.0, // Zoom для одного маркера
      );
      return;
    }

    // Вычисляем границы для нескольких маркеров
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

    // Создаём bounds и подстраиваем карту с отступами
    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(
          left: 30,
          right: 30,
          top: 160,
          bottom: 130,
        ), // Отступы: 50px по бокам, 150px сверху/снизу
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markerColor = markerColors[_selectedIndex] ?? AppColors.brandPrimary;

    // Для событий и клубов используем FutureBuilder, для остальных - синхронные данные
    if (_selectedIndex == 0 || _selectedIndex == 1) {
      return Scaffold(
        body: Stack(
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              // Используем динамический ключ для событий (обновляется при применении фильтров)
              // Для клубов используем статический ключ
              key: _selectedIndex == 0
                  ? _eventsMarkersKey
                  : const ValueKey('clubs_markers'),
              future: _selectedIndex == 0
                  ? ev.eventsMarkers(context, filterParams: _eventsFilterParams)
                  : clb.clubsMarkers(context),
              builder: (context, snapshot) {
                // Показываем карту даже во время загрузки (с пустыми маркерами)
                // ⚠️ ВАЖНО: Откладываем создание FlutterMap до следующего кадра,
                // чтобы не блокировать UI поток во время выполнения запроса
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Откладываем создание карты через Future.microtask,
                  // чтобы не блокировать UI поток во время выполнения запроса
                  return FutureBuilder<void>(
                    future: Future.microtask(() {}),
                    builder: (context, microtaskSnapshot) {
                      return microtaskSnapshot.connectionState ==
                              ConnectionState.done
                          ? _buildMap([], markerColor)
                          : Container(color: AppColors.surface);
                    },
                  );
                }
                
                // Обрабатываем ошибки
                if (snapshot.hasError) {
                  debugPrint('Ошибка загрузки маркеров: ${snapshot.error}');
                  return _buildMap([], markerColor);
                }
                
                final markers = snapshot.data ?? [];
                
                // Подстраиваем zoom после загрузки маркеров (только один раз)
                if (markers.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _fitBoundsToMarkers(markers);
                    }
                  });
                }
                
                return _buildMap(markers, markerColor);
              },
            ),
            _buildTabs(),
            if (_selectedIndex == 0)
              ev.EventsFloatingButtons(
                currentFilterParams: _eventsFilterParams,
                onApplyFilters: (params) {
                  // Обновляем параметры фильтра
                  setState(() {
                    _eventsFilterParams = params;
                    // Обновляем ключ FutureBuilder для перезагрузки данных
                    _eventsMarkersKey = ValueKey(
                      'events_markers_${DateTime.now().millisecondsSinceEpoch}',
                    );
                  });
                },
              ),
            if (_selectedIndex == 1) const clb.ClubsFloatingButtons(),
          ],
        ),
      );
    }

    final markers = _markersForTabSync(context);
    // Подстраиваем zoom при изменении вкладки
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitBoundsToMarkers(markers);
    });
    return _buildMapWithMarkers(markers, markerColor);
  }

  Widget _buildMapWithMarkers(
    List<Map<String, dynamic>> markers,
    Color markerColor,
  ) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(markers, markerColor),
          _buildTabs(),
          if (_selectedIndex == 1) const clb.ClubsFloatingButtons(),
          if (_selectedIndex == 2) const slt.SlotsFloatingButtons(),
          if (_selectedIndex == 3) const trv.TravelersFloatingButtons(),
        ],
      ),
    );
  }

  Widget _buildMap(List<Map<String, dynamic>> markers, Color markerColor) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(56.129057, 40.406635),
        initialZoom: 6.0,
        onMapReady: () {
          // Подстраиваем zoom после инициализации карты
          _fitBoundsToMarkers(markers);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.mapTilesUrl,
          additionalOptions: {'apiKey': AppConfig.mapTilerApiKey},
          userAgentPackageName: 'paceup.ru',
          maxZoom: 19,
          minZoom: 3,
          keepBuffer: 1,
          retinaMode: false,
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('MapTiler © OpenStreetMap')],
        ),
        MarkerLayer(
          markers: markers.map((m) {
            try {
              final LatLng point = m['point'] as LatLng;
              final String title = m['title'] as String;
              final int count = m['count'] as int;
              final dynamic events =
                  m['events']; // Для событий храним список событий
              final Widget? content = m['content'] as Widget?;

              return Marker(
                point: point,
                width: 28,
                height: 28,
                child: GestureDetector(
                  onTap: () {
                    final Widget sheet = () {
                      switch (_selectedIndex) {
                        case 0:
                          // Для событий создаём виджет со списком событий из API
                          return ebs.EventsBottomSheet(
                            title: title,
                            child: events != null && events is List
                                ? ebs.EventsListFromApi(
                                    events: events,
                                    latitude: m['latitude'] as double?,
                                    longitude: m['longitude'] as double?,
                                  )
                                : content ?? const ebs.EventsSheetPlaceholder(),
                          );
                        case 1:
                          // Для клубов создаём виджет со списком клубов из API
                          return cbs.ClubsBottomSheet(
                            title: title,
                            child: m['clubs'] != null && m['clubs'] is List
                                ? cbs.ClubsListFromApi(
                                    clubs: m['clubs'] as List<dynamic>,
                                    latitude: m['latitude'] as double?,
                                    longitude: m['longitude'] as double?,
                                  )
                                : content ?? const cbs.ClubsSheetPlaceholder(),
                          );
                        case 2:
                          return sbs.SlotsBottomSheet(
                            title: title,
                            child: content ?? const sbs.SlotsSheetPlaceholder(),
                          );
                        case 3:
                        default:
                          return tbs.TravelersBottomSheet(
                            title: title,
                            child:
                                content ?? const tbs.TravelersSheetPlaceholder(),
                          );
                      }
                    }();

                    showModalBottomSheet(
                      context: context,
                      useRootNavigator: true,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => sheet,
                    );
                  },

                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            } catch (e) {
              // Возвращаем пустой маркер, чтобы не сломать отрисовку
              return Marker(
                point: LatLng(0, 0),
                width: 0,
                height: 0,
                child: const SizedBox.shrink(),
              );
            }
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 10,
      right: 10,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(tabs.length, (index) {
              final isSelected = _selectedIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected
                          ? AppColors.surface
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
