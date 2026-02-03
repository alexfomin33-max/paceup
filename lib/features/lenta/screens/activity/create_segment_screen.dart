// lib/features/lenta/screens/activity/create_segment_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран создания участка на маршруте тренировки.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
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
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _startAnnotation;
  PointAnnotation? _endAnnotation;
  PolylineAnnotation? _segmentAnnotation;

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

  // ────────────────────────────────────────────────────────────────
  // 🔹 НАСТРОЙКИ ОГРАНИЧЕНИЙ
  // ────────────────────────────────────────────────────────────────
  static const double _maxRunKm = 1.0;
  static const double _maxBikeKm = 5.0;
  static const double _maxSwimKm = 0.5;
  static const double _distanceEpsilonKm = 0.01;
  // ────────────────────────────────────────────────────────────────
  // 🔹 ПОРОГ ПО ВЫСОТЕ: меньше — считаем участок «ровным»
  // ────────────────────────────────────────────────────────────────
  static const double _elevationThresholdM = 3.0;

  @override
  void initState() {
    super.initState();
    _buildPrefixDistances();
    _elevationValues = _parseElevationPerKm(widget.elevationPerKm);
  }

  @override
  void didUpdateWidget(covariant CreateSegmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points ||
        oldWidget.points.length != widget.points.length) {
      _buildPrefixDistances();
    }
    if (oldWidget.elevationPerKm != widget.elevationPerKm) {
      _elevationValues = _parseElevationPerKm(widget.elevationPerKm);
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
          // ────────────────────────────────────────────────────────────────
          // 🔹 ЛЕГЕНДА ВЫСОТЫ: подъём/спуск (если есть данные высоты)
          // ────────────────────────────────────────────────────────────────
          if (_canColorByElevation())
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: SafeArea(
                child: _ElevationLegend(
                  upColor: AppColors.error,
                  downColor: AppColors.success,
                ),
              ),
            ),
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
      // 🔹 ЕСЛИ НЕТ ДАННЫХ ВЫСОТЫ — РИСУЕМ ОДИН ЦВЕТ
      // ──────────────────────────────────────────────────────────────
      if (!_canColorByElevation()) {
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
        return;
      }

      // ──────────────────────────────────────────────────────────────
      // 🔹 РИСУЕМ УЧАСТКИ С РАЗНЫМИ ЦВЕТАМИ
      // ──────────────────────────────────────────────────────────────
      final segments = _buildColoredSegments();
      for (final segment in segments) {
        final coordinates = segment.points
            .map((p) => Position(p.longitude, p.latitude))
            .toList();
        await _trackPolylineManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coordinates),
            lineColor: segment.color.toARGB32(),
            lineWidth: 3.0,
          ),
        );
      }
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

      final name = await _showSaveDialog(distanceKm);
      if (name == null) return;

      await _createSegment(name: name);
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
  Future<void> _createSegment({required String name}) async {
    final selection = _normalizedSelection();
    if (selection == null) return;

    if (mounted) {
      setState(() {
        _isSaving = true;
        _errorText = null;
      });
    }

    try {
      await SegmentsService().createSegment(
        userId: widget.userId,
        activityId: widget.activityId,
        startIndex: selection.startIndex,
        endIndex: selection.endIndex,
        startFraction: selection.startFraction,
        endFraction: selection.endFraction,
        name: name,
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
    final maxKm = _maxDistanceKmForType(widget.activityType);
    if (maxKm == null) return null;

    if (distanceKm <= maxKm + _distanceEpsilonKm) return null;

    return 'Превышена длина участка: максимум ${_formatLimit(maxKm)}';
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

  // ────────────────────────────────────────────────────────────────
  // 🔹 FLUTTER_MAP: ПОЛИЛИНИИ И МАРКЕРЫ
  // ────────────────────────────────────────────────────────────────
  List<flutter_map.Polyline> _buildFlutterMapPolylines() {
    final polylines = <flutter_map.Polyline>[];

    if (_canColorByElevation()) {
      final segments = _buildColoredSegments();
      polylines.addAll(
        segments.map(
          (segment) => flutter_map.Polyline(
            points: segment.points,
            strokeWidth: 3.0,
            color: segment.color,
          ),
        ),
      );
    } else {
      polylines.add(
        flutter_map.Polyline(
          points: widget.points,
          strokeWidth: 3.0,
          color: AppColors.brandPrimary,
        ),
      );
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

    final startPoint = _startPoint ??
        (_startIndex != null ? widget.points[_startIndex!] : null);
    if (startPoint != null) {
      markers.add(
        _buildFlutterMapMarker(
          point: startPoint,
          label: '1',
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
        ),
      );
    }

    return markers;
  }

  flutter_map.Marker _buildFlutterMapMarker({
    required ll.LatLng point,
    required String label,
  }) {
    return flutter_map.Marker(
      point: point,
      width: AppSpacing.xl,
      height: AppSpacing.xl,
      child: Container(
        width: AppSpacing.xl,
        height: AppSpacing.xl,
        decoration: const BoxDecoration(
          color: AppColors.brandPrimary,
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

class _ElevationLegend extends StatelessWidget {
  const _ElevationLegend({
    required this.upColor,
    required this.downColor,
  });

  final Color upColor;
  final Color downColor;

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────────────────────────────────
    // 🔹 КОНТЕЙНЕР ЛЕГЕНДЫ: СТИЛЬ ПО ТЕМЕ
    // ──────────────────────────────────────────────────────────────
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.getBorderColor(context),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendItem(
            color: upColor,
            label: 'Подъём',
          ),
          const SizedBox(height: AppSpacing.xs),
          _LegendItem(
            color: downColor,
            label: 'Спуск',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────────────────────────────────
    // 🔹 СТРОКА ЛЕГЕНДЫ: ЦВЕТ + ТЕКСТ
    // ──────────────────────────────────────────────────────────────
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.sm,
          height: AppSpacing.sm,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.h13w5.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ],
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

