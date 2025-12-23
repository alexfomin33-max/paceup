import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import '../../../core/theme/app_theme.dart';
import '../constants/map_layer_ids.dart';
import '../services/map_fit_service.dart';
import '../services/marker_assets.dart';
import '../views/map_view.dart';
import '../views/map_view_mac.dart';
import '../widgets/map_tabs_widget.dart';

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

  /// ID источника/слоев для кластеризации (читаем из константного файла)
  static const String _geoJsonSourceId = MapLayerIds.geoJsonSourceId;
  static const String _clusterLayerId = MapLayerIds.clusterLayerId;
  static const String _clusterTextLayerId = MapLayerIds.clusterTextLayerId;
  static const String _unclusteredLayerId = MapLayerIds.unclusteredLayerId;
  static const String _unclusteredCircleLayerId =
      MapLayerIds.unclusteredCircleLayerId;
  static const String _officialCircleLayerId =
      MapLayerIds.officialCircleLayerId;

  /// Цвета маркеров по вкладкам
  final markerColors = const {
    0: AppColors.accentBlue, // события
    1: AppColors.accentPurple, // клубы
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
      if (kDebugMode) {
        debugPrint('⚠️ Операция обновления маркеров отменена (новый токен)');
      }
      return;
    }

    // Предотвращаем параллельные операции
    if (_isUpdatingMarkers) {
      if (kDebugMode) {
        debugPrint('⚠️ Обновление маркеров уже выполняется, пропускаем');
      }
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
      if (kDebugMode) {
        debugPrint('⚠️ Операция отменена после задержки');
      }
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

      if (kDebugMode) {
        debugPrint('📍 Настройка кластеризации: ${markers.length} маркеров');
      }

      // Проверяем отмену операции перед началом работы
      if (updateToken != null && updateToken != _currentUpdateToken) {
        if (kDebugMode) {
          debugPrint('⚠️ Операция отменена перед началом работы');
        }
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
        if (kDebugMode) {
          debugPrint('⚠️ Операция отменена после удаления старого источника');
        }
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
      if (kDebugMode) {
        debugPrint('✅ GeoJSON source создан');
      }

      // ── Создаем слой для кластеров (круги)
      // Используем условное выражение для цвета: красный для официальных, синий для обычных
      // Для кластеров используем базовый цвет, так как кластер может содержать смешанные события
      final clusterLayer = CircleLayer(
        id: _clusterLayerId,
        sourceId: _geoJsonSourceId,
        circleColor: markerColor.toARGB32(),
        circleRadius:
            12.0, // Размер кластера такой же, как у отдельных маркеров
        circleStrokeWidth: 1.0,
        circleStrokeColor: AppColors.border.toARGB32(),
      );

      // Фильтр: показываем только кластеры
      clusterLayer.filter = ['has', 'point_count'];

      await style.addLayer(clusterLayer);
      if (kDebugMode) {
        debugPrint('✅ Слой кластеров создан');
      }

      // ── Создаем слой для текста кластеров
      // ВАЖНО: textField использует простой формат строки
      // Mapbox автоматически подставит значение point_count из свойств кластера
      final clusterTextLayer = SymbolLayer(
        id: _clusterTextLayerId,
        sourceId: _geoJsonSourceId,
        textField: '{point_count}', // Формат строки для отображения количества
        textSize: 14.0,
        textColor: AppColors.surface.toARGB32(),
        textFont: ['Open Sans Semibold', 'Arial Unicode MS Bold'],
      );

      // Фильтр: показываем только кластеры
      clusterTextLayer.filter = ['has', 'point_count'];

      await style.addLayer(clusterTextLayer);
      if (kDebugMode) {
        debugPrint('✅ Слой текста кластеров создан');
      }

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
      if (kDebugMode) {
        debugPrint('✅ Слой отдельных точек создан (круг + текст)');
      }

      // ── Подписываемся на клики по слоям
      await _setupLayerClickHandlers();
      if (kDebugMode) {
        debugPrint('✅ Кластеризация настроена успешно');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Ошибка настройки маркеров с кластеризацией: $e');
        debugPrint('   Stack trace: ${StackTrace.current}');
      }
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
          if (kDebugMode) {
            debugPrint('✅ Слой $layerId удален');
          }
        } catch (e) {
          // Слой может не существовать - это нормально
          if (kDebugMode) {
            debugPrint('⚠️ Слой $layerId не найден или уже удален: $e');
          }
        }
      }

      // Удаляем источник
      try {
        await style.removeStyleSource(_geoJsonSourceId);
        if (kDebugMode) {
          debugPrint('✅ GeoJSON источник удален');
        }
      } catch (e) {
        // Источник может не существовать - это нормально
        if (kDebugMode) {
          debugPrint('⚠️ GeoJSON источник не найден или уже удален: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Ошибка при удалении GeoJSON источника: $e');
      }
      // Продолжаем работу - при следующем добавлении слои будут перезаписаны
    }
  }

  /// ──────────── Настройка обработчиков кликов по слоям ────────────
  /// Обрабатывает клики по кластерам и отдельным точкам через GeoJSON слои
  Future<void> _setupLayerClickHandlers() async {
    if (_mapboxMap == null || !mounted) return;

    // Обработчики кликов уже настроены в MapWidget через onTapListener
    // Этот метод вызывается для логирования успешной настройки
    if (kDebugMode) {
      debugPrint('✅ Обработчики кликов для кластеризации настроены');
    }
  }

  /// ──────────── Fallback: старый метод через PointAnnotationManager ────────────
  /// Используется, если кластеризация через GeoJSON не работает
  Future<void> _setupMarkersFallback(
    List<Map<String, dynamic>> markers,
    Color markerColor,
  ) async {
    if (_mapboxMap == null || !mounted) {
      if (kDebugMode) {
        debugPrint('⚠️ _setupMarkersFallback: карта не готова');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('📍 Настройка маркеров: ${markers.length} маркеров');
      }

      // ── Безопасное удаление старых маркеров
      if (_pointAnnotationManager != null) {
        try {
          await _pointAnnotationManager!.deleteAll();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Менеджер аннотаций был уничтожен: $e');
          }
          _pointAnnotationManager = null;
        }
      }

      // ── Создаем менеджер аннотаций, если его нет
      if (_pointAnnotationManager == null && _mapboxMap != null && mounted) {
        try {
          if (kDebugMode) {
            debugPrint('📍 Создание менеджера аннотаций...');
          }
          _pointAnnotationManager = await _mapboxMap!.annotations
              .createPointAnnotationManager();
          if (_pointAnnotationManager != null && mounted) {
            _pointAnnotationManager!.tapEvents(
              onTap: (annotation) {
                _onMarkerTap(annotation);
              },
            );
            if (kDebugMode) {
              debugPrint('✅ Менеджер аннотаций создан успешно');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Ошибка создания менеджера аннотаций: $e');
          }
          return;
        }
      }

      if (_pointAnnotationManager == null || _mapboxMap == null || !mounted) {
        if (kDebugMode) {
          debugPrint('⚠️ Менеджер аннотаций не готов');
        }
        return;
      }

      _markerData.clear();

      if (markers.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ Нет маркеров для отображения');
        }
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
            imageMap[imageKey] = await MarkerAssets.createMarkerImage(
              color,
              '$count',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Ошибка создания изображения маркера: $e');
          }
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
          if (kDebugMode) {
            debugPrint('Ошибка создания аннотации: $e');
          }
        }
      }

      if (annotations.isNotEmpty &&
          _pointAnnotationManager != null &&
          _mapboxMap != null &&
          mounted) {
        try {
          if (kDebugMode) {
            debugPrint('📍 Создание ${annotations.length} аннотаций...');
          }
          await _pointAnnotationManager!.createMulti(annotations);
          if (kDebugMode) {
            debugPrint('✅ Аннотации созданы успешно');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Ошибка создания аннотаций: $e');
            debugPrint('   Stack trace: ${StackTrace.current}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Не удалось создать аннотации: isEmpty=${annotations.isEmpty}, manager=${_pointAnnotationManager != null}, map=${_mapboxMap != null}, mounted=$mounted',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Ошибка настройки маркеров (fallback): $e');
        debugPrint('   Stack trace: ${StackTrace.current}');
      }
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
      if (kDebugMode) {
        debugPrint(
          '⚠️ _applyPendingMarkersIfReady: не готово (mounted=$mounted, map=${_mapboxMap != null}, color=${_pendingMarkerColor != null})',
        );
      }
      return;
    }

    // Если менеджер еще не создан, ждем немного и пробуем снова
    if (_pointAnnotationManager == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Менеджер аннотаций еще не создан, ждем...');
      }
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _pendingMarkerColor != null) {
          _applyPendingMarkersIfReady();
        }
      });
      return;
    }

    if (kDebugMode) {
      debugPrint('📍 Применение маркеров: ${_pendingMarkers.length} маркеров');
    }
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
      if (kDebugMode) {
        debugPrint('📍 Клик по карте: ${context.point.coordinates}');
      }

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

      if (kDebugMode) {
        debugPrint('📍 Найдено features: ${features.length}');
      }

      if (features.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ Клик был не по маркеру');
        }
        return;
      }

      // Берем первый найденный feature и проверяем его слой
      final queriedFeature = features.first;

      // Проверяем, какой слой был кликнут
      final layerIds = queriedFeature?.layers;
      if (layerIds == null || layerIds.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ Нет информации о слоях');
        }
        return;
      }

      final clickedLayerId = layerIds.first;
      if (kDebugMode) {
        debugPrint('📍 Клик по слою: $clickedLayerId');
      }

      // Если клик по кластеру, получаем все точки внутри и показываем bottom sheet
      if (clickedLayerId == _clusterLayerId ||
          clickedLayerId == _clusterTextLayerId) {
        if (kDebugMode) {
          debugPrint('📍 Клик по кластеру, координаты: $lat, $lng');
        }
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

          if (kDebugMode) {
            debugPrint(
              '📍 Поиск маркеров в кластере по экранным координатам (радиус: ${clusterRadiusPixels}px)...',
            );
          }

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

                  if (kDebugMode) {
                    debugPrint(
                      '📍 Маркер в кластере: $markerKey, расстояние: ${distancePixels.toStringAsFixed(1)}px',
                    );
                  }
                }
              }
            } catch (e) {
              // Если не удалось преобразовать координаты, пропускаем маркер
              if (kDebugMode) {
                debugPrint('⚠️ Ошибка преобразования координат маркера: $e');
              }
              continue;
            }
          }

          if (kDebugMode) {
            debugPrint(
              '📍 Собрано событий: ${allEvents.length}, клубов: ${allClubs.length}, маркеров: ${foundMarkerKeys.length}',
            );
          }

          if (allEvents.isEmpty && allClubs.isEmpty) {
            if (kDebugMode) {
              debugPrint('⚠️ Не найдено данных в кластере');
            }
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
            if (kDebugMode) {
              debugPrint('⚠️ Ошибка вычисления позиции кластера: $e');
            }
          }

          // Показываем bottom sheet с объединенными данными
          _showMarkerBottomSheet(clusterMarker, screenPosition: screenPosition);
          if (kDebugMode) {
            debugPrint('✅ Bottom sheet для кластера показан');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Ошибка обработки кластера: $e');
            debugPrint('   Stack trace: ${StackTrace.current}');
          }
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
        final distance = MapFitService.calculateDistance(
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
        if (kDebugMode) {
          debugPrint('📍 Найден маркер, расстояние: $minDistance');
        }
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
          if (kDebugMode) {
            debugPrint('⚠️ Ошибка вычисления позиции маркера: $e');
          }
        }

        _showMarkerBottomSheet(closestMarker, screenPosition: screenPosition);
        return;
      }

      if (kDebugMode) {
        debugPrint('⚠️ Маркер не найден для координат: $lat, $lng');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Ошибка обработки клика по карте: $e');
        debugPrint('   Stack trace: ${StackTrace.current}');
      }
    }
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
      if (kDebugMode) {
        debugPrint('Маркер не найден для координат: $lat, $lng');
      }
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
        if (kDebugMode) {
          debugPrint('Ошибка вычисления позиции маркера: $e');
        }
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

    final Widget sheet = () {
      switch (_selectedIndex) {
        case 0:
          // Для событий создаём виджет со списком событий из API
          return ebs.EventsBottomSheet(
            title: 'Предстоящие события',
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
      // ── если событие было удалено, обновляем маркеры на карте
      if (result == 'event_deleted' && mounted) {
        setState(() {
          _mapInitialized = false;
          _eventsMarkersKey = ValueKey(
            'events_markers_${DateTime.now().millisecondsSinceEpoch}',
          );
        });
      }
      // ── если событие было обновлено (изменены координаты/адрес), обновляем маркеры на карте
      if (result == 'event_updated' && mounted) {
        setState(() {
          _mapInitialized = false;
          _eventsMarkersKey = ValueKey(
            'events_markers_${DateTime.now().millisecondsSinceEpoch}',
          );
        });
      }
      // ── если клуб был удалён, обновляем маркеры на карте
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
                  if (kDebugMode) {
                    debugPrint('Ошибка загрузки маркеров: ${snapshot.error}');
                  }
                }

                // Автоматическая подстройка zoom отключена для Событий и Клубов
                // Пользователь может самостоятельно управлять масштабом карты

                return _buildMap(markers, markerColor);
              },
            ),
            MapTabsWidget(
              tabs: tabs,
              selectedIndex: _selectedIndex,
              onSelect: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
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
      MapFitService.fitBoundsToMarkers(_mapboxMap, markers);
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
          MapTabsWidget(
            tabs: tabs,
            selectedIndex: _selectedIndex,
            onSelect: (index) {
              setState(() {
                _selectedIndex = index;
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
          // if (_selectedIndex == 2) const cch.CoachesFloatingButtons(), // тренеры - временно закомментировано
          // if (_selectedIndex == 3) const trv.TravelersFloatingButtons(), // попутчики - временно закомментировано
        ],
      ),
    );
  }

  Widget _buildMap(List<Map<String, dynamic>> markers, Color markerColor) {
    // Проверяем поддержку платформы - используем flutter_map для macOS
    if (Platform.isMacOS) {
      return MapViewMac(
        markers: markers,
        markerColor: markerColor,
        mapController: _flutterMapController,
        mapInitialized: _mapInitialized,
        onMarkerTap: _onFlutterMapMarkerTap,
        selectedIndex: _selectedIndex,
      );
    }

    // Обновляем маркеры при изменении данных (с гарантией после инициализации)
    _queueMarkersUpdate(markers, markerColor);

    return MapView(
      mapKey: ValueKey('map_screen_${_selectedIndex}_$_mapInitialized'),
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
          if (kDebugMode) {
            debugPrint('⚠️ Не удалось отключить масштабную линейку: $e');
          }
        }

        // ── Создаем менеджер аннотаций для маркеров
        try {
          if (kDebugMode) {
            debugPrint('📍 Создание менеджера аннотаций в onMapCreated...');
          }
          _pointAnnotationManager = await mapboxMap.annotations
              .createPointAnnotationManager();
          if (_pointAnnotationManager != null && mounted) {
            _pointAnnotationManager!.tapEvents(
              onTap: (annotation) {
                _onMarkerTap(annotation);
              },
            );
            if (kDebugMode) {
              debugPrint('✅ Менеджер аннотаций создан в onMapCreated');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              '❌ Ошибка создания менеджера аннотаций в onMapCreated: $e',
            );
          }
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
    );
  }
}
