import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../core/config/app_config.dart';
import '../../../../../../../../core/services/routes_service.dart';
import '../../../../../../profile/providers/training/training_provider.dart';
import '../../../../activity/description_screen.dart';
import '../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../core/widgets/transparent_route.dart';
import '../../edit_route_bottom_sheet.dart';
import 'rout_description_bottom_sheet.dart';
import '../../../../../../map/services/marker_assets.dart';

/// Экран описания маршрута. Загружает детали из API (дата, автор, рекорды).
class RouteDescriptionScreen extends StatefulWidget {
  const RouteDescriptionScreen({
    super.key,
    required this.routeId,
    required this.userId,
    required this.initialRoute,
    this.onRouteDeleted,
    this.onRouteUpdated,
  });

  final int routeId;
  final int userId;
  final SavedRouteItem initialRoute;
  /// Вызывается после удаления маршрута; затем выполняется pop на экран избранных.
  final VoidCallback? onRouteDeleted;
  /// Вызывается после редактирования маршрута (имя/сложность).
  final void Function(String name, String difficulty)? onRouteUpdated;

  @override
  State<RouteDescriptionScreen> createState() => _RouteDescriptionScreenState();
}

class _RouteDescriptionScreenState extends State<RouteDescriptionScreen> {
  /// Фиксированная высота свёрнутого нижнего листа (логические пиксели).
  static const double _sheetCollapsedHeightPx = 100.0;

  RouteDetail? _detail;
  bool _loading = true;
  Object? _error;
  // ────────────────────────────────────────────────────────────────
  // Точки маршрута для интерактивной карты
  // ────────────────────────────────────────────────────────────────
  List<ll.LatLng> _routePoints = const [];

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

  Future<void> _loadDetail() async {
    if (widget.routeId <= 0) {
      if (mounted) setState(() { _loading = false; });
      return;
    }
    try {
      final d = await RoutesService().getRouteDetail(
        routeId: widget.routeId,
        userId: widget.userId,
      );
      if (mounted) setState(() { _detail = d; _loading = false; });
      await _loadRoutePoints(d);
    } catch (e, st) {
      if (mounted) setState(() { _error = e; _loading = false; });
      debugPrint('RouteDetail load error: $e $st');
    }
  }

  String get _title =>
      _detail?.name ?? widget.initialRoute.name;
  // ────────────────────────────────────────────────────────────────
  // Точки маршрута для интерактивной карты
  // ────────────────────────────────────────────────────────────────
  List<ll.LatLng> get _routePointsSafe => _routePoints;

  // ────────────────────────────────────────────────────────────────
  // Загружаем точки маршрута: из detail, иначе из активности
  // ────────────────────────────────────────────────────────────────
  Future<void> _loadRoutePoints(RouteDetail d) async {
    if (d.points.isNotEmpty) {
      if (!mounted) return;
      setState(() => _routePoints = d.points);
      return;
    }
    final activityId =
        d.sourceActivityId ?? d.personalBestActivityId ?? 0;
    if (activityId <= 0) {
      if (!mounted) return;
      setState(() => _routePoints = const []);
      return;
    }
    try {
      final map = await RoutesService().getActivityById(
        activityId: activityId,
        userId: widget.userId,
      );
      if (map == null) return;
      final ta = TrainingActivity.fromJson(map);
      final points = ta.points
          .map((c) => ll.LatLng(c.lat, c.lng))
          .toList();
      if (!mounted) return;
      setState(() => _routePoints = points);
    } catch (_) {
      if (!mounted) return;
      setState(() => _routePoints = const []);
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Данные маршрута по умолчанию (fallback, если нет личного рекорда)
  // ────────────────────────────────────────────────────────────────
  double get _distanceKm =>
      _detail != null ? _detail!.distanceKm : widget.initialRoute.distanceKm;
  // ────────────────────────────────────────────────────────────────
  // Личный рекорд пользователя: id тренировки, дистанция и набор высоты
  // ────────────────────────────────────────────────────────────────
  int get _personalBestActivityId =>
      _detail?.personalBestActivityId ?? 0;
  double? get _personalBestDistanceKm {
    final distanceM = _detail?.personalBestDistanceM;
    if (distanceM == null || distanceM <= 0) return null;
    return distanceM / 1000.0;
  }
  double? get _personalBestAscentM {
    final ascentM = _detail?.personalBestAscentM;
    if (ascentM == null || ascentM <= 0) return null;
    return ascentM;
  }
  /// Время: личный рекорд пользователя (movingDuration), иначе fallback.
  String get _durationText {
    final pb = _detail?.personalBestText;
    if (pb != null && pb.isNotEmpty && pb != '—') return pb;
    return widget.initialRoute.durationText ?? '—';
  }
  int get _ascentM =>
      _detail != null ? _detail!.ascentM : widget.initialRoute.ascentM;
  String get _difficulty =>
      _detail?.difficulty ?? widget.initialRoute.difficulty;

  // ────────────────────────────────────────────────────────────────
  // Пустой фон карты (когда нет точек маршрута): без плейсхолдера и иконки
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

  String _formatCreatedAt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('d MMMM yyyy', 'ru').format(dt);
    } catch (_) {
      return iso;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Формат дистанции без округления (отсечение до 2 знаков)
  // ────────────────────────────────────────────────────────────────
  String _formatDistanceKm(double km) {
    final truncated = (km * 100).truncateToDouble() / 100;
    return truncated.toStringAsFixed(2);
  }

  /// Показать меню маршрута (Изменить / Удалить) — вызывается с кнопки на карте.
  void _showRouteMenu(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final position = RelativeRect.fromLTRB(
      size.width - 220,
      80,
      16,
      0,
    );
    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xll),
      ),
      color: AppColors.surface,
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              const Icon(
                Icons.edit_outlined,
                size: 22,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 12),
              Text(
                'Изменить',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 22,
                color: AppColors.error,
              ),
              SizedBox(width: 12),
              Text(
                'Удалить',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        showEditRouteBottomSheet(
          context,
          route: widget.initialRoute,
          userId: widget.userId,
          onSaved: (name, difficulty) {
            widget.onRouteUpdated?.call(name, difficulty);
            _loadDetail();
          },
        );
      } else if (value == 'delete') {
        _confirmAndDeleteRoute(context);
      }
    });
  }

  /// Диалог подтверждения удаления; после удаления — pop на экран избранных.
  Future<void> _confirmAndDeleteRoute(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить маршрут?'),
        content: Text(
          'Маршрут «${widget.initialRoute.name}» будет удалён из избранного.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Отмена',
              style: TextStyle(
                color: AppColors.getTextSecondaryColor(ctx),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await RoutesService().deleteRoute(
        routeId: widget.routeId,
        userId: widget.userId,
      );
      if (!mounted) return;
      widget.onRouteDeleted?.call();
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText.rich(
              TextSpan(
                text: 'Ошибка: $e',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        );
      }
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Переход к лучшей тренировке пользователя по маршруту
  // ────────────────────────────────────────────────────────────────
  Future<void> _openPersonalBestActivity(BuildContext context) async {
    // ── Защита от пустого id
    final activityId = _personalBestActivityId;
    if (activityId <= 0) return;
    try {
      // ── Загружаем полную активность по id
      final map = await RoutesService().getActivityById(
        activityId: activityId,
        userId: widget.userId,
      );
      if (map == null || !context.mounted) return;
      // ── Конвертируем в модель для экрана описания
      final ta = TrainingActivity.fromJson(map);
      final activity = ta.toLentaActivity(
        widget.userId,
        'Пользователь',
        'assets/avatar_2.png',
      );
      if (!context.mounted) return;
      // ── Открываем экран описания тренировки
      Navigator.of(context).push(
        TransparentPageRoute(
          builder: (_) => ActivityDescriptionPage(
            activity: activity,
            currentUserId: widget.userId,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Open personal best error: $e $st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText.rich(
            TextSpan(
              text: 'Ошибка: $e',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdText = _loading && _detail == null
        ? '—'
        : _formatCreatedAt(_detail?.createdAt);
    // ────────────────────────────────────────────────────────────────
    // Данные личного рекорда для экрана маршрута
    // ────────────────────────────────────────────────────────────────
    final canOpenPersonalBest = _personalBestActivityId > 0;
    // ── Единый обработчик тапа для времени и строки «Личный рекорд»
    final VoidCallback? onPersonalBestTap = canOpenPersonalBest
        ? () => _openPersonalBestActivity(context)
        : null;
    final distanceKm = _personalBestDistanceKm ?? _distanceKm;
    final distanceText = '${_formatDistanceKm(distanceKm)} км';
    final ascentValueM = _personalBestAscentM ?? _ascentM.toDouble();
    final ascentText = '${ascentValueM.toStringAsFixed(0)} м';
    // Лидер — самый быстрый по маршруту
    // Если нет результатов — не показываем блок
    final leader = _detail?.leader;
    final personalBestText = _durationText;
    final myWorkoutsCount = _detail?.myWorkoutsCount ?? 0;
    final participantsCount = _detail?.participantsCount ?? 0;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText.rich(
                    TextSpan(
                      text: 'Ошибка: ${_error.toString()}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadDetail();
                },
                child: Stack(
                  children: [
                    // ─────────────────────────────────────────────────────────
                    // Карта на весь экран (нижний слой, фон)
                    // ─────────────────────────────────────────────────────────
                    Positioned.fill(
                      child: _RouteMapTopBlock(
                        points: _routePointsSafe,
                        placeholderBuilder: (height) =>
                            _mapPlaceholder(context, height),
                        isInteractive: true,
                        onBack: () => Navigator.of(context).maybePop(),
                        onMenu: () => _showRouteMenu(context),
                      ),
                    ),
                    // ── Нижний лист: при открытии развёрнут на 55%, можно свернуть/развернуть
                    DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: 0.5,
                      minChildSize: (_sheetCollapsedHeightPx /
                              MediaQuery.sizeOf(context).height)
                          .clamp(0.0, 1.0),
                      maxChildSize: 0.5,
                      builder: (context, scrollController) {
                        return RouteDescriptionBottomSheetContent(
                          scrollController: scrollController,
                          dragController: _sheetController,
                          data: RouteDescriptionSheetData(
                            title: _title,
                            difficulty: _difficulty,
                            createdText: createdText,
                            leader: leader,
                            routeId: widget.routeId,
                            userId: widget.userId,
                            distanceText: distanceText,
                            durationText: _durationText,
                            ascentText: ascentText,
                            personalBestText: personalBestText,
                            myWorkoutsCount: myWorkoutsCount,
                            participantsCount: participantsCount,
                            onPersonalBestTap: onPersonalBestTap,
                          ),
                        );
                      },
                    ),
                    // ── Индикатор загрузки поверх контента, пока загружаются детали маршрута
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

// ────────────────────────────────────────────────────────────────────
// Блок карты вверху экрана с кнопками в тёмных кружках (как в
// description_screen): слева «назад», справа «меню».
// ────────────────────────────────────────────────────────────────────
class _RouteMapTopBlock extends StatelessWidget {
  const _RouteMapTopBlock({
    required this.points,
    required this.placeholderBuilder,
    required this.isInteractive,
    required this.onBack,
    required this.onMenu,
  });

  final List<ll.LatLng> points;
  final Widget Function(double height) placeholderBuilder;
  final bool isInteractive;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeTop = mediaQuery.padding.top;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Высота карты: на весь доступный экран (когда блок в Positioned.fill)
        final mapHeight = constraints.maxHeight;

        return SizedBox(
          height: mapHeight,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // ────────────────────────────────────────────────────────────
              // Интерактивная карта на весь блок (весь экран)
              // ────────────────────────────────────────────────────────────
              Positioned.fill(
                child: points.isNotEmpty
                    ? _InlineRouteMap(
                        points: points,
                        isInteractive: isInteractive,
                      )
                    : placeholderBuilder(mapHeight),
              ),
              // Кнопки поверх карты: слева «назад», справа «меню»
          Positioned(
            top: safeTop + 8,
            left: 8,
            child: _CircleAppIcon(
              icon: CupertinoIcons.back,
              onPressed: onBack,
            ),
          ),
          Positioned(
            top: safeTop + 8,
            right: 8,
            child: _CircleAppIcon(
              icon: CupertinoIcons.ellipsis_vertical,
              onPressed: onMenu,
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Интерактивная карта маршрута (уменьшенная версия, как во fullscreen).
// Поддерживает flutter_map (macOS) и Mapbox (Android/iOS).
// ────────────────────────────────────────────────────────────────────
class _InlineRouteMap extends StatefulWidget {
  const _InlineRouteMap({
    required this.points,
    required this.isInteractive,
  });

  final List<ll.LatLng> points;
  final bool isInteractive;

  @override
  State<_InlineRouteMap> createState() => _InlineRouteMapState();
}

class _InlineRouteMapState extends State<_InlineRouteMap> {
  // ────────────────────────────────────────────────────────────────
  // Контроллеры и менеджеры Mapbox
  // ────────────────────────────────────────────────────────────────
  PolylineAnnotationManager? _polylineAnnotationManager;
  PointAnnotationManager? _pointAnnotationManager;
  Uint8List? _routeStartMarkerImage;
  Uint8List? _routeEndMarkerImage;

  // ────────────────────────────────────────────────────────────────
  // Контроллер flutter_map (macOS)
  // ────────────────────────────────────────────────────────────────
  final flutter_map.MapController _flutterMapController =
      flutter_map.MapController();

  // ────────────────────────────────────────────────────────────────
  // Флаги готовности и позиционирования
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
  // Построение карты с учётом платформы
  // ────────────────────────────────────────────────────────────────
  Widget _buildMap(ll.LatLng center, _RouteLatLngBounds bounds) {
    // Нижний отступ ~50% высоты экрана — маршрут в верхней половине
    final bottomPadding =
        MediaQuery.sizeOf(context).height * 0.5;

    // ── macOS: flutter_map
    if (Platform.isMacOS) {
      return flutter_map.FlutterMap(
        mapController: _flutterMapController,
        options: flutter_map.MapOptions(
          initialCenter: center,
          initialZoom: 12.0,
          minZoom: 3.0,
          maxZoom: 18.0,
          onMapReady: () {
            // ── Фитим границы один раз после готовности карты
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
                      top: 48,
                      left: 12,
                      right: 12,
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
            markers: _buildFlutterMapRouteMarkers(),
          ),
        ],
      );
    }

    // ── Android/iOS: Mapbox
    return Stack(
      children: [
        // Фон до готовности карты
        Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.getBackgroundColor(context),
        ),
        // Карта с fade-эффектом после инициализации
        AnimatedOpacity(
          opacity: _isMapReady ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: MapWidget(
            key: ValueKey('route_map_${widget.points.length}'),
            onMapCreated: (MapboxMap mapboxMap) async {
              // ── Отключаем масштабную линейку
              try {
                await mapboxMap.scaleBar.updateSettings(
                  ScaleBarSettings(enabled: false),
                );
              } catch (_) {}

              // ── Ждём инициализации каналов Mapbox
              await Future.delayed(const Duration(milliseconds: 300));

              // ── Полилиния маршрута
              try {
                _polylineAnnotationManager = await mapboxMap.annotations
                    .createPolylineAnnotationManager();
                await _drawTrackPolyline();
              } catch (_) {}

              // ── Маркеры старта и финиша
              try {
                _pointAnnotationManager = await mapboxMap.annotations
                    .createPointAnnotationManager();
                await _drawRouteStartEndMarkers();
              } catch (_) {}

              // ── Фит камеры по границам
              try {
                if (widget.points.length > 1) {
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
                      top: 48,
                      left: 12,
                      bottom: bottomPadding,
                      right: 12,
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

              // ── Показываем карту после полной инициализации
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
  // Полилиния маршрута (Mapbox)
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
  // Маркеры старта и финиша (Mapbox)
  // ────────────────────────────────────────────────────────────────
  Future<void> _drawRouteStartEndMarkers() async {
    if (_pointAnnotationManager == null || widget.points.length < 2) {
      return;
    }
    await _ensureRouteMarkerImages();
    if (_routeStartMarkerImage == null || _routeEndMarkerImage == null) {
      return;
    }
    final first = widget.points.first;
    final last = widget.points.last;
    await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(first.longitude, first.latitude),
        ),
        image: _routeStartMarkerImage!,
        iconSize: 1.0,
      ),
    );
    await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(last.longitude, last.latitude),
        ),
        image: _routeEndMarkerImage!,
        iconSize: 1.0,
      ),
    );
  }

  Future<void> _ensureRouteMarkerImages() async {
    _routeStartMarkerImage ??= await MarkerAssets.createMarkerImage(
      AppColors.success,
      'С',
    );
    _routeEndMarkerImage ??= await MarkerAssets.createMarkerImage(
      AppColors.error,
      'Ф',
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Flutter_map: полилиния маршрута
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
  // Flutter_map: маркеры старта и финиша
  // ────────────────────────────────────────────────────────────────
  List<flutter_map.Marker> _buildFlutterMapRouteMarkers() {
    if (widget.points.length < 2) return const [];
    return [
      _routeMarker(widget.points.first, 'С', AppColors.success),
      _routeMarker(widget.points.last, 'Ф', AppColors.error),
    ];
  }

  flutter_map.Marker _routeMarker(
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
  // Вспомогательные методы вычисления центра и границ
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

  _RouteLatLngBounds _boundsFromPoints(List<ll.LatLng> pts) {
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
    return _RouteLatLngBounds(
      ll.LatLng(minLat, minLng),
      ll.LatLng(maxLat, maxLng),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Локальные границы маршрута для fit камеры
// ────────────────────────────────────────────────────────────────────
class _RouteLatLngBounds {
  final ll.LatLng southwest;
  final ll.LatLng northeast;

  _RouteLatLngBounds(this.southwest, this.northeast);
}

// ────────────────────────────────────────────────────────────────────
// Кнопка-иконка в полупрозрачном тёмном кружке (как в description_screen).
// ────────────────────────────────────────────────────────────────────
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

