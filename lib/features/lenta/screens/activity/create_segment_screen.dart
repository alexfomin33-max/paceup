// lib/features/lenta/screens/activity/create_segment_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран создания участка на маршруте тренировки.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/segments_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../map/services/marker_assets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 🔹 ОСНОВНОЙ ЭКРАН
// ─────────────────────────────────────────────────────────────────────────────

/// Экран для выбора начала и конца участка по треку.
class CreateSegmentScreen extends StatefulWidget {
  const CreateSegmentScreen({
    super.key,
    required this.points,
    required this.activityId,
    required this.userId,
    required this.activityType,
    this.elevationPerKm = const {},
  });

  /// Точки трека в порядке следования.
  final List<ll.LatLng> points;

  /// ID тренировки.
  final int activityId;

  /// ID пользователя, который создаёт участок.
  final int userId;

  /// Тип активности (run/bike и т.д.).
  final String activityType;

  /// Высота по километрам (для окраски трека).
  final Map<String, double> elevationPerKm;

  @override
  State<CreateSegmentScreen> createState() => _CreateSegmentScreenState();
}

class _CreateSegmentScreenState extends State<CreateSegmentScreen> {
  // ────────────────────────────────────────────────────────────────
  // 🔹 MAPBOX КОНТРОЛЛЕРЫ
  // ────────────────────────────────────────────────────────────────
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _trackPolylineManager;
  PolylineAnnotationManager? _segmentPolylineManager;
  PolylineAnnotationManager? _nearbySegmentsPolylineManager;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _startAnnotation;
  PointAnnotation? _endAnnotation;
  /// Маркеры старта и финиша маршрута (всегда на карте).
  PointAnnotation? _routeStartAnnotation;
  PointAnnotation? _routeEndAnnotation;
  PolylineAnnotation? _segmentAnnotation;
  final List<PolylineAnnotation> _nearbySegmentAnnotations = [];

  // ────────────────────────────────────────────────────────────────
  // 🔹 FLUTTER_MAP КОНТРОЛЛЕР
  // ────────────────────────────────────────────────────────────────
  final flutter_map.MapController _flutterMapController =
      flutter_map.MapController();

  // ────────────────────────────────────────────────────────────────
  // 🔹 ВНУТРЕННИЕ СОСТОЯНИЯ
  // ────────────────────────────────────────────────────────────────
  final ll.Distance _distance = const ll.Distance();
  List<double> _prefixDistancesM = [];
  List<double> _elevationValues = [];
  bool _isMapReady = false;
  bool _isSaving = false;
  String? _errorText;
  // ────────────────────────────────────────────────────────────────
  // 🔹 ДАННЫЕ ДЛЯ ПРОВЕРКИ ДУБЛЕЙ
  // ────────────────────────────────────────────────────────────────
  List<ActivitySegmentDuplicateItem> _existingSegments = [];
  // ────────────────────────────────────────────────────────────────
  // 🔹 ДАННЫЕ ДЛЯ ОТРИСОВКИ УЧАСТКОВ В ОБЛАСТИ
  // ────────────────────────────────────────────────────────────────
  List<ActivitySegmentMapItem> _nearbySegments = [];

  int? _startIndex;
  int? _endIndex;
  int? _startSegmentIndex;
  int? _endSegmentIndex;
  double? _startFraction;
  double? _endFraction;
  double? _startDistanceM;
  double? _endDistanceM;
  ll.LatLng? _startPoint;
  ll.LatLng? _endPoint;
  double? _distanceKm;

  Uint8List? _startMarkerImage;
  Uint8List? _endMarkerImage;
  /// Изображения маркеров «Старт» и «Финиш» маршрута.
  Uint8List? _routeStartMarkerImage;
  Uint8List? _routeEndMarkerImage;
  /// Изображение стрелки направления и аннотации на Mapbox.
  Uint8List? _arrowImage;
  List<PointAnnotation> _arrowAnnotations = [];

  // ────────────────────────────────────────────────────────────────
  // 🔹 НАСТРОЙКИ ОГРАНИЧЕНИЙ
  // ────────────────────────────────────────────────────────────────
  static const double _maxRunKm = 1.0;
  static const double _maxBikeKm = 5.0;
  static const double _maxSwimKm = 0.5;
  static const double _distanceEpsilonKm = 0.01;
  static const double _nearbySegmentsStrokeWidth = 4.0;
  static const double _nearbySegmentsAlpha = 0.9;
  // ────────────────────────────────────────────────────────────────
  // 🔹 ПОРОГ ПО ВЫСОТЕ: меньше — считаем участок «ровным»
  // ────────────────────────────────────────────────────────────────
  static const double _elevationThresholdM = 3.0;

  @override
  void initState() {
    super.initState();
    _buildPrefixDistances();
    _elevationValues = _parseElevationPerKm(widget.elevationPerKm);
    // ──────────────────────────────────────────────────────────────
    // 🔹 ПРЕДЗАГРУЗКА УЖЕ СОЗДАННЫХ УЧАСТКОВ
    // ──────────────────────────────────────────────────────────────
    _loadExistingSegments();
    // ──────────────────────────────────────────────────────────────
    // 🔹 ПРЕДЗАГРУЗКА УЧАСТКОВ В ОБЛАСТИ ТРЕКА
    // ──────────────────────────────────────────────────────────────
    _loadNearbySegments();
  }

  @override
  void didUpdateWidget(covariant CreateSegmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points ||
        oldWidget.points.length != widget.points.length) {
      _buildPrefixDistances();
      _loadNearbySegments();
    }
    if (oldWidget.elevationPerKm != widget.elevationPerKm) {
      _elevationValues = _parseElevationPerKm(widget.elevationPerKm);
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПРЕДЗАГРУЗКА УЧАСТКОВ ДЛЯ ПРОВЕРКИ ДУБЛЕЙ
  // ────────────────────────────────────────────────────────────────
  Future<void> _loadExistingSegments() async {
    try {
      final segments = await SegmentsService().getSegmentsForActivity(
        userId: widget.userId,
        activityId: widget.activityId,
      );
      if (!mounted) return;
      setState(() {
        _existingSegments = segments;
      });
    } catch (_) {
      // Ошибки загрузки сегментов игнорируем: проверка дублей
      // остаётся мягкой, а итоговое решение — на бэкенде.
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПРЕДЗАГРУЗКА УЧАСТКОВ В ОБЛАСТИ ТРЕКА
  // ────────────────────────────────────────────────────────────────
  Future<void> _loadNearbySegments() async {
    if (widget.points.isEmpty) return;
    final bounds = _boundsFromPoints(widget.points);
    try {
      final segments = await SegmentsService().getSegmentsByBbox(
        minLat: bounds.southwest.latitude,
        minLng: bounds.southwest.longitude,
        maxLat: bounds.northeast.latitude,
        maxLng: bounds.northeast.longitude,
        activityType: widget.activityType,
      );
      if (!mounted) return;
      setState(() {
        _nearbySegments = segments;
      });
      if (!Platform.isMacOS) {
        await _drawNearbySegmentsMapbox();
      }
    } catch (_) {
      // Ошибки загрузки участков по области игнорируем.
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 MAPBOX: ОТРИСОВКА УЧАСТКОВ В ОБЛАСТИ
  // ────────────────────────────────────────────────────────────────
  Future<void> _drawNearbySegmentsMapbox() async {
    if (_nearbySegmentsPolylineManager == null) return;
    try {
      await _nearbySegmentsPolylineManager!.deleteAll();
    } catch (_) {
      // Игнорируем ошибки удаления.
    }
    _nearbySegmentAnnotations.clear();

    if (_nearbySegments.isEmpty) return;

    final color = AppColors.orange
        .withValues(alpha: _nearbySegmentsAlpha)
        .toARGB32();

    for (final segment in _nearbySegments) {
      if (segment.points.length < 2) continue;
      final coordinates = segment.points
          .map((p) => Position(p.longitude, p.latitude))
          .toList();
      final ann = await _nearbySegmentsPolylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coordinates),
          lineColor: color,
          lineWidth: _nearbySegmentsStrokeWidth,
        ),
      );
      _nearbySegmentAnnotations.add(ann);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ПРОВЕРКА НАЛИЧИЯ ТОЧЕК
    // ────────────────────────────────────────────────────────────────
    if (widget.points.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: const Center(child: Text('Нет точек маршрута')),
      );
    }

    final center = _centerFromPoints(widget.points);
    final bounds = _boundsFromPoints(widget.points);
    final instruction = _buildInstructionText();

    // ────────────────────────────────────────────────────────────────
    // 🔹 ОСНОВНОЙ LAYOUT
    // ────────────────────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: Stack(
        children: [
          _buildMap(center, bounds),
          const _MapBackButton(),
          _SegmentInfoPanel(
            instruction: instruction,
            distanceKm: _distanceKm,
            isSaving: _isSaving,
            errorText: _errorText,
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 КАРТА: ВЫБОР ДВУХ ТОЧЕК
  // ────────────────────────────────────────────────────────────────
  Widget _buildMap(ll.LatLng center, _LatLngBounds bounds) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 macOS: используем flutter_map
    // ────────────────────────────────────────────────────────────────
    if (Platform.isMacOS) {
      return flutter_map.FlutterMap(
        mapController: _flutterMapController,
        options: flutter_map.MapOptions(
          initialCenter: center,
          initialZoom: 12.0,
          minZoom: 3.0,
          maxZoom: 18.0,
          onTap: (tapPos, latLng) {
            _handleTapPoint(latLng);
          },
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
          flutter_map.MarkerLayer(
            markers: _buildFlutterMapArrowMarkers(),
          ),
          flutter_map.MarkerLayer(
            markers: _buildFlutterMapMarkers(),
          ),
        ],
      );
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 Android/iOS: используем Mapbox
    // ────────────────────────────────────────────────────────────────
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.getBackgroundColor(context),
        ),
        AnimatedOpacity(
          opacity: _isMapReady ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: MapWidget(
            key: ValueKey(
              'create_segment_${widget.activityId}_${widget.points.length}',
            ),
            onTapListener: _onMapTap,
            onMapCreated: (MapboxMap mapboxMap) async {
              _mapboxMap = mapboxMap;
              await _prepareMapbox(mapboxMap, bounds);
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

  // ────────────────────────────────────────────────────────────────
  // 🔹 MAPBOX: ИНИЦИАЛИЗАЦИЯ КАРТЫ
  // ────────────────────────────────────────────────────────────────
  Future<void> _prepareMapbox(
    MapboxMap mapboxMap,
    _LatLngBounds bounds,
  ) async {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ОТКЛЮЧАЕМ ЛИНЕЙКУ
    // ────────────────────────────────────────────────────────────────
    try {
      await mapboxMap.scaleBar.updateSettings(
        ScaleBarSettings(enabled: false),
      );
    } catch (_) {
      // Игнорируем ошибки совместимости.
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ДАЁМ КАРТЕ ВРЕМЯ НА ИНИЦИАЛИЗАЦИЮ
    // ────────────────────────────────────────────────────────────────
    await Future.delayed(const Duration(milliseconds: 300));

    // ────────────────────────────────────────────────────────────────
    // 🔹 СОЗДАЁМ МЕНЕДЖЕРЫ АННОТАЦИЙ
    // ────────────────────────────────────────────────────────────────
    try {
      _trackPolylineManager =
          await mapboxMap.annotations.createPolylineAnnotationManager();
      _segmentPolylineManager =
          await mapboxMap.annotations.createPolylineAnnotationManager();
      _nearbySegmentsPolylineManager =
          await mapboxMap.annotations.createPolylineAnnotationManager();
      _pointAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
    } catch (_) {
      // Игнорируем ошибки создания менеджеров.
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 РИСУЕМ ТРЕК
    // ────────────────────────────────────────────────────────────────
    await _drawTrackPolyline();

    // ────────────────────────────────────────────────────────────────
    // 🔹 РИСУЕМ УЧАСТКИ В ОБЛАСТИ
    // ────────────────────────────────────────────────────────────────
    await _drawNearbySegmentsMapbox();

    // ────────────────────────────────────────────────────────────────
    // 🔹 МАРКЕРЫ СТАРТА И ФИНИША МАРШРУТА
    // ────────────────────────────────────────────────────────────────
    await _drawRouteStartEndMarkers();

    // ────────────────────────────────────────────────────────────────
    // 🔹 СТРЕЛКИ НАПРАВЛЕНИЯ ВДОЛЬ МАРШРУТА
    // ────────────────────────────────────────────────────────────────
    await _drawArrowMarkers();

    // ────────────────────────────────────────────────────────────────
    // 🔹 ПОДСТРАИВАЕМ КАМЕРУ ПОД ГРАНИЦЫ
    // ────────────────────────────────────────────────────────────────
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
        MbxEdgeInsets(
          top: AppSpacing.md,
          left: AppSpacing.md,
          bottom: AppSpacing.md,
          right: AppSpacing.md,
        ),
        null,
        null,
        null,
        null,
      );
      await mapboxMap.setCamera(camera);
    } catch (_) {
      // Если камера не готова — оставляем исходные настройки.
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ПОКАЗЫВАЕМ КАРТУ
    // ────────────────────────────────────────────────────────────────
    if (mounted) {
      setState(() {
        _isMapReady = true;
      });
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ОБНОВЛЯЕМ МАРКЕРЫ И УЧАСТОК (ЕСЛИ УЖЕ ВЫБРАНО)
    // ────────────────────────────────────────────────────────────────
    await _refreshSelectionVisuals();
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 MAPBOX: ОТРИСОВКА ОСНОВНОГО ТРЕКА
  // ────────────────────────────────────────────────────────────────
  Future<void> _drawTrackPolyline() async {
    if (_trackPolylineManager == null || widget.points.isEmpty) {
      return;
    }

    try {
      await _trackPolylineManager!.deleteAll();

      // ──────────────────────────────────────────────────────────────
      // 🔹 ТРЕК ОДИН ЦВЕТ (СИНИЙ) — БЕЗ ОКРАСКИ ПО ВЫСОТЕ
      // ──────────────────────────────────────────────────────────────
      final coordinates = widget.points
          .map((p) => Position(p.longitude, p.latitude))
          .toList();
      await _trackPolylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coordinates),
          lineColor: AppColors.brandPrimary.toARGB32(),
          lineWidth: 3.0,
        ),
      );
    } catch (_) {
      // Игнорируем ошибки отрисовки.
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 MAPBOX: КЛИК ПО КАРТЕ
  // ────────────────────────────────────────────────────────────────
  Future<void> _onMapTap(MapContentGestureContext context) async {
    final lat = context.point.coordinates.lat;
    final lng = context.point.coordinates.lng;
    await _handleTapPoint(
      ll.LatLng(lat.toDouble(), lng.toDouble()),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ОБРАБОТКА ТАПА: ВЫБОР НАЧАЛА И КОНЦА
  // ────────────────────────────────────────────────────────────────
  Future<void> _handleTapPoint(ll.LatLng tapPoint) async {
    if (_isSaving) return;

    // ────────────────────────────────────────────────────────────────
    // 🔹 ПРИВЯЗКА К ТРЕКУ (SNAP)
    // ────────────────────────────────────────────────────────────────
    final snap = _snapToRoute(tapPoint);
    if (snap == null) {
      if (mounted) {
        setState(() {
          _errorText = 'Не удалось привязать точку к треку';
        });
      }
      return;
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ПЕРВЫЙ ТАП: СТАРТ
    // ────────────────────────────────────────────────────────────────
    if (_startIndex == null || _endIndex != null) {
      if (mounted) {
        setState(() {
          _startIndex = snap.index;
          _startSegmentIndex = snap.segmentIndex;
          _startFraction = snap.fraction;
          _startPoint = snap.point;
          _startDistanceM =
              _distanceAtSegment(snap.segmentIndex, snap.fraction);
          _endIndex = null;
          _endSegmentIndex = null;
          _endFraction = null;
          _endPoint = null;
          _endDistanceM = null;
          _distanceKm = null;
          _errorText = null;
        });
      }
      await _refreshSelectionVisuals();
      return;
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ВТОРОЙ ТАП: ФИНИШ
    // ────────────────────────────────────────────────────────────────
    if (_startIndex != null && _endIndex == null) {
      // ──────────────────────────────────────────────────────────────
      // 🔹 ЗАЩИТА ОТ ОДИНАКОВЫХ ТОЧЕК
      // ──────────────────────────────────────────────────────────────
      if (mounted) {
        setState(() {
          _endIndex = snap.index;
          _endSegmentIndex = snap.segmentIndex;
          _endFraction = snap.fraction;
          _endPoint = snap.point;
          _endDistanceM =
              _distanceAtSegment(snap.segmentIndex, snap.fraction);
          _errorText = null;
        });
      }

      final distanceMeters = _calculateDistanceMeters();
      if (distanceMeters != null && distanceMeters < 1) {
        if (mounted) {
          setState(() {
            _errorText = 'Начало и конец участка должны различаться';
          });
        }
        return;
      }

      final distanceKm = _calculateDistanceKm();
      if (mounted) {
        setState(() {
          _distanceKm = distanceKm;
        });
      }

      await _refreshSelectionVisuals();

      final validationError = _validateDistance(distanceKm);
      if (validationError != null) {
        if (mounted) {
          setState(() {
            _errorText = validationError;
          });
        }
        return;
      }

      // ──────────────────────────────────────────────────────────────
      // 🔹 ПРОВЕРКА ДУБЛЕЙ ПО СТАРТУ/ФИНИШУ И ПО РАССТОЯНИЮ ОТ ЛИНИИ
      // ──────────────────────────────────────────────────────────────
      final selection = _normalizedSelection();
      if (selection != null) {
        final duplicateError = _validateDuplicate(selection);
        if (duplicateError != null) {
          if (mounted) {
            setState(() {
              _errorText = duplicateError;
            });
          }
          return;
        }
        final duplicateNearby = _validateDuplicateNearbyByStartEnd(selection);
        if (duplicateNearby != null) {
          if (mounted) {
            setState(() {
              _errorText = duplicateNearby;
            });
          }
          return;
        }
        final segmentPoints = _buildSegmentPolylinePoints(selection);
        final duplicateByDist = _validateDuplicateByDistance(segmentPoints);
        if (duplicateByDist != null) {
          if (mounted) {
            setState(() {
              _errorText = duplicateByDist;
            });
          }
          return;
        }
      }

      final name = await _showSaveDialog(distanceKm);
      if (name == null) return;

      // Значение участка для имени (2 знака) — то же отправляем на бэкенд в real_distance_km.
      final realDistanceKm =
          double.parse(distanceKm.toStringAsFixed(2));
      await _createSegment(name: name, realDistanceKm: realDistanceKm);
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ДИАЛОГ СОХРАНЕНИЯ
  // ────────────────────────────────────────────────────────────────
  Future<String?> _showSaveDialog(double distanceKm) async {
    final defaultName = 'Участок: ${distanceKm.toStringAsFixed(2)} км';
    final controller = TextEditingController(text: defaultName);

    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(ctx),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Сохранить участок',
                        style: AppTextStyles.h18w6.copyWith(
                          color: AppColors.getTextPrimaryColor(ctx),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${distanceKm.toStringAsFixed(2)} км',
                        style: AppTextStyles.h14w4.copyWith(
                          color: AppColors.getTextSecondaryColor(ctx),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Название участка',
                          hintStyle: TextStyle(
                            color: AppColors.getTextSecondaryColor(ctx),
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        onChanged: (_) {
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(
                                'Отмена',
                                style: TextStyle(
                                  color: AppColors.getTextSecondaryColor(
                                    ctx,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final raw = controller.text.trim();
                                Navigator.of(ctx).pop(
                                  raw.isEmpty ? defaultName : raw,
                                );
                              },
                              child: const Text('Сохранить'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 СОХРАНЕНИЕ УЧАСТКА ЧЕРЕЗ API
  // ────────────────────────────────────────────────────────────────
  Future<void> _createSegment({
    required String name,
    required double realDistanceKm,
  }) async {
    final selection = _normalizedSelection();
    if (selection == null) return;

    if (mounted) {
      setState(() {
        _isSaving = true;
        _errorText = null;
      });
    }

    final segmentPoints = _buildSegmentPolylinePoints(selection);

    try {
      await SegmentsService().createSegment(
        userId: widget.userId,
        activityId: widget.activityId,
        startIndex: selection.startIndex,
        endIndex: selection.endIndex,
        startFraction: selection.startFraction,
        endFraction: selection.endFraction,
        name: name,
        realDistanceKm: realDistanceKm,
        segmentPoints: segmentPoints.length >= 2 ? segmentPoints : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop('Участок сохранён');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText.rich(
            TextSpan(
              text: 'Ошибка: ${e.message}',
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Не удалось сохранить участок';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText.rich(
            TextSpan(
              text: 'Ошибка: не удалось сохранить участок',
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ВЫЧИСЛЕНИЕ ДИСТАНЦИИ УЧАСТКА
  // ────────────────────────────────────────────────────────────────
  double _calculateDistanceKm() {
    final meters = _calculateDistanceMeters();
    if (meters == null) return 0;
    return meters / 1000.0;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПРОВЕРКА ЛИМИТОВ ПО ТИПУ АКТИВНОСТИ
  // ────────────────────────────────────────────────────────────────
  String? _validateDistance(double distanceKm) {
    final minKm = _minDistanceKmForType(widget.activityType);
    if (minKm != null && distanceKm < minKm - _distanceEpsilonKm) {
      return 'Минимальная длина участка: ${_formatLimit(minKm)}';
    }

    final maxKm = _maxDistanceKmForType(widget.activityType);
    if (maxKm == null) return null;

    if (distanceKm <= maxKm + _distanceEpsilonKm) return null;

    return 'Превышена длина участка: максимум ${_formatLimit(maxKm)}';
  }

  double? _minDistanceKmForType(String type) {
    final normalized = type.trim().toLowerCase();
    if ([
      'run',
      'indoor-running',
      'ski',
      'skiing',
    ].contains(normalized)) {
      return 0.1;
    }
    if ([
      'bike',
      'indoor-cycling',
      'cycling',
      'bicycle',
    ].contains(normalized)) {
      return 0.5;
    }
    if ([
      'walking',
      'walk',
      'hiking',
    ].contains(normalized)) {
      return 0.05;
    }
    return null;
  }

  double? _maxDistanceKmForType(String type) {
    final normalized = type.trim().toLowerCase();
    if ([
      'run',
      'indoor-running',
      'walking',
      'walk',
      'hiking',
      'ski',
      'skiing',
    ].contains(normalized)) {
      return _maxRunKm;
    }
    if (['swim', 'swimming'].contains(normalized)) {
      return _maxSwimKm;
    }
    if ([
      'bike',
      'indoor-cycling',
      'cycling',
      'bicycle',
    ].contains(normalized)) {
      return _maxBikeKm;
    }
    return null;
  }

  String _formatLimit(double km) {
    if (km < 1) {
      final meters = (km * 1000).round();
      return '$meters м';
    }
    return '${km.toStringAsFixed(0)} км';
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПРОВЕРКА ДУБЛЕЙ ПО СТАРТУ И ФИНИШУ
  // ────────────────────────────────────────────────────────────────
  String? _validateDuplicate(_SegmentSelection selection) {
    // ──────────────────────────────────────────────────────────────
    // 🔹 ОПРЕДЕЛЯЕМ ПОРОГИ ПО ТИПУ АКТИВНОСТИ
    // ──────────────────────────────────────────────────────────────
    final toleranceM = _duplicatePointToleranceM(widget.activityType);
    if (toleranceM == null) return null;
    if (_existingSegments.isEmpty) return null;

    // ──────────────────────────────────────────────────────────────
    // 🔹 СУММАРНЫЙ ПОРОГ ДЛЯ ДВУХ ТОЧЕК
    // ──────────────────────────────────────────────────────────────
    final totalToleranceM = toleranceM * 2.0;

    // ──────────────────────────────────────────────────────────────
    // 🔹 СРАВНИВАЕМ С КАЖДЫМ СУЩЕСТВУЮЩИМ УЧАСТКОМ
    // ──────────────────────────────────────────────────────────────
    for (final segment in _existingSegments) {
      final startPoint = _safePointAtSegment(
        segment.startIndex,
        segment.startFraction,
      );
      final endPoint = _safePointAtSegment(
        segment.endIndex,
        segment.endFraction,
      );
      if (startPoint == null || endPoint == null) continue;

      final startDeltaM = _distance(selection.startPoint, startPoint);
      final endDeltaM = _distance(selection.endPoint, endPoint);
      final totalDeltaM = startDeltaM + endDeltaM;

      // ────────────────────────────────────────────────────────────
      // 🔹 ДУБЛЬ: ОБЕ ТОЧКИ И СУММА В ДОПУСКЕ
      // ────────────────────────────────────────────────────────────
      if (startDeltaM <= toleranceM &&
          endDeltaM <= toleranceM &&
          totalDeltaM <= totalToleranceM) {
        return 'Такой участок уже существует';
      }
    }

    return null;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ДУБЛЬ ПО СТАРТУ/ФИНИШУ СРЕДИ УЧАСТКОВ В ОБЛАСТИ (100/200, 300/600, 50/100 М)
  // ────────────────────────────────────────────────────────────────
  String? _validateDuplicateNearbyByStartEnd(_SegmentSelection selection) {
    final toleranceM = _duplicatePointToleranceM(widget.activityType);
    if (toleranceM == null) return null;
    if (_nearbySegments.isEmpty) return null;

    final totalToleranceM = toleranceM * 2.0;

    for (final segment in _nearbySegments) {
      if (segment.points.length < 2) continue;
      final theirStart = segment.points.first;
      final theirEnd = segment.points.last;

      final startDeltaM = _distance(selection.startPoint, theirStart);
      final endDeltaM = _distance(selection.endPoint, theirEnd);
      if (startDeltaM <= toleranceM &&
          endDeltaM <= toleranceM &&
          (startDeltaM + endDeltaM) <= totalToleranceM) {
        return 'Такой участок уже существует';
      }

      final startDeltaRev = _distance(selection.startPoint, theirEnd);
      final endDeltaRev = _distance(selection.endPoint, theirStart);
      if (startDeltaRev <= toleranceM &&
          endDeltaRev <= toleranceM &&
          (startDeltaRev + endDeltaRev) <= totalToleranceM) {
        return 'Такой участок уже существует';
      }
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ДУБЛЬ ПО РАДИУСУ 10 М ОТ ЛИНИИ СУЩЕСТВУЮЩЕГО УЧАСТКА
  // ────────────────────────────────────────────────────────────────
  static const double _duplicatePolylineRadiusM = 10.0;

  String? _validateDuplicateByDistance(List<ll.LatLng> segmentPoints) {
    if (segmentPoints.length < 2 || _nearbySegments.isEmpty) {
      return null;
    }
    for (final existing in _nearbySegments) {
      if (existing.points.length < 2) continue;
      final distM = _polylineToPolylineDistanceM(
        segmentPoints,
        existing.points,
      );
      if (distM < _duplicatePolylineRadiusM) {
        return 'Такой участок уже существует';
      }
    }
    return null;
  }

  double _pointToPolylineDistanceM(ll.LatLng point, List<ll.LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) return _distance(point, polyline.first);
    double minDist = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final d = _distanceToSegmentM(
        point,
        polyline[i],
        polyline[i + 1],
      );
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  double _distanceToSegmentM(
    ll.LatLng p,
    ll.LatLng a,
    ll.LatLng b,
  ) {
    final proj = _projectToSegment(p, a, b);
    return _distance(proj.point, p);
  }

  double _polylineToPolylineDistanceM(
    List<ll.LatLng> a,
    List<ll.LatLng> b,
  ) {
    double maxA = 0;
    for (final p in a) {
      final d = _pointToPolylineDistanceM(p, b);
      if (d > maxA) maxA = d;
    }
    double maxB = 0;
    for (final p in b) {
      final d = _pointToPolylineDistanceM(p, a);
      if (d > maxB) maxB = d;
    }
    return maxA > maxB ? maxA : maxB;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПОРОГ ПОГРЕШНОСТИ ДЛЯ ТОЧЕК СТАРТА/ФИНИША
  // ────────────────────────────────────────────────────────────────
  double? _duplicatePointToleranceM(String type) {
    final normalized = type.trim().toLowerCase();
    if ([
      'run',
      'indoor-running',
      'ski',
      'skiing',
    ].contains(normalized)) {
      return 100.0;
    }
    if ([
      'bike',
      'indoor-cycling',
      'cycling',
      'bicycle',
    ].contains(normalized)) {
      return 300.0;
    }
    if ([
      'walking',
      'walk',
      'hiking',
    ].contains(normalized)) {
      return 50.0;
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 БЕЗОПАСНАЯ ТОЧКА НА СЕГМЕНТЕ (С CLAMP FRACTION)
  // ────────────────────────────────────────────────────────────────
  ll.LatLng? _safePointAtSegment(int segmentIndex, double fraction) {
    if (segmentIndex < 0 || segmentIndex >= widget.points.length - 1) {
      return null;
    }
    final t = fraction.clamp(0.0, 1.0);
    final a = widget.points[segmentIndex];
    final b = widget.points[segmentIndex + 1];
    return ll.LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 SNAP TO ROUTE: ПРИВЯЗКА ТОЧКИ К ТРЕКУ
  // ────────────────────────────────────────────────────────────────
  _SnapResult? _snapToRoute(ll.LatLng tapPoint) {
    if (widget.points.length < 2) return null;

    double bestDistance = double.infinity;
    int bestSegmentIndex = 0;
    double bestFraction = 0;
    ll.LatLng bestPoint = widget.points.first;

    for (int i = 0; i < widget.points.length - 1; i++) {
      final a = widget.points[i];
      final b = widget.points[i + 1];
      final projection = _projectToSegment(tapPoint, a, b);
      final distance = _distance(projection.point, tapPoint);

      if (distance < bestDistance) {
        bestDistance = distance;
        bestSegmentIndex = i;
        bestFraction = projection.fraction;
        bestPoint = projection.point;
      }
    }

    final snappedIndex =
        bestFraction >= 0.5 ? bestSegmentIndex + 1 : bestSegmentIndex;

    return _SnapResult(
      index: snappedIndex,
      segmentIndex: bestSegmentIndex,
      fraction: bestFraction,
      point: bestPoint,
    );
  }

  _ProjectionResult _projectToSegment(
    ll.LatLng p,
    ll.LatLng a,
    ll.LatLng b,
  ) {
    final ax = a.latitude;
    final ay = a.longitude;
    final bx = b.latitude;
    final by = b.longitude;
    final px = p.latitude;
    final py = p.longitude;

    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;

    if (len2 == 0) {
      return _ProjectionResult(point: a, fraction: 0);
    }

    final t = ((px - ax) * dx + (py - ay) * dy) / len2;
    final clamped = t.clamp(0.0, 1.0);
    final projected = ll.LatLng(
      ax + clamped * dx,
      ay + clamped * dy,
    );

    return _ProjectionResult(
      point: projected,
      fraction: clamped,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ВИЗУАЛИЗАЦИЯ: МАРКЕРЫ И УЧАСТОК
  // ────────────────────────────────────────────────────────────────
  Future<void> _refreshSelectionVisuals() async {
    if (!Platform.isMacOS) {
      await _updateMapboxMarkers();
      await _updateMapboxSegment();
    }
  }

  Future<void> _updateMapboxMarkers() async {
    if (_pointAnnotationManager == null) return;

    await _ensureMarkerImages();

    // ──────────────────────────────────────────────────────────────
    // 🔹 ОБНОВЛЕНИЕ МАРКЕРА СТАРТА
    // ──────────────────────────────────────────────────────────────
    final startPoint = _startPoint ??
        (_startIndex != null ? widget.points[_startIndex!] : null);
    if (startPoint == null) {
      if (_startAnnotation != null) {
        await _pointAnnotationManager!.delete(_startAnnotation!);
        _startAnnotation = null;
      }
    } else if (_startMarkerImage != null) {
      if (_startAnnotation == null) {
        _startAnnotation = await _pointAnnotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(startPoint.longitude, startPoint.latitude),
            ),
            image: _startMarkerImage!,
            iconSize: 1.0,
          ),
        );
      } else {
        _startAnnotation!.geometry = Point(
          coordinates: Position(startPoint.longitude, startPoint.latitude),
        );
        await _pointAnnotationManager!.update(_startAnnotation!);
      }
    }

    // ──────────────────────────────────────────────────────────────
    // 🔹 ОБНОВЛЕНИЕ МАРКЕРА ФИНИША
    // ──────────────────────────────────────────────────────────────
    final endPoint =
        _endPoint ?? (_endIndex != null ? widget.points[_endIndex!] : null);
    if (endPoint == null) {
      if (_endAnnotation != null) {
        await _pointAnnotationManager!.delete(_endAnnotation!);
        _endAnnotation = null;
      }
    } else if (_endMarkerImage != null) {
      if (_endAnnotation == null) {
        _endAnnotation = await _pointAnnotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(endPoint.longitude, endPoint.latitude),
            ),
            image: _endMarkerImage!,
            iconSize: 1.0,
          ),
        );
      } else {
        _endAnnotation!.geometry = Point(
          coordinates: Position(endPoint.longitude, endPoint.latitude),
        );
        await _pointAnnotationManager!.update(_endAnnotation!);
      }
    }
  }

  Future<void> _updateMapboxSegment() async {
    if (_segmentPolylineManager == null) return;

    final selection = _normalizedSelection();
    if (selection == null) {
      if (_segmentAnnotation != null) {
        await _segmentPolylineManager!.delete(_segmentAnnotation!);
        _segmentAnnotation = null;
      }
      return;
    }

    final segmentPoints = _buildSegmentPolylinePoints(selection);

    if (segmentPoints.length < 2) return;

    final coordinates = segmentPoints
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    if (_segmentAnnotation == null) {
      _segmentAnnotation = await _segmentPolylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coordinates),
          lineColor: AppColors.brandPrimary.toARGB32(),
          lineWidth: 5.0,
        ),
      );
    } else {
      _segmentAnnotation!.geometry = LineString(coordinates: coordinates);
      await _segmentPolylineManager!.update(_segmentAnnotation!);
    }
  }

  Future<void> _ensureMarkerImages() async {
    if (_startMarkerImage == null) {
      _startMarkerImage = await MarkerAssets.createMarkerImage(
        AppColors.brandPrimary,
        '1',
      );
    }
    if (_endMarkerImage == null) {
      _endMarkerImage = await MarkerAssets.createMarkerImage(
        AppColors.brandPrimary,
        '2',
      );
    }
  }

  /// Маркеры «Старт» (зелёный) и «Финиш» (красный) для начала и конца маршрута.
  Future<void> _ensureRouteMarkerImages() async {
    if (_routeStartMarkerImage == null) {
      _routeStartMarkerImage = await MarkerAssets.createMarkerImage(
        AppColors.success,
        'С',
      );
    }
    if (_routeEndMarkerImage == null) {
      _routeEndMarkerImage = await MarkerAssets.createMarkerImage(
        AppColors.error,
        'Ф',
      );
    }
  }

  /// Отрисовка точек старта и финиша маршрута на Mapbox (всегда видны).
  Future<void> _drawRouteStartEndMarkers() async {
    if (_pointAnnotationManager == null || widget.points.length < 2) {
      return;
    }
    await _ensureRouteMarkerImages();
    if (_routeStartMarkerImage == null || _routeEndMarkerImage == null) return;

    final first = widget.points.first;
    final last = widget.points.last;

    if (_routeStartAnnotation == null) {
      _routeStartAnnotation = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(first.longitude, first.latitude),
          ),
          image: _routeStartMarkerImage!,
          iconSize: 1.0,
        ),
      );
    } else {
      _routeStartAnnotation!.geometry = Point(
        coordinates: Position(first.longitude, first.latitude),
      );
      await _pointAnnotationManager!.update(_routeStartAnnotation!);
    }

    if (_routeEndAnnotation == null) {
      _routeEndAnnotation = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(last.longitude, last.latitude),
          ),
          image: _routeEndMarkerImage!,
          iconSize: 1.0,
        ),
      );
    } else {
      _routeEndAnnotation!.geometry = Point(
        coordinates: Position(last.longitude, last.latitude),
      );
      await _pointAnnotationManager!.update(_routeEndAnnotation!);
    }
  }

  /// Позиции и азимуты для стрелок направления (каждые ~300 м по маршруту).
  List<({ll.LatLng point, double bearingDeg})> _computeArrowPositions() {
    if (widget.points.length < 2 || _prefixDistancesM.length != widget.points.length) {
      return [];
    }
    const stepM = 300.0;
    final totalM = _prefixDistancesM.last;
    if (totalM < stepM) return [];
    final out = <({ll.LatLng point, double bearingDeg})>[];
    for (var d = stepM; d < totalM; d += stepM) {
      final idx = _indexAtDistanceM(d);
      if (idx == null || idx >= widget.points.length - 1) continue;
      final p = widget.points[idx];
      final next = widget.points[idx + 1];
      final bearing = _bearingDegrees(p, next);
      out.add((point: _pointAtDistanceM(d), bearingDeg: bearing));
    }
    return out;
  }

  int? _indexAtDistanceM(double distanceM) {
    for (int i = 0; i < _prefixDistancesM.length - 1; i++) {
      if (_prefixDistancesM[i] <= distanceM && distanceM < _prefixDistancesM[i + 1]) {
        return i;
      }
    }
    return null;
  }

  ll.LatLng _pointAtDistanceM(double distanceM) {
    final idx = _indexAtDistanceM(distanceM);
    if (idx == null || idx >= widget.points.length - 1) {
      return widget.points.first;
    }
    final t = (distanceM - _prefixDistancesM[idx]) /
        (_prefixDistancesM[idx + 1] - _prefixDistancesM[idx]);
    final a = widget.points[idx];
    final b = widget.points[idx + 1];
    return ll.LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Азимут от [from] к [to] в градусах (0 = север, 90 = восток).
  double _bearingDegrees(ll.LatLng from, ll.LatLng to) {
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    var b = math.atan2(y, x) * 180 / math.pi;
    return (b + 360) % 360;
  }

  /// Отрисовка стрелок направления на Mapbox.
  Future<void> _drawArrowMarkers() async {
    if (_pointAnnotationManager == null || widget.points.length < 2) return;
    for (final a in _arrowAnnotations) {
      await _pointAnnotationManager!.delete(a);
    }
    _arrowAnnotations = [];
    _arrowImage ??= await MarkerAssets.createArrowImage();
    if (_arrowImage == null) return;
    final positions = _computeArrowPositions();
    for (final pos in positions) {
      final ann = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              pos.point.longitude,
              pos.point.latitude,
            ),
          ),
          image: _arrowImage!,
          iconSize: 0.8,
          iconRotate: pos.bearingDeg,
        ),
      );
      _arrowAnnotations.add(ann);
    }
  }

  /// Стрелки направления для flutter_map (macOS).
  List<flutter_map.Marker> _buildFlutterMapArrowMarkers() {
    final positions = _computeArrowPositions();
    return positions
        .map(
          (pos) => flutter_map.Marker(
            point: pos.point,
            width: 20,
            height: 20,
            child: Transform.rotate(
              angle: (pos.bearingDeg - 90) * math.pi / 180,
              child: const Icon(
                CupertinoIcons.arrow_up,
                color: AppColors.brandPrimary,
                size: 20,
              ),
            ),
          ),
        )
        .toList();
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 FLUTTER_MAP: ПОЛИЛИНИИ И МАРКЕРЫ
  // ────────────────────────────────────────────────────────────────
  List<flutter_map.Polyline> _buildFlutterMapPolylines() {
    final polylines = <flutter_map.Polyline>[];

    // ──────────────────────────────────────────────────────────────
    // 🔹 ТРЕК ОДИН ЦВЕТ (СИНИЙ) — БЕЗ ОКРАСКИ ПО ВЫСОТЕ
    // ──────────────────────────────────────────────────────────────
    polylines.add(
      flutter_map.Polyline(
        points: widget.points,
        strokeWidth: 3.0,
        color: AppColors.brandPrimary,
      ),
    );

    // ──────────────────────────────────────────────────────────────
    // 🔹 УЧАСТКИ В ОБЛАСТИ ТРЕКА
    // ──────────────────────────────────────────────────────────────
    if (_nearbySegments.isNotEmpty) {
      final color = AppColors.orange.withValues(
        alpha: _nearbySegmentsAlpha,
      );
      for (final segment in _nearbySegments) {
        if (segment.points.length < 2) continue;
        polylines.add(
          flutter_map.Polyline(
            points: segment.points,
            strokeWidth: _nearbySegmentsStrokeWidth,
            color: color,
          ),
        );
      }
    }

    final selection = _normalizedSelection();
    if (selection != null) {
      final segmentPoints = _buildSegmentPolylinePoints(selection);
      if (segmentPoints.length >= 2) {
        polylines.add(
          flutter_map.Polyline(
            points: segmentPoints,
            strokeWidth: 5.0,
            color: AppColors.brandPrimary,
          ),
        );
      }
    }

    return polylines;
  }

  List<flutter_map.Marker> _buildFlutterMapMarkers() {
    final markers = <flutter_map.Marker>[];

    // ──────────────────────────────────────────────────────────────
    // 🔹 СТАРТ И ФИНИШ МАРШРУТА (всегда: «С» зелёный, «Ф» красный)
    // ──────────────────────────────────────────────────────────────
    if (widget.points.length >= 2) {
      markers.add(
        _buildFlutterMapMarker(
          point: widget.points.first,
          label: 'С',
          color: AppColors.success,
        ),
      );
      markers.add(
        _buildFlutterMapMarker(
          point: widget.points.last,
          label: 'Ф',
          color: AppColors.error,
        ),
      );
    }

    final startPoint = _startPoint ??
        (_startIndex != null ? widget.points[_startIndex!] : null);
    if (startPoint != null) {
      markers.add(
        _buildFlutterMapMarker(
          point: startPoint,
          label: '1',
          color: AppColors.brandPrimary,
        ),
      );
    }

    final endPoint =
        _endPoint ?? (_endIndex != null ? widget.points[_endIndex!] : null);
    if (endPoint != null) {
      markers.add(
        _buildFlutterMapMarker(
          point: endPoint,
          label: '2',
          color: AppColors.brandPrimary,
        ),
      );
    }

    return markers;
  }

  flutter_map.Marker _buildFlutterMapMarker({
    required ll.LatLng point,
    required String label,
    Color color = AppColors.brandPrimary,
  }) {
    return flutter_map.Marker(
      point: point,
      width: AppSpacing.xl,
      height: AppSpacing.xl,
      child: Container(
        width: AppSpacing.xl,
        height: AppSpacing.xl,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.h14w6.copyWith(
            color: AppColors.surface,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ИНСТРУКЦИИ ДЛЯ ПОЛЬЗОВАТЕЛЯ
  // ────────────────────────────────────────────────────────────────
  String _buildInstructionText() {
    if (_startIndex == null) {
      return 'Тапните начало участка';
    }
    if (_endIndex == null) {
      return 'Тапните конец участка';
    }
    return 'Тапните снова, чтобы выбрать новое начало';
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ВСПОМОГАТЕЛЬНЫЕ ХЕЛПЕРЫ
  // ────────────────────────────────────────────────────────────────
  double? _calculateDistanceMeters() {
    if (_startDistanceM == null || _endDistanceM == null) {
      return null;
    }
    return (_endDistanceM! - _startDistanceM!).abs();
  }

  double _distanceAtSegment(int segmentIndex, double fraction) {
    if (segmentIndex < 0 || segmentIndex >= widget.points.length - 1) {
      return 0;
    }

    final segmentLength = _distance(
      widget.points[segmentIndex],
      widget.points[segmentIndex + 1],
    );

    if (_prefixDistancesM.length == widget.points.length &&
        _prefixDistancesM.isNotEmpty) {
      return _prefixDistancesM[segmentIndex] + segmentLength * fraction;
    }

    double meters = 0;
    for (int i = 1; i <= segmentIndex; i++) {
      meters += _distance(widget.points[i - 1], widget.points[i]);
    }
    return meters + segmentLength * fraction;
  }

  ll.LatLng _pointAtSegment(int segmentIndex, double fraction) {
    final a = widget.points[segmentIndex];
    final b = widget.points[segmentIndex + 1];
    return ll.LatLng(
      a.latitude + (b.latitude - a.latitude) * fraction,
      a.longitude + (b.longitude - a.longitude) * fraction,
    );
  }

  _SegmentSelection? _normalizedSelection() {
    if (_startSegmentIndex == null ||
        _endSegmentIndex == null ||
        _startFraction == null ||
        _endFraction == null ||
        _startDistanceM == null ||
        _endDistanceM == null) {
      return null;
    }

    final rawStartPoint = _startPoint ??
        _pointAtSegment(_startSegmentIndex!, _startFraction!);
    final rawEndPoint =
        _endPoint ?? _pointAtSegment(_endSegmentIndex!, _endFraction!);

    if (_endDistanceM! >= _startDistanceM!) {
      return _SegmentSelection(
        startIndex: _startSegmentIndex!,
        endIndex: _endSegmentIndex!,
        startFraction: _startFraction!,
        endFraction: _endFraction!,
        startDistanceM: _startDistanceM!,
        endDistanceM: _endDistanceM!,
        startPoint: rawStartPoint,
        endPoint: rawEndPoint,
      );
    }

    return _SegmentSelection(
      startIndex: _endSegmentIndex!,
      endIndex: _startSegmentIndex!,
      startFraction: _endFraction!,
      endFraction: _startFraction!,
      startDistanceM: _endDistanceM!,
      endDistanceM: _startDistanceM!,
      startPoint: rawEndPoint,
      endPoint: rawStartPoint,
    );
  }

  List<ll.LatLng> _buildSegmentPolylinePoints(_SegmentSelection selection) {
    final points = <ll.LatLng>[selection.startPoint];
    for (int i = selection.startIndex + 1;
        i <= selection.endIndex;
        i++) {
      points.add(widget.points[i]);
    }
    points.add(selection.endPoint);
    return points;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ОКРАСКА ТРЕКА ПО ВЫСОТЕ
  // ────────────────────────────────────────────────────────────────
  bool _canColorByElevation() {
    final type = widget.activityType.toLowerCase();
    final isSwim = type == 'swim' || type == 'swimming';
    return !isSwim && _elevationValues.length >= 2;
  }

  // ignore: unused_element — оставлено на случай возврата окраски по высоте
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

  ll.LatLng _centerFromPoints(List<ll.LatLng> pts) {
    double lat = 0;
    double lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    final n = pts.length.toDouble();
    return ll.LatLng(lat / n, lng / n);
  }

  _LatLngBounds _boundsFromPoints(List<ll.LatLng> pts) {
    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;

    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return _LatLngBounds(
      ll.LatLng(minLat, minLng),
      ll.LatLng(maxLat, maxLng),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПРЕФИКСНЫЕ ДИСТАНЦИИ ДЛЯ O(1) РАСЧЁТА
  // ────────────────────────────────────────────────────────────────
  void _buildPrefixDistances() {
    // ──────────────────────────────────────────────────────────────
    // 🔹 ЕСЛИ ТОЧЕК НЕТ — ПУСТОЙ СПИСОК
    // ──────────────────────────────────────────────────────────────
    if (widget.points.isEmpty) {
      _prefixDistancesM = [];
      return;
    }

    // ──────────────────────────────────────────────────────────────
    // 🔹 СЧИТАЕМ НАКОПЛЕННУЮ ДИСТАНЦИЮ В МЕТРАХ
    // ──────────────────────────────────────────────────────────────
    _prefixDistancesM =
        List<double>.filled(widget.points.length, 0, growable: false);
    for (int i = 1; i < widget.points.length; i++) {
      _prefixDistancesM[i] = _prefixDistancesM[i - 1] +
          _distance(widget.points[i - 1], widget.points[i]);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🔹 UI-БЛОКИ
// ─────────────────────────────────────────────────────────────────────────────

class _MapBackButton extends StatelessWidget {
  const _MapBackButton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          top: AppSpacing.md,
        ),
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
    );
  }
}

class _SegmentInfoPanel extends StatelessWidget {
  const _SegmentInfoPanel({
    required this.instruction,
    required this.distanceKm,
    required this.isSaving,
    required this.errorText,
  });

  final String instruction;
  final double? distanceKm;
  final bool isSaving;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: AppSpacing.md,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.getBorderColor(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Создание участка',
                style: AppTextStyles.h16w6.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                instruction,
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
              if (distanceKm != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Длина: ${distanceKm!.toStringAsFixed(2)} км',
                  style: AppTextStyles.h14w6.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ],
              if (isSaving) ...[
                const SizedBox(height: AppSpacing.sm),
                const CupertinoActivityIndicator(),
              ],
              if (errorText != null && errorText!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                SelectableText.rich(
                  TextSpan(
                    text: errorText,
                    style: AppTextStyles.h14w4.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🔹 ВНУТРЕННИЕ ТИПЫ
// ─────────────────────────────────────────────────────────────────────────────

class _LatLngBounds {
  const _LatLngBounds(this.southwest, this.northeast);

  final ll.LatLng southwest;
  final ll.LatLng northeast;
}

class _SnapResult {
  const _SnapResult({
    required this.index,
    required this.segmentIndex,
    required this.fraction,
    required this.point,
  });

  final int index;
  final int segmentIndex;
  final double fraction;
  final ll.LatLng point;
}

class _ProjectionResult {
  const _ProjectionResult({
    required this.point,
    required this.fraction,
  });

  final ll.LatLng point;
  final double fraction;
}

class _SegmentSelection {
  const _SegmentSelection({
    required this.startIndex,
    required this.endIndex,
    required this.startFraction,
    required this.endFraction,
    required this.startDistanceM,
    required this.endDistanceM,
    required this.startPoint,
    required this.endPoint,
  });

  final int startIndex;
  final int endIndex;
  final double startFraction;
  final double endFraction;
  final double startDistanceM;
  final double endDistanceM;
  final ll.LatLng startPoint;
  final ll.LatLng endPoint;
}

class _ColoredSegment {
  const _ColoredSegment({
    required this.points,
    required this.color,
  });

  final List<ll.LatLng> points;
  final Color color;
}

