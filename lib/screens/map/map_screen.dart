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
import 'clubs/clubs_filters_bottom_sheet.dart';
// import 'coaches/coaches_screen.dart' as cch; // тренеры - временно закомментировано
// import 'travelers/travelers_screen.dart' as trv; // попутчики - временно закомментировано

// нижние выезжающие окна
import 'events/events_bottom_sheet.dart' as ebs;
import 'clubs/clubs_bottom_sheet.dart' as cbs;
// import 'coaches/coaches_bottom_sheet.dart' as cchbs; // тренеры - временно закомментировано
// import 'travelers/travelers_bottom_sheet.dart' as tbs; // попутчики - временно закомментировано

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedIndex = 0;

  /// Контроллер карты для управления zoom и центром
  final MapController _mapController = MapController();

  final tabs = const ["События", "Клубы"]; // "Тренеры", "Попутчики" - временно закомментировано

  /// Параметры фильтра событий (для обновления карты при применении фильтров)
  EventsFilterParams? _eventsFilterParams;

  /// Параметры фильтра клубов (для обновления карты при применении фильтров)
  ClubsFilterParams? _clubsFilterParams;

  /// Ключ для FutureBuilder событий (обновляется при изменении фильтров или создании события)
  Key _eventsMarkersKey = const ValueKey('events_markers_default');

  /// Ключ для FutureBuilder клубов (обновляется при изменении фильтров или создании клуба)
  Key _clubsMarkersKey = const ValueKey('clubs_markers_default');

  /// Флаг инициализации карты для вкладок События и Клубы
  /// Предотвращает мерцание - карта создается один раз
  bool _mapInitialized = false;

  /// Цвета маркеров по вкладкам
  final markerColors = const {
    0: AppColors.accentBlue, // события
    1: AppColors.error, // клубы
    // 2: AppColors.success, // тренеры - временно закомментировано
    // 3: AppColors.accentPurple, // попутчики - временно закомментировано
  };

  List<Map<String, dynamic>> _markersForTabSync(BuildContext context) {
    switch (_selectedIndex) {
      case 1:
        // Клубы теперь асинхронные, не используется здесь
        return [];
      // case 2:
      //   return cch.coachesMarkers(context); // тренеры - временно закомментировано
      // case 3:
      // default:
      //   return trv.travelersMarkers(context); // попутчики - временно закомментировано
      default:
        return [];
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
              // Используем динамический ключ для событий (обновляется при применении фильтров или создании события)
              // Для клубов используем динамический ключ (обновляется при создании или удалении клуба)
              key: _selectedIndex == 0 ? _eventsMarkersKey : _clubsMarkersKey,
              future: _selectedIndex == 0
                  ? ev.eventsMarkers(context, filterParams: _eventsFilterParams)
                  : clb.clubsMarkers(context, filterParams: _clubsFilterParams),
              builder: (context, snapshot) {
                // Показываем карту даже во время загрузки (с пустыми маркерами)
                // ⚠️ ВАЖНО: Откладываем создание FlutterMap до следующего кадра,
                // чтобы не блокировать UI поток во время выполнения запроса
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_mapInitialized) {
                  // Откладываем создание карты через Future.microtask,
                  // чтобы не блокировать UI поток во время выполнения запроса
                  return FutureBuilder<void>(
                    future: Future.microtask(() {}),
                    builder: (context, microtaskSnapshot) {
                      if (microtaskSnapshot.connectionState ==
                          ConnectionState.done) {
                        // Помечаем карту как инициализированную, чтобы она не пересоздавалась
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _mapInitialized = true;
                            });
                          }
                        });
                        return _buildMap([], markerColor);
                      }
                      return Container(color: AppColors.surface);
                    },
                  );
                }

                // После первой инициализации всегда показываем карту
                // Это предотвращает мерцание - карта не пересоздается
                final markers = snapshot.hasData
                    ? (snapshot.data ?? [])
                    : <Map<String, dynamic>>[];

                // Обрабатываем ошибки
                if (snapshot.hasError) {
                  debugPrint('Ошибка загрузки маркеров: ${snapshot.error}');
                }

                // Автоматическая подстройка zoom отключена для Событий и Клубов
                // Пользователь может самостоятельно управлять масштабом карты

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
                    // Сбрасываем флаг инициализации при обновлении данных
                    _mapInitialized = false;
                    // Обновляем ключ FutureBuilder для перезагрузки данных
                    _eventsMarkersKey = ValueKey(
                      'events_markers_${DateTime.now().millisecondsSinceEpoch}',
                    );
                  });
                },
                onEventCreated: () {
                  // Обновляем ключ FutureBuilder для перезагрузки данных после создания события
                  setState(() {
                    // Сбрасываем флаг инициализации при обновлении данных
                    _mapInitialized = false;
                    _eventsMarkersKey = ValueKey(
                      'events_markers_${DateTime.now().millisecondsSinceEpoch}',
                    );
                  });
                },
              ),
            if (_selectedIndex == 1)
              clb.ClubsFloatingButtons(
                currentFilterParams: _clubsFilterParams,
                onApplyFilters: (params) {
                  // Обновляем параметры фильтра
                  setState(() {
                    _clubsFilterParams = params;
                    // Сбрасываем флаг инициализации при обновлении данных
                    _mapInitialized = false;
                    // Обновляем ключ FutureBuilder для перезагрузки данных
                    _clubsMarkersKey = ValueKey(
                      'clubs_markers_${DateTime.now().millisecondsSinceEpoch}',
                    );
                  });
                },
                onClubCreated: () {
                  // Обновляем ключ FutureBuilder для перезагрузки данных после создания клуба
                  setState(() {
                    // Сбрасываем флаг инициализации при обновлении данных
                    _mapInitialized = false;
                    _clubsMarkersKey = ValueKey(
                      'clubs_markers_${DateTime.now().millisecondsSinceEpoch}',
                    );
                  });
                },
              ),
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
          if (_selectedIndex == 1)
            clb.ClubsFloatingButtons(
              currentFilterParams: _clubsFilterParams,
              onApplyFilters: (params) {
                // Обновляем параметры фильтра
                setState(() {
                  _clubsFilterParams = params;
                  // Сбрасываем флаг инициализации при обновлении данных
                  _mapInitialized = false;
                  // Обновляем ключ FutureBuilder для перезагрузки данных
                  _clubsMarkersKey = ValueKey(
                    'clubs_markers_${DateTime.now().millisecondsSinceEpoch}',
                  );
                });
              },
              onClubCreated: () {
                // Обновляем ключ FutureBuilder для перезагрузки данных после создания клуба
                setState(() {
                  // Сбрасываем флаг инициализации при обновлении данных
                  _mapInitialized = false;
                  _clubsMarkersKey = ValueKey(
                    'clubs_markers_${DateTime.now().millisecondsSinceEpoch}',
                  );
                });
              },
            ),
          // if (_selectedIndex == 2) const cch.CoachesFloatingButtons(), // тренеры - временно закомментировано
          // if (_selectedIndex == 3) const trv.TravelersFloatingButtons(), // попутчики - временно закомментировано
        ],
      ),
    );
  }

  Widget _buildMap(List<Map<String, dynamic>> markers, Color markerColor) {
    return SizedBox.expand(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(56.129057, 40.406635),
          initialZoom: 6.0,
          // Фоновый цвет карты (серый, если тайлы не загрузились)
          backgroundColor: AppColors.getSurfaceColor(context),
          onMapReady: () {
            // Подстраиваем zoom после инициализации карты
            // Для Событий (0) и Клубов (1) автоматическая подстройка отключена
            // if (_selectedIndex != 0 && _selectedIndex != 1) {
            //   _fitBoundsToMarkers(markers);
            // }
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
                final dynamic events = m['events'];
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
                                  : content ??
                                        const ebs.EventsSheetPlaceholder(),
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
                                  : content ??
                                        const cbs.ClubsSheetPlaceholder(),
                            );
                          // case 2: // тренеры - временно закомментировано
                          //   return cchbs.CoachesBottomSheet(
                          //     title: title,
                          //     child:
                          //         content ??
                          //         const cchbs.CoachesSheetPlaceholder(),
                          //   );
                          // case 3: // попутчики - временно закомментировано
                          default:
                            return const SizedBox.shrink();
                            // return tbs.TravelersBottomSheet(
                            //   title: title,
                            //   child:
                            //       content ??
                            //       const tbs.TravelersSheetPlaceholder(),
                            // );
                        }
                      }();

                      showModalBottomSheet(
                        context: context,
                        useRootNavigator: true,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => sheet,
                      ).then((result) {
                        // Если событие было удалено, обновляем маркеры на карте
                        if (result == 'event_deleted' && mounted) {
                          setState(() {
                            // Сбрасываем флаг инициализации при обновлении данных
                            _mapInitialized = false;
                            _eventsMarkersKey = ValueKey(
                              'events_markers_${DateTime.now().millisecondsSinceEpoch}',
                            );
                          });
                        }
                        // Если клуб был удалён, обновляем маркеры на карте
                        if (result == 'club_deleted' && mounted) {
                          setState(() {
                            // Сбрасываем флаг инициализации при обновлении данных
                            _mapInitialized = false;
                            _clubsMarkersKey = ValueKey(
                              'clubs_markers_${DateTime.now().millisecondsSinceEpoch}',
                            );
                          });
                        }
                      });
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
      ),
    );
  }

  Widget _buildTabs() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
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
              mainAxisSize: MainAxisSize.max,
              children: List.generate(tabs.length, (index) {
                final isSelected = _selectedIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Сбрасываем флаг инициализации при смене вкладки
                      // Это нужно для корректной работы при переключении между вкладками
                      if (_selectedIndex != index) {
                        _mapInitialized = false;
                      }
                      setState(() => _selectedIndex = index);
                    },
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
                        textAlign: TextAlign.center,
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
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
