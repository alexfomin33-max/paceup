import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';

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
import 'clubs/club_popup.dart' as cpopup;
// import 'coaches/coaches_bottom_sheet.dart' as cchbs; // тренеры - временно закомментировано
// import 'travelers/travelers_bottom_sheet.dart' as tbs; // попутчики - временно закомментировано

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  int _selectedIndex = 0;

  /// Контроллер карты для управления zoom и центром
  MapboxMap? _mapboxMap;

  /// Контроллер flutter_map для macOS
  final flutter_map.MapController _flutterMapController =
      flutter_map.MapController();

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

  /// Менеджер аннотаций для маркеров (используется как fallback)
  PointAnnotationManager? _pointAnnotationManager;

  /// Данные маркеров для обработки кликов
  /// Ключ: координаты в формате "lat_lng", значение: данные маркера
  final Map<String, Map<String, dynamic>> _markerData = {};

  /// ID источника GeoJSON для кластеризации
  static const String _geoJsonSourceId = 'markers-source';

  /// ID слоя для кластеров (круги)
  static const String _clusterLayerId = 'clusters';

  /// ID слоя для текста кластеров
  static const String _clusterTextLayerId = 'cluster-count';

  /// ID слоя для отдельных точек (не кластеры) - текст
  static const String _unclusteredLayerId = 'unclustered-point';

  /// ID слоя для кругов отдельных точек (фон)
  static const String _unclusteredCircleLayerId = 'unclustered-point-circle';

  /// ID слоя для официальных маркеров (красные)
  static const String _officialCircleLayerId = 'official-point-circle';

  /// Цвета маркеров по вкладкам
  final markerColors = const {
    0: AppColors.accentBlue, // события
    1: AppColors.error, // клубы
    // 2: AppColors.success, // тренеры - временно закомментировано
    // 3: AppColors.accentPurple, // попутчики - временно закомментировано
  };

  /// ──────────── Буфер маркеров для повторной отрисовки ────────────
  /// Хранит последние данные API, чтобы отрисовать их после готовности карты.
  List<Map<String, dynamic>> _pendingMarkers = const [];

  /// Цвет маркеров последней активной вкладки (используется после инициализации).
  Color? _pendingMarkerColor;

  /// ──────────── Исходные маркеры для определения кластеров ────────────
  /// Хранит все исходные маркеры до кластеризации для точного определения
  /// принадлежности точек к кластерам при клике
  List<Map<String, dynamic>> _allOriginalMarkers = const [];

  /// Флаг для предотвращения параллельных операций с маркерами
  bool _isUpdatingMarkers = false;

  /// Токен для отмены предыдущих операций
  Object? _currentUpdateToken;

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

    // Создаём bounds и подстраиваем карту с отступами с обработкой ошибок канала
    try {
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
    } catch (cameraError) {
      // Если канал еще не готов, логируем и продолжаем работу
      // Карта останется в текущей позиции
      debugPrint('⚠️ Не удалось настроить камеру карты: $cameraError');
    }
  }

  /// ──────────── Конвертация маркеров в GeoJSON ────────────
  /// Преобразует список маркеров в формат GeoJSON для использования с кластеризацией
  String _markersToGeoJson(List<Map<String, dynamic>> markers) {
    final features = <Map<String, dynamic>>[];

    for (final marker in markers) {
      final point = marker['point'] as latlong.LatLng?;
      if (point == null) continue;

      // Сохраняем данные маркера для обработки кликов
      final markerKey =
          '${point.latitude.toStringAsFixed(6)}_${point.longitude.toStringAsFixed(6)}';
      _markerData[markerKey] = marker;

      // Получаем флаг официального события
      final isOfficial = marker['is_official'] as bool? ?? false;

      // Создаем GeoJSON Feature
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [point.longitude, point.latitude],
        },
        'properties': {
          'count': marker['count'] as int? ?? 0,
          'title': marker['title'] as String? ?? '',
          'latitude': point.latitude,
          'longitude': point.longitude,
          'is_official':
              isOfficial, // Флаг официального события для условного цвета
        },
      });
    }

    return jsonEncode({'type': 'FeatureCollection', 'features': features});
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

  /// ──────────── Настройка маркеров с кластеризацией через GeoJSON ────────────
  /// Использует GeoJSON source с кластеризацией для эффективного отображения
  /// большого количества маркеров
  /// ВАЖНО: Защищено от параллельных вызовов через _isUpdatingMarkers
  Future<void> _setupMarkers(
    List<Map<String, dynamic>> markers,
    Color markerColor, {
    Object? updateToken,
  }) async {
    if (_mapboxMap == null || !mounted) return;

    // Проверяем, не отменена ли операция
    if (updateToken != null && updateToken != _currentUpdateToken) {
      debugPrint('⚠️ Операция обновления маркеров отменена (новый токен)');
      return;
    }

    // Предотвращаем параллельные операции
    if (_isUpdatingMarkers) {
      debugPrint('⚠️ Обновление маркеров уже выполняется, пропускаем');
      return;
    }

    _isUpdatingMarkers = true;

    // Добавляем небольшую задержку для гарантии готовности карты
    // Это предотвращает конфликты при быстром переключении вкладок
    await Future.delayed(const Duration(milliseconds: 50));

    // Повторная проверка после задержки
    if (_mapboxMap == null || !mounted) {
      _isUpdatingMarkers = false;
      return;
    }

    if (updateToken != null && updateToken != _currentUpdateToken) {
      debugPrint('⚠️ Операция отменена после задержки');
      _isUpdatingMarkers = false;
      return;
    }

    try {
      _markerData.clear();
      // Сохраняем исходные маркеры для определения кластеров
      _allOriginalMarkers = List<Map<String, dynamic>>.unmodifiable(markers);

      if (markers.isEmpty) {
        await _removeGeoJsonSource();
        _isUpdatingMarkers = false;
        return;
      }

      debugPrint('📍 Настройка кластеризации: ${markers.length} маркеров');

      // Проверяем отмену операции перед началом работы
      if (updateToken != null && updateToken != _currentUpdateToken) {
        debugPrint('⚠️ Операция отменена перед началом работы');
        _isUpdatingMarkers = false;
        return;
      }

      // ── Конвертируем маркеры в GeoJSON
      final geoJsonString = _markersToGeoJson(markers);

      // ── Получаем стиль карты
      final style = _mapboxMap!.style;

      // ── Удаляем старый источник и слои перед созданием новых
      await _removeGeoJsonSource();

      // Проверяем отмену операции после удаления
      if (updateToken != null && updateToken != _currentUpdateToken) {
        debugPrint('⚠️ Операция отменена после удаления старого источника');
        _isUpdatingMarkers = false;
        return;
      }

      // ── Создаем GeoJSON source с кластеризацией
      final geoJsonSource = GeoJsonSource(
        id: _geoJsonSourceId,
        data: geoJsonString,
        cluster: true,
        clusterRadius: 30, // Радиус кластеризации в пикселях
        clusterMaxZoom: 14, // Максимальный zoom для кластеризации
        clusterMinPoints: 2, // Минимальное количество точек для кластера
      );

      await style.addSource(geoJsonSource);
      debugPrint('✅ GeoJSON source создан');

      // ── Создаем слой для кластеров (круги)
      // Используем условное выражение для цвета: красный для официальных, синий для обычных
      // Для кластеров используем базовый цвет, так как кластер может содержать смешанные события
      final clusterLayer = CircleLayer(
        id: _clusterLayerId,
        sourceId: _geoJsonSourceId,
        circleColor: markerColor.toARGB32(),
        circleRadius: 18.0,
        circleStrokeWidth: 1.0,
        circleStrokeColor: AppColors.border.toARGB32(),
      );

      // Фильтр: показываем только кластеры
      clusterLayer.filter = ['has', 'point_count'];

      await style.addLayer(clusterLayer);
      debugPrint('✅ Слой кластеров создан');

      // ── Создаем слой для текста кластеров
      // ВАЖНО: textField использует простой формат строки
      // Mapbox автоматически подставит значение point_count из свойств кластера
      final clusterTextLayer = SymbolLayer(
        id: _clusterTextLayerId,
        sourceId: _geoJsonSourceId,
        textField: '{point_count}', // Формат строки для отображения количества
        textSize: 17.0,
        textColor: AppColors.surface.toARGB32(),
        textFont: ['Open Sans Semibold', 'Arial Unicode MS Bold'],
      );

      // Фильтр: показываем только кластеры
      clusterTextLayer.filter = ['has', 'point_count'];

      await style.addLayer(clusterTextLayer);
      debugPrint('✅ Слой текста кластеров создан');

      // ── Создаем слой для отдельных точек (не кластеры)
      // Используем комбинацию CircleLayer (фон) и SymbolLayer (текст)
      // Создаем два слоя: один для официальных (красный), другой для обычных (синий)

      // Слой для обычных маркеров (синий)
      final unclusteredCircleLayer = CircleLayer(
        id: _unclusteredCircleLayerId,
        sourceId: _geoJsonSourceId,
        circleColor: markerColor.toARGB32(),
        circleRadius: 12.0, // Размер точки (как раньше)
        circleStrokeWidth: 1.0,
        circleStrokeColor: AppColors.border.toARGB32(),
      );

      // Фильтр: показываем только обычные точки без кластеризации
      unclusteredCircleLayer.filter = [
        'all',
        [
          '!',
          ['has', 'point_count'],
        ],
        [
          '!=',
          ['get', 'is_official'],
          true,
        ],
      ];

      await style.addLayer(unclusteredCircleLayer);

      // Слой для официальных маркеров (красный)
      final officialCircleLayer = CircleLayer(
        id: _officialCircleLayerId,
        sourceId: _geoJsonSourceId,
        circleColor: AppColors.error.toARGB32(), // Красный цвет для официальных
        circleRadius: 12.0, // Размер точки (как раньше)
        circleStrokeWidth: 1.0,
        circleStrokeColor: AppColors.border.toARGB32(),
      );

      // Фильтр: показываем только официальные точки без кластеризации
      officialCircleLayer.filter = [
        'all',
        [
          '!',
          ['has', 'point_count'],
        ],
        [
          '==',
          ['get', 'is_official'],
          true,
        ],
      ];

      await style.addLayer(officialCircleLayer);

      // Затем создаем слой для текста с количеством
      final unclusteredTextLayer = SymbolLayer(
        id: _unclusteredLayerId,
        sourceId: _geoJsonSourceId,
        textField: '{count}', // Отображаем количество из properties
        textSize: 14.0, // Размер текста (как в оригинальных маркерах)
        textColor: AppColors.surface.toARGB32(),
        textFont: ['Open Sans Semibold', 'Arial Unicode MS Bold'],
      );

      // Фильтр: показываем только точки без кластеризации
      unclusteredTextLayer.filter = [
        '!',
        ['has', 'point_count'],
      ];

      await style.addLayer(unclusteredTextLayer);
      debugPrint('✅ Слой отдельных точек создан (круг + текст)');

      // ── Подписываемся на клики по слоям
      await _setupLayerClickHandlers();
      debugPrint('✅ Кластеризация настроена успешно');
    } catch (e) {
      debugPrint('❌ Ошибка настройки маркеров с кластеризацией: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      // Fallback на старый метод, если кластеризация не работает
      await _setupMarkersFallback(markers, markerColor);
    } finally {
      _isUpdatingMarkers = false;
    }
  }

  /// ──────────── Удаление GeoJSON источника и слоев ────────────
  /// Безопасно удаляет все слои и источник перед созданием новых
  Future<void> _removeGeoJsonSource() async {
    if (_mapboxMap == null) return;

    try {
      final style = _mapboxMap!.style;

      // Удаляем слои в обратном порядке (сначала зависимые, потом базовые)
      // Это важно для правильного удаления без ошибок
      final layerIds = [
        _unclusteredLayerId, // Текст отдельных точек
        _officialCircleLayerId, // Круг официальных точек
        _unclusteredCircleLayerId, // Круг обычных точек
        _clusterTextLayerId, // Текст кластеров
        _clusterLayerId, // Круги кластеров
      ];

      for (final layerId in layerIds) {
        try {
          await style.removeStyleLayer(layerId);
          debugPrint('✅ Слой $layerId удален');
        } catch (e) {
          // Слой может не существовать - это нормально
          debugPrint('⚠️ Слой $layerId не найден или уже удален: $e');
        }
      }

      // Удаляем источник
      try {
        await style.removeStyleSource(_geoJsonSourceId);
        debugPrint('✅ GeoJSON источник удален');
      } catch (e) {
        // Источник может не существовать - это нормально
        debugPrint('⚠️ GeoJSON источник не найден или уже удален: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка при удалении GeoJSON источника: $e');
      // Продолжаем работу - при следующем добавлении слои будут перезаписаны
    }
  }

  /// ──────────── Настройка обработчиков кликов по слоям ────────────
  /// Обрабатывает клики по кластерам и отдельным точкам через GeoJSON слои
  Future<void> _setupLayerClickHandlers() async {
    if (_mapboxMap == null || !mounted) return;

    // Обработчики кликов уже настроены в MapWidget через onTapListener
    // Этот метод вызывается для логирования успешной настройки
    debugPrint('✅ Обработчики кликов для кластеризации настроены');
  }

  /// ──────────── Fallback: старый метод через PointAnnotationManager ────────────
  /// Используется, если кластеризация через GeoJSON не работает
  Future<void> _setupMarkersFallback(
    List<Map<String, dynamic>> markers,
    Color markerColor,
  ) async {
    if (_mapboxMap == null || !mounted) {
      debugPrint('⚠️ _setupMarkersFallback: карта не готова');
      return;
    }

    try {
      debugPrint('📍 Настройка маркеров: ${markers.length} маркеров');

      // ── Безопасное удаление старых маркеров
      if (_pointAnnotationManager != null) {
        try {
          await _pointAnnotationManager!.deleteAll();
        } catch (e) {
          debugPrint('⚠️ Менеджер аннотаций был уничтожен: $e');
          _pointAnnotationManager = null;
        }
      }

      // ── Создаем менеджер аннотаций, если его нет
      if (_pointAnnotationManager == null && _mapboxMap != null && mounted) {
        try {
          debugPrint('📍 Создание менеджера аннотаций...');
          _pointAnnotationManager = await _mapboxMap!.annotations
              .createPointAnnotationManager();
          if (_pointAnnotationManager != null && mounted) {
            _pointAnnotationManager!.tapEvents(
              onTap: (annotation) {
                _onMarkerTap(annotation);
              },
            );
            debugPrint('✅ Менеджер аннотаций создан успешно');
          }
        } catch (e) {
          debugPrint('❌ Ошибка создания менеджера аннотаций: $e');
          return;
        }
      }

      if (_pointAnnotationManager == null || _mapboxMap == null || !mounted) {
        debugPrint('⚠️ Менеджер аннотаций не готов');
        return;
      }

      _markerData.clear();

      if (markers.isEmpty) {
        debugPrint('⚠️ Нет маркеров для отображения');
        return;
      }

      // Создаем изображения маркеров
      // Используем разные цвета для официальных и обычных маркеров
      final imageMap = <String, Uint8List>{};
      for (final marker in markers) {
        try {
          final count = marker['count'] as int;
          final isOfficial = marker['is_official'] as bool? ?? false;
          // Используем красный цвет для официальных, синий для обычных
          final color = isOfficial ? AppColors.error : markerColor;
          final imageKey = 'marker_${color.toARGB32()}_$count';
          if (!imageMap.containsKey(imageKey)) {
            imageMap[imageKey] = await _createMarkerImage(color, '$count');
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
          final isOfficial = marker['is_official'] as bool? ?? false;
          // Используем красный цвет для официальных, синий для обычных
          final color = isOfficial ? AppColors.error : markerColor;
          final imageKey = 'marker_${color.toARGB32()}_$count';
          final imageBytes = imageMap[imageKey]!;

          final markerKey =
              '${point.latitude.toStringAsFixed(6)}_${point.longitude.toStringAsFixed(6)}';
          _markerData[markerKey] = marker;

          annotations.add(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(point.longitude, point.latitude),
              ),
              image: imageBytes,
              iconSize: 1.2,
            ),
          );
        } catch (e) {
          debugPrint('Ошибка создания аннотации: $e');
        }
      }

      if (annotations.isNotEmpty &&
          _pointAnnotationManager != null &&
          _mapboxMap != null &&
          mounted) {
        try {
          debugPrint('📍 Создание ${annotations.length} аннотаций...');
          await _pointAnnotationManager!.createMulti(annotations);
          debugPrint('✅ Аннотации созданы успешно');
        } catch (e) {
          debugPrint('❌ Ошибка создания аннотаций: $e');
          debugPrint('   Stack trace: ${StackTrace.current}');
        }
      } else {
        debugPrint(
          '⚠️ Не удалось создать аннотации: isEmpty=${annotations.isEmpty}, manager=${_pointAnnotationManager != null}, map=${_mapboxMap != null}, mounted=$mounted',
        );
      }
    } catch (e) {
      debugPrint('❌ Ошибка настройки маркеров (fallback): $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
    }
  }

  /// ──────────── Вспомогательная функция: конвертация Color в RGBA массив ────────────
  // ignore: unused_element
  List<int> _colorToRgbaArray(Color color) {
    return [
      (color.r * 255.0).round() & 0xff,
      (color.g * 255.0).round() & 0xff,
      (color.b * 255.0).round() & 0xff,
      (color.a * 255.0).round() & 0xff,
    ];
  }

  /// ──────────── Планировщик обновления маркеров ────────────
  /// Сохраняет данные и инициирует перерисовку, когда карта готова.
  /// Отменяет предыдущие операции при новом вызове
  void _queueMarkersUpdate(
    List<Map<String, dynamic>> markers,
    Color markerColor,
  ) {
    // Отменяем предыдущую операцию, создавая новый токен
    _currentUpdateToken = Object();
    _pendingMarkers = List<Map<String, dynamic>>.unmodifiable(markers);
    _pendingMarkerColor = markerColor;
    _applyPendingMarkersIfReady();
  }

  /// Запускает перерисовку маркеров, как только Mapbox и менеджер готовы.
  void _applyPendingMarkersIfReady() {
    if (!mounted || _mapboxMap == null || _pendingMarkerColor == null) {
      debugPrint(
        '⚠️ _applyPendingMarkersIfReady: не готово (mounted=$mounted, map=${_mapboxMap != null}, color=${_pendingMarkerColor != null})',
      );
      return;
    }

    // Если менеджер еще не создан, ждем немного и пробуем снова
    if (_pointAnnotationManager == null) {
      debugPrint('⚠️ Менеджер аннотаций еще не создан, ждем...');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _pendingMarkerColor != null) {
          _applyPendingMarkersIfReady();
        }
      });
      return;
    }

    debugPrint('📍 Применение маркеров: ${_pendingMarkers.length} маркеров');
    final currentToken = _currentUpdateToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingMarkerColor == null) return;
      _setupMarkers(
        _pendingMarkers,
        _pendingMarkerColor!,
        updateToken: currentToken,
      );
    });
  }

  /// ──────────── Обработка клика по карте (для GeoJSON слоев) ────────────
  /// Обрабатывает клики по кластерам и отдельным точкам через queryRenderedFeatures
  Future<void> _onMapTap(MapContentGestureContext context) async {
    if (_mapboxMap == null || !mounted) return;

    try {
      debugPrint('📍 Клик по карте: ${context.point.coordinates}');

      // Получаем координаты клика на карте (географические)
      final point = context.point;
      final lat = point.coordinates.lat;
      final lng = point.coordinates.lng;

      // Получаем координаты клика на экране
      final screenCoordinate = ScreenCoordinate(
        x: context.touchPosition.x,
        y: context.touchPosition.y,
      );

      // Создаем геометрию для запроса с небольшим радиусом для точности
      final queryGeometry = RenderedQueryGeometry.fromScreenCoordinate(
        screenCoordinate,
      );

      // Настраиваем опции запроса - проверяем все наши слои
      final options = RenderedQueryOptions(
        layerIds: [
          _clusterLayerId,
          _clusterTextLayerId,
          _officialCircleLayerId, // Официальные маркеры
          _unclusteredCircleLayerId, // Обычные маркеры
          _unclusteredLayerId,
        ],
      );

      // Запрашиваем features в точке клика
      final features = await _mapboxMap!.queryRenderedFeatures(
        queryGeometry,
        options,
      );

      debugPrint('📍 Найдено features: ${features.length}');

      if (features.isEmpty) {
        debugPrint('⚠️ Клик был не по маркеру');
        return;
      }

      // Берем первый найденный feature и проверяем его слой
      final queriedFeature = features.first;

      // Проверяем, какой слой был кликнут
      final layerIds = queriedFeature?.layers;
      if (layerIds == null || layerIds.isEmpty) {
        debugPrint('⚠️ Нет информации о слоях');
        return;
      }

      final clickedLayerId = layerIds.first;
      debugPrint('📍 Клик по слою: $clickedLayerId');

      // Если клик по кластеру, получаем все точки внутри и показываем bottom sheet
      if (clickedLayerId == _clusterLayerId ||
          clickedLayerId == _clusterTextLayerId) {
        debugPrint('📍 Клик по кластеру, координаты: $lat, $lng');
        try {
          // ────────────────────────────────────────────────────────────────
          // Подход как в Google Maps / Яндекс.Картах:
          // Определяем принадлежность маркеров к кластеру по экранным координатам
          // Это самый точный способ, используемый в крупных сервисах
          // ────────────────────────────────────────────────────────────────

          // Получаем экранные координаты центра кластера
          final clusterScreenPoint = ScreenCoordinate(
            x: context.touchPosition.x,
            y: context.touchPosition.y,
          );

          // Радиус кластера в пикселях (соответствует визуальному размеру)
          // clusterRadius = 30 пикселей (из настроек кластеризации)
          // Добавляем запас для надежности (40px = примерно радиус кластера + отступ)
          const clusterRadiusPixels = 40.0;

          debugPrint(
            '📍 Поиск маркеров в кластере по экранным координатам (радиус: ${clusterRadiusPixels}px)...',
          );

          // Собираем все события/клубы из маркеров, входящих в кластер
          final allEvents = <dynamic>[];
          final allClubs = <dynamic>[];
          final foundMarkerKeys = <String>{};
          String? clusterTitle;

          // Проходим по всем исходным маркерам (до кластеризации)
          for (final marker in _allOriginalMarkers) {
            final markerPoint = marker['point'] as latlong.LatLng?;
            if (markerPoint == null) continue;

            try {
              // Преобразуем географические координаты маркера в экранные координаты
              final markerMapPoint = Point(
                coordinates: Position(
                  markerPoint.longitude,
                  markerPoint.latitude,
                ),
              );

              final markerScreenPoint = await _mapboxMap!.pixelForCoordinate(
                markerMapPoint,
              );

              // Вычисляем расстояние в пикселях от центра кластера до маркера
              final dx = markerScreenPoint.x - clusterScreenPoint.x;
              final dy = markerScreenPoint.y - clusterScreenPoint.y;
              final distancePixels = (dx * dx + dy * dy);

              // Если маркер находится в пределах радиуса кластера
              if (distancePixels <= clusterRadiusPixels * clusterRadiusPixels) {
                // Формируем ключ маркера для проверки дубликатов
                final markerKey =
                    '${markerPoint.latitude.toStringAsFixed(6)}_${markerPoint.longitude.toStringAsFixed(6)}';

                if (!foundMarkerKeys.contains(markerKey)) {
                  foundMarkerKeys.add(markerKey);

                  // Собираем события
                  final events = marker['events'] as List<dynamic>?;
                  if (events != null) {
                    allEvents.addAll(events);
                  }

                  // Собираем клубы
                  final clubs = marker['clubs'] as List<dynamic>?;
                  if (clubs != null) {
                    allClubs.addAll(clubs);
                  }

                  // Используем заголовок первого маркера
                  clusterTitle ??= marker['title'] as String? ?? 'Маркеры';

                  debugPrint(
                    '📍 Маркер в кластере: $markerKey, расстояние: ${distancePixels.toStringAsFixed(1)}px',
                  );
                }
              }
            } catch (e) {
              // Если не удалось преобразовать координаты, пропускаем маркер
              debugPrint('⚠️ Ошибка преобразования координат маркера: $e');
              continue;
            }
          }

          debugPrint(
            '📍 Собрано событий: ${allEvents.length}, клубов: ${allClubs.length}, маркеров: ${foundMarkerKeys.length}',
          );

          if (allEvents.isEmpty && allClubs.isEmpty) {
            debugPrint('⚠️ Не найдено данных в кластере');
            return;
          }

          // Создаем объединенный маркер для bottom sheet
          final clusterMarker = <String, dynamic>{
            'point': latlong.LatLng(lat.toDouble(), lng.toDouble()),
            'title': clusterTitle ?? 'Маркеры',
            'count': allEvents.length + allClubs.length,
            'events': allEvents,
            'clubs': allClubs,
            'latitude': lat.toDouble(),
            'longitude': lng.toDouble(),
          };

          // Вычисляем позицию на экране для bottom sheet
          Offset? screenPosition;
          try {
            final pixelCoordinate = await _mapboxMap!.pixelForCoordinate(point);
            screenPosition = Offset(
              pixelCoordinate.x.toDouble(),
              pixelCoordinate.y.toDouble(),
            );
          } catch (e) {
            debugPrint('⚠️ Ошибка вычисления позиции кластера: $e');
          }

          // Показываем bottom sheet с объединенными данными
          _showMarkerBottomSheet(clusterMarker, screenPosition: screenPosition);
          debugPrint('✅ Bottom sheet для кластера показан');
        } catch (e) {
          debugPrint('❌ Ошибка обработки кластера: $e');
          debugPrint('   Stack trace: ${StackTrace.current}');
        }
        return;
      }

      // Если клик по отдельной точке, ищем маркер в _markerData
      // Используем поиск по ближайшим координатам с допуском
      Map<String, dynamic>? closestMarker;
      double minDistance = double.infinity;
      const tolerance =
          0.01; // Допуск для поиска маркера (примерно 1 км) - увеличен для лучшей работы кликов

      for (final entry in _markerData.entries) {
        final marker = entry.value;
        final markerPoint = marker['point'] as latlong.LatLng?;
        if (markerPoint == null) continue;

        // Вычисляем расстояние до маркера
        final distance = _calculateDistance(
          lat.toDouble(),
          lng.toDouble(),
          markerPoint.latitude.toDouble(),
          markerPoint.longitude.toDouble(),
        );

        // Если это ближайший маркер в радиусе клика
        if (distance < minDistance && distance < tolerance) {
          minDistance = distance;
          closestMarker = marker;
        }
      }

      // Если нашли маркер, показываем bottom sheet
      if (closestMarker != null) {
        debugPrint('📍 Найден маркер, расстояние: $minDistance');
        Offset? screenPosition;
        try {
          final markerPoint = closestMarker['point'] as latlong.LatLng;
          final mapPoint = Point(
            coordinates: Position(markerPoint.longitude, markerPoint.latitude),
          );
          final pixelCoordinate = await _mapboxMap!.pixelForCoordinate(
            mapPoint,
          );
          screenPosition = Offset(
            pixelCoordinate.x.toDouble(),
            pixelCoordinate.y.toDouble(),
          );
        } catch (e) {
          debugPrint('⚠️ Ошибка вычисления позиции маркера: $e');
        }

        _showMarkerBottomSheet(closestMarker, screenPosition: screenPosition);
        return;
      }

      debugPrint('⚠️ Маркер не найден для координат: $lat, $lng');
    } catch (e) {
      debugPrint('❌ Ошибка обработки клика по карте: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
    }
  }

  /// ──────────── Вычисление расстояния между двумя точками ────────────
  /// Использует простую формулу для вычисления расстояния в градусах
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    // Простое вычисление расстояния через разницу координат
    // Для точности можно использовать формулу гаверсинуса, но для наших целей достаточно
    final dLat = (lat1 - lat2).abs();
    final dLng = (lng1 - lng2).abs();
    return dLat * dLat + dLng * dLng;
  }

  /// Обработка клика по маркеру (для fallback метода через PointAnnotationManager)
  Future<void> _onMarkerTap(PointAnnotation annotation) async {
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

    Offset? screenPosition;
    if (_mapboxMap != null) {
      try {
        final screenCoordinate = await _mapboxMap!.pixelForCoordinate(
          Point(coordinates: Position(lng, lat)),
        );
        screenPosition = Offset(
          screenCoordinate.x.toDouble(),
          screenCoordinate.y.toDouble(),
        );
      } catch (e) {
        debugPrint('Ошибка вычисления позиции маркера: $e');
      }
    }

    _showMarkerBottomSheet(marker, screenPosition: screenPosition);
  }

  /// Обработка клика по маркеру (для flutter_map на macOS)
  void _onFlutterMapMarkerTap(Map<String, dynamic> marker) {
    _showMarkerBottomSheet(marker);
  }

  /// Показать bottom sheet для маркера
  void _showMarkerBottomSheet(
    Map<String, dynamic> marker, {
    Offset? screenPosition,
  }) {
    final title = marker['title'] as String;
    final dynamic events = marker['events'];
    final Widget? content = marker['content'] as Widget?;

    // ────────────────────────────────────────────────────────────────
    // 🔹 ОСОБЫЙ СЛУЧАЙ ДЛЯ КЛУБОВ: если count == 1, показываем попап
    // ────────────────────────────────────────────────────────────────
    if (_selectedIndex == 1) {
      final count = marker['count'] as int? ?? 0;
      final clubs = marker['clubs'] as List<dynamic>? ?? [];

      // Если клуб один — показываем попап
      if (count == 1 && clubs.isNotEmpty) {
        final club = clubs.first as Map<String, dynamic>;
        cpopup.ClubPopup.show(
          context,
          club: club,
          screenX: screenPosition?.dx,
          screenY: screenPosition?.dy,
        );
        return;
      }

      // Если клубов больше одного — показываем bottom sheet
      if (count > 1) {
        final Widget sheet = cbs.ClubsBottomSheet(
          title: title,
          child: clubs.isNotEmpty
              ? cbs.ClubsListFromApi(
                  clubs: clubs,
                  latitude: marker['latitude'] as double?,
                  longitude: marker['longitude'] as double?,
                )
              : content ?? const cbs.ClubsSheetPlaceholder(),
        );

        showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => sheet,
        ).then((result) {
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
        return;
      }
    }

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
          // Для клубов создаём виджет со списком клубов из API (fallback)
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
  Widget _buildFlutterMap(
    List<Map<String, dynamic>> markers,
    Color markerColor,
  ) {
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
          center = latlong.LatLng(
            sumLat / points.length,
            sumLng / points.length,
          );
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
            urlTemplate: AppConfig.mapTilesUrl.replaceAll(
              '{apiKey}',
              AppConfig.mapTilerApiKey,
            ),
            userAgentPackageName: 'com.example.paceup',
          ),
          flutter_map.MarkerLayer(
            markers: markers.map((marker) {
              final point = marker['point'] as latlong.LatLng?;
              if (point == null) {
                return const flutter_map.Marker(
                  point: latlong.LatLng(0, 0),
                  width: 0,
                  height: 0,
                  child: SizedBox.shrink(),
                );
              }

              final count = marker['count'] as int? ?? 0;
              final isOfficial = marker['is_official'] as bool? ?? false;
              // Используем красный цвет для официальных, синий для обычных
              final color = isOfficial ? AppColors.error : markerColor;

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
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1),
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

    // Обновляем маркеры при изменении данных (с гарантией после инициализации)
    _queueMarkersUpdate(markers, markerColor);

    return SizedBox.expand(
      child: MapWidget(
        key: ValueKey('map_screen_${_selectedIndex}_$_mapInitialized'),
        onTapListener: _onMapTap,
        onMapCreated: (MapboxMap mapboxMap) async {
          _mapboxMap = mapboxMap;

          // ────────────────────────── Отключаем масштабную линейку ──────────────────────────
          // Отключаем горизонтальную линию масштаба, которая отображается сверху слева
          try {
            await mapboxMap.scaleBar.updateSettings(
              ScaleBarSettings(enabled: false),
            );
          } catch (e) {
            // Если метод недоступен (для обратной совместимости), игнорируем ошибку
            debugPrint('⚠️ Не удалось отключить масштабную линейку: $e');
          }

          // ── Создаем менеджер аннотаций для маркеров
          try {
            debugPrint('📍 Создание менеджера аннотаций в onMapCreated...');
            _pointAnnotationManager = await mapboxMap.annotations
                .createPointAnnotationManager();
            if (_pointAnnotationManager != null && mounted) {
              _pointAnnotationManager!.tapEvents(
                onTap: (annotation) {
                  _onMarkerTap(annotation);
                },
              );
              debugPrint('✅ Менеджер аннотаций создан в onMapCreated');
            }
          } catch (e) {
            debugPrint(
              '❌ Ошибка создания менеджера аннотаций в onMapCreated: $e',
            );
          }

          // Сохраняем цвет/данные по умолчанию, если Future уже вернул маркеры
          _pendingMarkerColor ??= markerColor;
          if (_pendingMarkers.isEmpty && markers.isNotEmpty) {
            _pendingMarkers = List<Map<String, dynamic>>.unmodifiable(markers);
          }

          // Добавляем небольшую задержку для гарантии готовности карты
          await Future.delayed(const Duration(milliseconds: 300));
          _applyPendingMarkersIfReady();
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
                      // Если вкладка уже активна, выходим без пересборки,
                      // чтобы избежать повторной отрисовки маркеров и мерцаний
                      if (_selectedIndex == index) {
                        return;
                      }

                      // При реальном переключении вкладок обновляем маркеры
                      // НЕ сбрасываем _mapInitialized - карта должна оставаться инициализированной
                      // Это предотвращает пересоздание карты и зависания
                      setState(() {
                        _selectedIndex = index;
                      });
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
