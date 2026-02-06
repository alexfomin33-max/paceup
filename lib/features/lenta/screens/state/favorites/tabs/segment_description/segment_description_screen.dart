import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../../../../../core/config/app_config.dart';
import '../../../../../../../../core/services/routes_service.dart';
import '../../../../../../../../core/services/segments_service.dart';
import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../core/utils/activity_format.dart';
import '../../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../../core/widgets/transparent_route.dart';
import '../../../../activity/description_screen.dart';
import '../../../../../../profile/providers/training/training_provider.dart';
import '../../../../../../map/services/marker_assets.dart';
import 'segment_description_bottom_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Экран описания участка (Избранное → Участки).
// ─────────────────────────────────────────────────────────────────────────────
class SegmentDescriptionScreen extends StatefulWidget {
  const SegmentDescriptionScreen({
    super.key,
    required this.segmentId,
    required this.userId,
    required this.initialSegment,
  });

  final int segmentId;
  final int userId;
  final SegmentWithMyResult initialSegment;

  @override
  State<SegmentDescriptionScreen> createState() =>
      _SegmentDescriptionScreenState();
}

class _SegmentDescriptionScreenState extends State<SegmentDescriptionScreen> {
  // ────────────────────────────────────────────────────────────────
  // 🔹 КОНСТАНТЫ И СОСТОЯНИЕ
  // ────────────────────────────────────────────────────────────────
  static const double _sheetCollapsedHeightPx = 100.0;

  SegmentDetail? _detail;
  bool _loading = true;
  Object? _error;
  List<ll.LatLng> _segmentPoints = const [];

  late final DraggableScrollableController _sheetController;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _loadDetail();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ЗАГРУЗКА ДЕТАЛЕЙ УЧАСТКА
  // ────────────────────────────────────────────────────────────────
  Future<void> _loadDetail() async {
    if (widget.segmentId <= 0) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }
    try {
      final d = await SegmentsService().getSegmentDetail(
        segmentId: widget.segmentId,
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _detail = d;
        _segmentPoints = d.points;
        _loading = false;
        _error = null;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
      log('SegmentDetail load error: $e', stackTrace: st);
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ВСПОМОГАТЕЛЬНЫЕ ГЕТТЕРЫ
  // ────────────────────────────────────────────────────────────────
  String get _title => _detail?.name ?? widget.initialSegment.name;

  double get _distanceKm {
    final d = _detail;
    if (d != null) {
      return d.displayDistanceKm;
    }
    return widget.initialSegment.displayDistanceKm;
  }

  bool get _hasMyResult {
    final best = _detail?.personalBestDurationSec ?? 0;
    return best > 0;
  }

  String get _personalBestText {
    if (!_hasMyResult) return '—';
    final text = _detail?.personalBestText;
    if (text == null || text.isEmpty) return '—';
    return text;
  }

  int get _personalBestActivityId =>
      _detail?.personalBestActivityId ?? 0;

  String get _sportTypeText =>
      _sportTypeLabel(_detail?.activityType);

  IconData get _sportTypeIcon =>
      _sportTypeIconFor(_detail?.activityType);

  String get _distanceText =>
      '${_formatDistanceKm(_distanceKm)} км';

  String get _ascentText {
    if (!_hasMyResult) return '—';
    final ascent = _detail?.personalBestElevationGainM;
    if (ascent == null || ascent <= 0) return '—';
    return '${ascent.toStringAsFixed(0)} м';
  }

  String get _paceOrSpeedText {
    if (!_hasMyResult) return '—';
    final pace = _detail?.personalBestPaceMinPerKm;
    final speed = _detail?.personalBestSpeedKmh;
    if (pace != null && pace > 0) {
      return '${formatPace(pace)} /км';
    }
    if (speed != null && speed > 0) {
      return '${speed.toStringAsFixed(1)} км/ч';
    }
    return '—';
  }

  String get _heartRateText {
    if (!_hasMyResult) return '—';
    final hr = _detail?.personalBestAvgHeartRate;
    if (hr == null || hr <= 0) return '—';
    return hr.round().toString();
  }

  int get _myAttemptsCount => _detail?.myAttemptsCount ?? 0;

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПЕРЕХОД К ЛИЧНОМУ РЕКОРДУ
  // ────────────────────────────────────────────────────────────────
  Future<void> _openPersonalBestActivity(BuildContext context) async {
    final activityId = _personalBestActivityId;
    if (activityId <= 0) return;
    try {
      final map = await RoutesService().getActivityById(
        activityId: activityId,
        userId: widget.userId,
      );
      if (map == null || !context.mounted) return;
      final ta = TrainingActivity.fromJson(map);
      final activity = ta.toLentaActivity(
        widget.userId,
        'Пользователь',
        'assets/avatar_2.png',
      );
      if (!context.mounted) return;
      Navigator.of(context).push(
        TransparentPageRoute(
          builder: (_) => ActivityDescriptionPage(
            activity: activity,
            currentUserId: widget.userId,
          ),
        ),
      );
    } catch (e, st) {
      log('Open segment best activity error: $e', stackTrace: st);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ошибка'),
          content: SelectableText.rich(
            TextSpan(
              text: e.toString(),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПЛЕЙСХОЛДЕР КАРТЫ
  // ────────────────────────────────────────────────────────────────
  static Widget _mapPlaceholder(BuildContext context, double height) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Container(
        color: AppColors.getBackgroundColor(context),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ФОРМАТ ДИСТАНЦИИ БЕЗ ОКРУГЛЕНИЯ
  // ────────────────────────────────────────────────────────────────
  String _formatDistanceKm(double km) {
    final truncated = (km * 100).truncateToDouble() / 100;
    return truncated.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final canOpenPersonalBest = _personalBestActivityId > 0;
    final VoidCallback? onPersonalBestTap = canOpenPersonalBest
        ? () => _openPersonalBestActivity(context)
        : null;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SelectableText.rich(
                    TextSpan(
                      text: 'Ошибка: ${_error.toString()}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadDetail,
                child: Stack(
                  children: [
                    // ────────────────────────────────────────────────────
                    // Карта на весь экран (нижний слой)
                    // ────────────────────────────────────────────────────
                    Positioned.fill(
                      child: _SegmentMapTopBlock(
                        points: _segmentPoints,
                        placeholderBuilder: (height) =>
                            _mapPlaceholder(context, height),
                        isInteractive: true,
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    // ────────────────────────────────────────────────────
                    // Нижний лист: как в маршрутах
                    // ────────────────────────────────────────────────────
                    DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: 0.5,
                      minChildSize: (_sheetCollapsedHeightPx /
                              MediaQuery.sizeOf(context).height)
                          .clamp(0.0, 1.0),
                      maxChildSize: 0.5,
                      builder: (context, scrollController) {
                        return SegmentDescriptionBottomSheetContent(
                          scrollController: scrollController,
                          dragController: _sheetController,
                          data: SegmentDescriptionSheetData(
                            title: _title,
                            sportTypeText: _sportTypeText,
                            sportTypeIcon: _sportTypeIcon,
                            distanceText: _distanceText,
                            ascentText: _ascentText,
                            paceOrSpeedText: _paceOrSpeedText,
                            heartRateText: _heartRateText,
                            personalBestText: _personalBestText,
                            myAttemptsCount: _hasMyResult
                                ? _myAttemptsCount
                                : 0,
                            hasMyResult: _hasMyResult,
                            segmentId: widget.segmentId,
                            userId: widget.userId,
                            onPersonalBestTap: onPersonalBestTap,
                          ),
                        );
                      },
                    ),
                    if (_loading)
                      Positioned.fill(
                        child: Center(
                          child: CupertinoActivityIndicator(
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Блок карты вверху: кнопка «назад», как в маршрутах.
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentMapTopBlock extends StatelessWidget {
  const _SegmentMapTopBlock({
    required this.points,
    required this.placeholderBuilder,
    required this.isInteractive,
    required this.onBack,
  });

  final List<ll.LatLng> points;
  final Widget Function(double height) placeholderBuilder;
  final bool isInteractive;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapHeight = constraints.maxHeight;
        return SizedBox(
          height: mapHeight,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned.fill(
                child: points.isNotEmpty
                    ? _InlineSegmentMap(
                        points: points,
                        isInteractive: isInteractive,
                      )
                    : placeholderBuilder(mapHeight),
              ),
              Positioned(
                top: safeTop + AppSpacing.xs,
                left: AppSpacing.xs,
                child: _CircleAppIcon(
                  icon: CupertinoIcons.back,
                  onPressed: onBack,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Интерактивная карта участка (flutter_map для macOS, Mapbox для Android/iOS).
// ─────────────────────────────────────────────────────────────────────────────
class _InlineSegmentMap extends StatefulWidget {
  const _InlineSegmentMap({
    required this.points,
    required this.isInteractive,
  });

  final List<ll.LatLng> points;
  final bool isInteractive;

  @override
  State<_InlineSegmentMap> createState() => _InlineSegmentMapState();
}

class _InlineSegmentMapState extends State<_InlineSegmentMap> {
  // ────────────────────────────────────────────────────────────────
  // 🔹 КОНТРОЛЛЕРЫ MAPBOX
  // ────────────────────────────────────────────────────────────────
  PolylineAnnotationManager? _polylineAnnotationManager;
  PointAnnotationManager? _pointAnnotationManager;
  Uint8List? _segmentStartMarkerImage;
  Uint8List? _segmentEndMarkerImage;

  // ────────────────────────────────────────────────────────────────
  // 🔹 КОНТРОЛЛЕР FLUTTER_MAP
  // ────────────────────────────────────────────────────────────────
  final flutter_map.MapController _flutterMapController =
      flutter_map.MapController();

  // ────────────────────────────────────────────────────────────────
  // 🔹 ФЛАГИ ГОТОВНОСТИ КАРТЫ
  // ────────────────────────────────────────────────────────────────
  bool _isMapReady = false;
  bool _isBoundsFitted = false;

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const SizedBox.shrink();
    }

    final center = _centerFromPoints(widget.points);
    final bounds = _boundsFromPoints(widget.points);

    return IgnorePointer(
      ignoring: !widget.isInteractive,
      child: RepaintBoundary(
        child: _buildMap(center, bounds),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПОСТРОЕНИЕ КАРТЫ С УЧЁТОМ ПЛАТФОРМЫ
  // ────────────────────────────────────────────────────────────────
  Widget _buildMap(ll.LatLng center, _SegmentLatLngBounds bounds) {
    final bottomPadding =
        MediaQuery.sizeOf(context).height * 0.5;

    if (Platform.isMacOS) {
      return flutter_map.FlutterMap(
        mapController: _flutterMapController,
        options: flutter_map.MapOptions(
          initialCenter: center,
          initialZoom: 12.0,
          minZoom: 3.0,
          maxZoom: 18.0,
          onMapReady: () {
            if (_isBoundsFitted) return;
            _isBoundsFitted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (widget.points.length > 1) {
                _flutterMapController.fitCamera(
                  flutter_map.CameraFit.bounds(
                    bounds: flutter_map.LatLngBounds(
                      bounds.southwest,
                      bounds.northeast,
                    ),
                    padding: EdgeInsets.only(
                      top: AppSpacing.lg,
                      left: AppSpacing.sm,
                      right: AppSpacing.sm,
                      bottom: bottomPadding,
                    ),
                  ),
                );
              } else {
                _flutterMapController.move(center, 12.0);
              }
            });
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
            markers: _buildFlutterMapSegmentMarkers(),
          ),
        ],
      );
    }

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
            key: ValueKey('segment_map_${widget.points.length}'),
            onMapCreated: (MapboxMap mapboxMap) async {
              try {
                await mapboxMap.scaleBar.updateSettings(
                  ScaleBarSettings(enabled: false),
                );
              } catch (_) {}

              await Future.delayed(const Duration(milliseconds: 300));

              try {
                _polylineAnnotationManager = await mapboxMap.annotations
                    .createPolylineAnnotationManager();
                await _drawTrackPolyline();
              } catch (_) {}

              try {
                _pointAnnotationManager = await mapboxMap.annotations
                    .createPointAnnotationManager();
                await _drawSegmentStartEndMarkers();
              } catch (_) {}

              try {
                if (widget.points.length > 1) {
                  final camera =
                      await mapboxMap.cameraForCoordinateBounds(
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
                      top: AppSpacing.lg,
                      left: AppSpacing.sm,
                      bottom: bottomPadding,
                      right: AppSpacing.sm,
                    ),
                    null,
                    null,
                    null,
                    null,
                  );
                  await mapboxMap.setCamera(camera);
                } else {
                  await mapboxMap.setCamera(
                    CameraOptions(
                      center: Point(
                        coordinates: Position(
                          center.longitude,
                          center.latitude,
                        ),
                      ),
                      zoom: 12,
                    ),
                  );
                }
              } catch (_) {}

              if (!mounted) return;
              setState(() {
                _isMapReady = true;
              });
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
  // 🔹 MAPBOX: ПОЛИЛИНИЯ УЧАСТКА
  // ────────────────────────────────────────────────────────────────
  Future<void> _drawTrackPolyline() async {
    if (_polylineAnnotationManager == null || widget.points.length < 2) {
      return;
    }
    await _polylineAnnotationManager!.deleteAll();
    final coordinates = widget.points
        .map((p) => Position(p.longitude, p.latitude))
        .toList();
    await _polylineAnnotationManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: coordinates),
        lineColor: AppColors.polyline.toARGB32(),
        lineWidth: 3.0,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 MAPBOX: МАРКЕРЫ СТАРТА И ФИНИША
  // ────────────────────────────────────────────────────────────────
  Future<void> _drawSegmentStartEndMarkers() async {
    if (_pointAnnotationManager == null || widget.points.length < 2) {
      return;
    }
    await _ensureSegmentMarkerImages();
    if (_segmentStartMarkerImage == null ||
        _segmentEndMarkerImage == null) {
      return;
    }
    final first = widget.points.first;
    final last = widget.points.last;
    await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(first.longitude, first.latitude),
        ),
        image: _segmentStartMarkerImage!,
        iconSize: 1.0,
      ),
    );
    await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(last.longitude, last.latitude),
        ),
        image: _segmentEndMarkerImage!,
        iconSize: 1.0,
      ),
    );
  }

  Future<void> _ensureSegmentMarkerImages() async {
    _segmentStartMarkerImage ??= await MarkerAssets.createMarkerImage(
      AppColors.success,
      'С',
    );
    _segmentEndMarkerImage ??= await MarkerAssets.createMarkerImage(
      AppColors.error,
      'Ф',
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 FLUTTER_MAP: ПОЛИЛИНИЯ
  // ────────────────────────────────────────────────────────────────
  List<flutter_map.Polyline> _buildFlutterMapPolylines() {
    return [
      flutter_map.Polyline(
        points: widget.points,
        strokeWidth: 3.0,
        color: AppColors.polyline,
      ),
    ];
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 FLUTTER_MAP: МАРКЕРЫ СТАРТА И ФИНИША
  // ────────────────────────────────────────────────────────────────
  List<flutter_map.Marker> _buildFlutterMapSegmentMarkers() {
    if (widget.points.length < 2) return const [];
    return [
      _segmentMarker(widget.points.first, 'С', AppColors.success),
      _segmentMarker(widget.points.last, 'Ф', AppColors.error),
    ];
  }

  flutter_map.Marker _segmentMarker(
    ll.LatLng point,
    String label,
    Color color,
  ) {
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
  // 🔹 ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ────────────────────────────────────────────────────────────────
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

  _SegmentLatLngBounds _boundsFromPoints(List<ll.LatLng> pts) {
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
    return _SegmentLatLngBounds(
      ll.LatLng(minLat, minLng),
      ll.LatLng(maxLat, maxLng),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Локальные границы участка для fit камеры
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentLatLngBounds {
  final ll.LatLng southwest;
  final ll.LatLng northeast;

  _SegmentLatLngBounds(this.southwest, this.northeast);
}

// ─────────────────────────────────────────────────────────────────────────────
// Кнопка-иконка в полупрозрачном тёмном кружке.
// ─────────────────────────────────────────────────────────────────────────────
class _CircleAppIcon extends StatelessWidget {
  const _CircleAppIcon({
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final iconColor = AppColors.getSurfaceColor(context);
    final backgroundColor =
        AppColors.getTextPrimaryColor(context).withValues(alpha: 0.5);

    return SizedBox(
      width: 38,
      height: 38,
      child: GestureDetector(
        onTap: onPressed ?? () {},
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Локальные хелперы для вида спорта
// ─────────────────────────────────────────────────────────────────────────────
String _sportTypeLabel(String? type) {
  final t = (type ?? '').toLowerCase();
  if (t == 'run' || t == 'running' || t == 'indoor-running') {
    return 'Бег';
  }
  if (t == 'bike' || t == 'cycling' || t == 'bicycle' ||
      t == 'indoor-cycling') {
    return 'Велосипед';
  }
  if (t == 'swim' || t == 'swimming') {
    return 'Плавание';
  }
  if (t == 'ski' || t == 'skiing') {
    return 'Лыжи';
  }
  if (t == 'walking' || t == 'walk') {
    return 'Ходьба';
  }
  if (t == 'hiking') {
    return 'Поход';
  }
  return 'Тренировка';
}

IconData _sportTypeIconFor(String? type) {
  final t = (type ?? '').toLowerCase();
  if (t == 'run' || t == 'running' || t == 'indoor-running') {
    return Icons.directions_run;
  }
  if (t == 'bike' || t == 'cycling' || t == 'bicycle' ||
      t == 'indoor-cycling') {
    return Icons.directions_bike;
  }
  if (t == 'swim' || t == 'swimming') {
    return Icons.pool;
  }
  if (t == 'ski' || t == 'skiing') {
    return Icons.downhill_skiing;
  }
  if (t == 'walking' || t == 'walk') {
    return Icons.directions_walk;
  }
  if (t == 'hiking') {
    return Icons.hiking;
  }
  return Icons.directions_run;
}
