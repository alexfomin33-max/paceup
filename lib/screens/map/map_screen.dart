import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_map/flutter_map.dart' as flutter_map;
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
  MapboxMap? _mapboxMap;

  /// Контроллер flutter_map для macOS
  final flutter_map.MapController _flutterMapController = flutter_map.MapController();

  final tabs = const [
    "События",
    "Клубы",
  ]; // "Тренеры", "Попутчики" - временно закомментировано

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

  /// Менеджер аннотаций для маркеров
  PointAnnotationManager? _pointAnnotationManager;

  /// Данные маркеров для обработки кликов
  final Map<String, Map<String, dynamic>> _markerData = {};

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
  Future<void> _fitBoundsToMarkers(List<Map<String, dynamic>> markers) async {
    if (markers.isEmpty || _mapboxMap == null) return;

    // Извлекаем точки из маркеров
    final points = markers
        .map((m) => m['point'] as latlong.LatLng?)
        .whereType<latlong.LatLng>()
        .toList();

    if (points.isEmpty) return;

    // Если маркер один, устанавливаем центр и разумный zoom
    if (points.length == 1) {
      await _mapboxMap!.flyTo(
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
    final camera = await _mapboxMap!.cameraForCoordinateBounds(
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
    await _mapboxMap!.setCamera(camera);
  }

  /// Создание изображения маркера с текстом
  Future<Uint8List> _createMarkerImage(Color color, String text) async {
    const size = 64.0; // Увеличиваем размер маркера еще больше
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Рисуем круг
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 0.5, paint);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 0.5,
      borderPaint,
    );

    // Рисуем текст
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.surface,
          fontWeight: FontWeight.w600,
          fontSize: 36, // Увеличиваем размер текста пропорционально
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Настройка маркеров на карте
  Future<void> _setupMarkers(
    List<Map<String, dynamic>> markers,
    Color markerColor,
  ) async {
    if (_mapboxMap == null) return;

    try {
      // Удаляем старые маркеры
      if (_pointAnnotationManager != null) {
        await _pointAnnotationManager!.deleteAll();
      }

      // Создаем менеджер аннотаций, если его нет
      _pointAnnotationManager ??= await _mapboxMap!.annotations
          .createPointAnnotationManager();

      _markerData.clear();

      if (markers.isEmpty) return;

      // Создаем изображения маркеров
      final imageMap = <String, Uint8List>{};
      for (final marker in markers) {
        try {
          final count = marker['count'] as int;
          final imageKey = 'marker_${markerColor.value}_$count';
          if (!imageMap.containsKey(imageKey)) {
            imageMap[imageKey] = await _createMarkerImage(
              markerColor,
              '$count',
            );
          }
        } catch (e) {
          debugPrint('Ошибка создания изображения маркера: $e');
        }
      }

      // Создаем аннотации
      final annotations = <PointAnnotationOptions>[];
      for (final marker in markers) {
        try {
          final point = marker['point'] as latlong.LatLng;
          final count = marker['count'] as int;
          final imageKey = 'marker_${markerColor.value}_$count';
          final imageBytes = imageMap[imageKey]!;

          // Сохраняем данные маркера по координатам для поиска при клике
          // Используем строку с координатами как ключ (округление до 6 знаков для точности)
          final markerKey =
              '${point.latitude.toStringAsFixed(6)}_${point.longitude.toStringAsFixed(6)}';
          _markerData[markerKey] = marker;

          annotations.add(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(point.longitude, point.latitude),
              ),
              image: imageBytes,
              iconSize: 1.2, // Увеличиваем размер иконки на 20%
            ),
          );
        } catch (e) {
          debugPrint('Ошибка создания аннотации: $e');
        }
      }

      if (annotations.isNotEmpty) {
        await _pointAnnotationManager!.createMulti(annotations);
      }
    } catch (e) {
      debugPrint('Ошибка настройки маркеров: $e');
    }
  }

  /// Обработка клика по маркеру (для Mapbox)
  void _onMarkerTap(PointAnnotation annotation) {
    // Получаем координаты из геометрии аннотации
    final geometry = annotation.geometry;
    final coordinates = geometry.coordinates;

    if (coordinates.length < 2) return;

    // В Mapbox координаты хранятся как [longitude, latitude]
    final lng = coordinates[0] as double;
    final lat = coordinates[1] as double;

    // Ищем маркер по координатам (округление до 6 знаков для точности)
    final markerKey = '${lat.toStringAsFixed(6)}_${lng.toStringAsFixed(6)}';
    final marker = _markerData[markerKey];

    if (marker == null) {
      debugPrint('Маркер не найден для координат: $lat, $lng');
      return;
    }

    _showMarkerBottomSheet(marker);
  }

  /// Обработка клика по маркеру (для flutter_map на macOS)
  void _onFlutterMapMarkerTap(Map<String, dynamic> marker) {
    _showMarkerBottomSheet(marker);
  }

  /// Показать bottom sheet для маркера
  void _showMarkerBottomSheet(Map<String, dynamic> marker) {
    final title = marker['title'] as String;
    final dynamic events = marker['events'];
    final Widget? content = marker['content'] as Widget?;

    final Widget sheet = () {
      switch (_selectedIndex) {
        case 0:
          // Для событий создаём виджет со списком событий из API
          return ebs.EventsBottomSheet(
            title: title,
            child: events != null && events is List
                ? ebs.EventsListFromApi(
                    events: events,
                    latitude: marker['latitude'] as double?,
                    longitude: marker['longitude'] as double?,
                  )
                : content ?? const ebs.EventsSheetPlaceholder(),
          );
        case 1:
          // Для клубов создаём виджет со списком клубов из API
          return cbs.ClubsBottomSheet(
            title: title,
            child: marker['clubs'] != null && marker['clubs'] is List
                ? cbs.ClubsListFromApi(
                    clubs: marker['clubs'] as List<dynamic>,
                    latitude: marker['latitude'] as double?,
                    longitude: marker['longitude'] as double?,
                  )
                : content ?? const cbs.ClubsSheetPlaceholder(),
          );
        default:
          return const SizedBox.shrink();
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
          _mapInitialized = false;
          _eventsMarkersKey = ValueKey(
            'events_markers_${DateTime.now().millisecondsSinceEpoch}',
          );
        });
      }
      // Если клуб был удалён, обновляем маркеры на карте
      if (result == 'club_deleted' && mounted) {
        setState(() {
          _mapInitialized = false;
          _clubsMarkersKey = ValueKey(
            'clubs_markers_${DateTime.now().millisecondsSinceEpoch}',
          );
        });
      }
    });
  }

  /// Построение карты с flutter_map для macOS
  Widget _buildFlutterMap(List<Map<String, dynamic>> markers, Color markerColor) {
    // Вычисляем центр карты
    latlong.LatLng center = const latlong.LatLng(56.129057, 40.406635);
    double zoom = 6.0;

    if (markers.isNotEmpty) {
      final points = markers
          .map((m) => m['point'] as latlong.LatLng?)
          .whereType<latlong.LatLng>()
          .toList();

      if (points.isNotEmpty) {
        if (points.length == 1) {
          center = points.first;
          zoom = 12.0;
        } else {
          // Вычисляем центр всех точек
          double sumLat = 0, sumLng = 0;
          for (final point in points) {
            sumLat += point.latitude;
            sumLng += point.longitude;
          }
          center = latlong.LatLng(sumLat / points.length, sumLng / points.length);
          zoom = 10.0;
        }
      }
    }

    // Подстраиваем камеру при первом отображении
    if (!_mapInitialized && markers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final points = markers
            .map((m) => m['point'] as latlong.LatLng?)
            .whereType<latlong.LatLng>()
            .toList();
        if (points.length > 1) {
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
          _flutterMapController.fitCamera(
            flutter_map.CameraFit.bounds(
              bounds: flutter_map.LatLngBounds(
                latlong.LatLng(minLat, minLng),
                latlong.LatLng(maxLat, maxLng),
              ),
              padding: const EdgeInsets.all(30),
            ),
          );
        } else if (points.length == 1) {
          _flutterMapController.move(points.first, 12.0);
        }
      });
    }

    return SizedBox.expand(
      child: flutter_map.FlutterMap(
        mapController: _flutterMapController,
        options: flutter_map.MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          minZoom: 3.0,
          maxZoom: 18.0,
        ),
        children: [
          flutter_map.TileLayer(
            urlTemplate: AppConfig.mapTilesUrl.replaceAll('{apiKey}', AppConfig.mapTilerApiKey),
            userAgentPackageName: 'com.example.paceup',
          ),
          flutter_map.MarkerLayer(
            markers: markers.map((marker) {
              final point = marker['point'] as latlong.LatLng?;
              if (point == null) {
                return flutter_map.Marker(
                  point: const latlong.LatLng(0, 0),
                  width: 0,
                  height: 0,
                  child: const SizedBox.shrink(),
                );
              }

              final count = marker['count'] as int? ?? 0;

              return flutter_map.Marker(
                point: point,
                width: 64,
                height: 64,
                child: GestureDetector(
                  onTap: () => _onFlutterMapMarkerTap(marker),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapboxMap = null;
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
                // ⚠️ ВАЖНО: Откладываем создание MapWidget до следующего кадра,
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
                      return Container(
                        color: AppColors.getSurfaceColor(context),
                      );
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
    // Проверяем поддержку платформы - используем flutter_map для macOS
    if (Platform.isMacOS) {
      return _buildFlutterMap(markers, markerColor);
    }

    // Обновляем маркеры при изменении данных
    if (_mapboxMap != null && _pointAnnotationManager != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupMarkers(markers, markerColor);
      });
    }

    return SizedBox.expand(
      child: MapWidget(
        key: ValueKey('map_screen_${_selectedIndex}_${_mapInitialized}'),
        onMapCreated: (MapboxMap mapboxMap) async {
          _mapboxMap = mapboxMap;

          // Подписываемся на клики по маркерам
          _pointAnnotationManager = await mapboxMap.annotations
              .createPointAnnotationManager();
          _pointAnnotationManager!.tapEvents(
            onTap: (annotation) {
              _onMarkerTap(annotation);
            },
          );

          // Настраиваем маркеры после создания карты
          await _setupMarkers(markers, markerColor);
        },
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(40.406635, 56.129057)),
          zoom: 6.0,
        ),
        styleUri: MapboxStyles.MAPBOX_STREETS,
      ),
    );
  }

  Widget _buildTabs() {
    // ── определяем цвета в зависимости от темы
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    // ── в темной теме убираем тень, чтобы фон был идентичен нижнему меню
    final shadowColor = isDark ? null : AppColors.shadowMedium;

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
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: shadowColor != null
                  ? [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
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
                            ? AppColors.getTextPrimaryColor(context)
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
                              ? AppColors.getSurfaceColor(context)
                              : AppColors.getTextPrimaryColor(context),
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
