import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../../../../../core/services/route_map_service.dart';
import '../../../../../../../../../core/services/routes_service.dart';
import '../../../../../../../../../core/services/segments_service.dart';
import '../../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../../core/utils/static_map_url_builder.dart';
import '../../../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../../../core/widgets/transparent_route.dart';
import '../../../../../activity/description_screen.dart';
import '../../../../../../../profile/providers/training/training_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Формат даты/времени из API (Y-m-d H:i:s) в «18 июня, 20:52».
// ─────────────────────────────────────────────────────────────────────────────
String _formatWhen(String whenStr) {
  if (whenStr.isEmpty) return '—';
  try {
    final dt = DateTime.parse(whenStr);
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final month = months[dt.month - 1];
    return '${dt.day} $month, '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return whenStr;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Локальные константы отступов (только из токенов).
// ─────────────────────────────────────────────────────────────────────────────
const double _space2 = AppSpacing.xs / 2;
const double _space6 = AppSpacing.sm - _space2;
const double _space10 = AppSpacing.sm + _space2;
const double _space12 = AppSpacing.sm + AppSpacing.xs;
const double _space18 = AppSpacing.md + _space2;

// ─────────────────────────────────────────────────────────────────────────────
// Экран: Мои результаты по участку.
// ─────────────────────────────────────────────────────────────────────────────
class SegmentMyResultsScreen extends StatefulWidget {
  const SegmentMyResultsScreen({
    super.key,
    required this.segmentId,
    required this.segmentTitle,
    required this.userId,
  });

  final int segmentId;
  final String segmentTitle;
  final int userId;

  @override
  State<SegmentMyResultsScreen> createState() =>
      _SegmentMyResultsScreenState();
}

class _SegmentMyResultsScreenState
    extends State<SegmentMyResultsScreen> {
  List<SegmentAttemptItem>? _attempts;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ЗАГРУЗКА ДАННЫХ
  // ────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    if (widget.segmentId <= 0 || widget.userId <= 0) {
      if (mounted) {
        setState(() {
          _attempts = [];
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await SegmentsService().getSegmentAttempts(
        segmentId: widget.segmentId,
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _attempts = list;
        _loading = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
      log('Segment attempts load error: $e', stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          title: 'Мои результаты',
          showBottomDivider: false,
        ),
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
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // ─── Подшапка: название участка
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceColor(context),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.darkShadowSoft
                                  : AppColors.shadowSoft,
                              offset: const Offset(0, 1),
                              blurRadius: 1,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          _space12,
                        ),
                        child: Center(
                          child: Text(
                            widget.segmentTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: _space10),
                    ),
                    if (_loading)
                      const SliverFillRemaining(
                        child: Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      )
                    else if (_attempts == null || _attempts!.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Нет результатов по этому участку',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        sliver: SliverList.separated(
                          itemCount: _attempts!.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: _space6),
                          itemBuilder: (context, i) => _ResultCard(
                            item: _attempts![i],
                            userId: widget.userId,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.lg),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Карточка результата: карта, дата/время, длительность, темп/скорость, пульс.
// ─────────────────────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.item,
    required this.userId,
  });

  final SegmentAttemptItem item;
  final int userId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openActivityDescription(context),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.twinchip,
            width: 1.0,
          ),
        ),
        child: _ResultRow(item: item, userId: userId),
      ),
    );
  }

  Future<void> _openActivityDescription(BuildContext context) async {
    try {
      final map = await RoutesService().getActivityById(
        activityId: item.activityId,
        userId: userId,
      );
      if (map == null || !context.mounted) return;
      final ta = TrainingActivity.fromJson(map);
      final activity = ta.toLentaActivity(
        userId,
        'Пользователь',
        'assets/avatar_2.png',
      );
      if (!context.mounted) return;
      Navigator.of(context).push(
        TransparentPageRoute(
          builder: (_) => ActivityDescriptionPage(
            activity: activity,
            currentUserId: userId,
          ),
        ),
      );
    } catch (e, st) {
      log('Open segment activity error: $e', stackTrace: st);
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
}

class _ResultRow extends StatefulWidget {
  const _ResultRow({required this.item, required this.userId});
  final SegmentAttemptItem item;
  final int userId;

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  List<LatLng>? _points;
  bool _loadingMap = true;

  @override
  void initState() {
    super.initState();
    _loadWorkoutData();
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ЗАГРУЗКА ДАННЫХ ТРЕНИРОВКИ ДЛЯ МИНИ-КАРТЫ
  // ────────────────────────────────────────────────────────────────
  Future<void> _loadWorkoutData() async {
    try {
      final map = await RoutesService().getActivityById(
        activityId: widget.item.activityId,
        userId: widget.userId,
      );
      if (map == null || !mounted) {
        if (mounted) {
          setState(() {
            _loadingMap = false;
          });
        }
        return;
      }
      final ta = TrainingActivity.fromJson(map);
      final points = ta.points.map((p) => LatLng(p.lat, p.lng)).toList();
      if (!mounted) return;
      setState(() {
        _points = points;
        _loadingMap = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMap = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _formatWhen(widget.item.when);
    final hrText = widget.item.heartRate != null
        ? '${widget.item.heartRate}'
        : '—';
    return Padding(
      padding: const EdgeInsets.all(_space6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _space2,
          _space2,
          _space12,
          _space2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Превью карты (80x76)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: _loadingMap
                  ? SizedBox(
                      width: 80,
                      height: 76,
                      child: _mapPlaceholder(context),
                    )
                  : _points != null && _points!.isNotEmpty
                      ? SizedBox(
                          width: 80,
                          height: 76,
                          child: _buildStaticMiniMap(
                            context,
                            _points!,
                            activityId: widget.item.activityId,
                            userId: widget.userId,
                          ),
                        )
                      : SizedBox(
                          width: 80,
                          height: 76,
                          child: _mapPlaceholder(context),
                        ),
            ),
            const SizedBox(width: _space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: _space18),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricAligned(
                          cupertinoIcon: CupertinoIcons.time,
                          text: widget.item.durationText,
                          align: MainAxisAlignment.start,
                          textAlign: TextAlign.left,
                          iconColor: AppColors.brandPrimary,
                        ),
                      ),
                      Expanded(
                        child: _MetricAligned(
                          materialIcon: Icons.speed,
                          text: widget.item.paceText,
                          align: MainAxisAlignment.center,
                          textAlign: TextAlign.center,
                          iconColor: AppColors.brandPrimary,
                        ),
                      ),
                      Expanded(
                        child: _MetricAligned(
                          cupertinoIcon: CupertinoIcons.heart,
                          text: hrText,
                          align: MainAxisAlignment.center,
                          textAlign: TextAlign.center,
                          iconColor: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 СТАТИЧНАЯ МИНИ-КАРТА МАРШРУТА (80x76)
  // ────────────────────────────────────────────────────────────────
  Widget _buildStaticMiniMap(
    BuildContext context,
    List<LatLng> points, {
    int? activityId,
    int? userId,
  }) {
    const widthDp = 80.0;
    const heightDp = 76.0;

    // ──────────────────────────────────────────────────────────────
    // 🔹 ПРОРЕЖИВАНИЕ ТОЧЕК: для треков с большим количеством точек
    // ──────────────────────────────────────────────────────────────
    final thinnedPoints = _thinPoints(points, step: 30);

    if (!_arePointsValidForMap(thinnedPoints)) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.getSurfaceColor(context),
        child: const Icon(
          Icons.map_outlined,
          color: AppColors.brandPrimary,
          size: 24,
        ),
      );
    }

    // ──────────────────────────────────────────────────────────────
    // 🔹 ОПТИМИЗАЦИЯ РАЗМЕРА: ограниченный DPR для мини-карт
    // ──────────────────────────────────────────────────────────────
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final optimizedDpr = (dpr > 1.5 ? 1.5 : dpr).clamp(1.0, 1.5);

    final widthPx = (widthDp * optimizedDpr).round();
    final heightPx = (heightDp * optimizedDpr).round();

    final routeMapService = RouteMapService();
    String mapUrl;
    bool shouldSaveAfterLoad = false;

    final cachedUrl = activityId != null
        ? routeMapService.getCachedRouteMapUrl(
            activityId,
            thumbnail: true,
          )
        : null;

    if (cachedUrl != null) {
      mapUrl = cachedUrl;
      shouldSaveAfterLoad = false;
    } else {
      try {
        mapUrl = StaticMapUrlBuilder.fromPoints(
          points: thinnedPoints,
          widthPx: widthPx.toDouble(),
          heightPx: heightPx.toDouble(),
          strokeWidth: 4.0,
          padding: 8.0,
          maxWidth: 160.0,
          maxHeight: 140.0,
        );

        if (activityId != null && userId != null) {
          shouldSaveAfterLoad = true;
        }

        if (activityId != null) {
          routeMapService
              .getRouteMapUrl(activityId, thumbnail: true)
              .catchError((_) {
            return null;
          });
        }
      } catch (_) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.getSurfaceColor(context),
          child: const Icon(
            Icons.map_outlined,
            color: AppColors.brandPrimary,
            size: 24,
          ),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: mapUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      memCacheWidth: widthPx,
      maxWidthDiskCache: widthPx,
      placeholder: (context, url) => Container(
        color: AppColors.getBackgroundColor(context),
        child: Center(
          child: CupertinoActivityIndicator(
            radius: 10,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.getBackgroundColor(context),
        child: Icon(
          CupertinoIcons.map,
          color: AppColors.getIconSecondaryColor(context),
          size: 32,
        ),
      ),
      imageBuilder: shouldSaveAfterLoad
          ? (context, imageProvider) {
              final routeMapService = RouteMapService();
              routeMapService.saveRouteMapFromUrl(
                activityId: activityId!,
                userId: userId!,
                mapboxUrl: mapUrl,
                thumbnail: true,
              );
              return Image(image: imageProvider);
            }
          : null,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПРОРЕЖИВАНИЕ ТОЧЕК
  // ────────────────────────────────────────────────────────────────
  static List<LatLng> _thinPoints(
    List<LatLng> points, {
    int step = 30,
    int threshold = 100,
  }) {
    if (points.length <= 2 || step <= 1) {
      return points;
    }
    if (points.length < threshold) {
      return points;
    }
    final thinnedPoints = <LatLng>[];
    thinnedPoints.add(points.first);
    for (int i = step; i < points.length - 1; i += step) {
      thinnedPoints.add(points[i]);
    }
    final lastPoint = points.last;
    if (thinnedPoints.last != lastPoint) {
      thinnedPoints.add(lastPoint);
    }
    return thinnedPoints;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ПРОВЕРКА ВАЛИДНОСТИ ТОЧЕК ДЛЯ КАРТЫ
  // ────────────────────────────────────────────────────────────────
  static bool _arePointsValidForMap(List<LatLng> points) {
    if (points.isEmpty || points.length < 2) {
      return false;
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    const minDifference = 0.001;
    final latDifference = maxLat - minLat;
    final lngDifference = maxLng - minLng;
    return latDifference >= minDifference || lngDifference >= minDifference;
  }

  static Widget _mapPlaceholder(BuildContext context) {
    return Container(
      width: 80,
      height: 76,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceMuted
          : AppColors.skeletonBase,
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.map,
        size: 20,
        color: AppColors.getTextSecondaryColor(context),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Метрика: иконка + текст
// ─────────────────────────────────────────────────────────────────────────────
class _MetricAligned extends StatelessWidget {
  const _MetricAligned({
    this.cupertinoIcon,
    this.materialIcon,
    required this.text,
    required this.align,
    required this.textAlign,
    this.iconColor,
  });

  final IconData? cupertinoIcon;
  final IconData? materialIcon;
  final String text;
  final MainAxisAlignment align;
  final TextAlign textAlign;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final icon = materialIcon ?? cupertinoIcon!;
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: align,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? AppColors.getTextSecondaryColor(context),
        ),
        const SizedBox(width: _space6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }
}
