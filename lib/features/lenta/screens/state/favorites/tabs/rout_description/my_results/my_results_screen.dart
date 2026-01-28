import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../../../core/widgets/transparent_route.dart';
import '../../../../../../../../../core/services/routes_service.dart';
import '../../../../../../../../../core/services/route_map_service.dart';
import '../../../../../../../../../core/utils/static_map_url_builder.dart';
import '../../../../../../../profile/providers/training/training_provider.dart';
import '../../../../../activity/description_screen.dart';

/// Форматирует дату/время из API (Y-m-d H:i:s) в «18 июня, 20:52».
String _formatWhen(String whenStr) {
  if (whenStr.isEmpty) return '—';
  try {
    final dt = DateTime.parse(whenStr);
    return DateFormat('d MMMM, HH:mm', 'ru').format(dt);
  } catch (_) {
    return whenStr;
  }
}

/// Экран: Мои результаты для выбранного маршрута.
/// Загружает тренировки по маршруту из API, карты из uploads, тап — в описание.
class MyResultsScreen extends StatefulWidget {
  const MyResultsScreen({
    super.key,
    required this.routeId,
    required this.routeTitle,
    required this.userId,
    this.difficultyText,
  });

  final int routeId;
  final String routeTitle;
  final int userId;
  final String? difficultyText;

  @override
  State<MyResultsScreen> createState() => _MyResultsScreenState();
}

class _MyResultsScreenState extends State<MyResultsScreen> {
  List<RouteWorkoutItem>? _workouts;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.routeId <= 0 || widget.userId <= 0) {
      if (mounted) setState(() { _workouts = []; _loading = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final list = await RoutesService().getRouteWorkouts(
        routeId: widget.routeId,
        userId: widget.userId,
      );
      if (mounted) setState(() { _workouts = list; _loading = false; });
    } catch (e, st) {
      if (mounted) setState(() { _error = e; _loading = false; });
      debugPrint('MyResults load error: $e $st');
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
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // ─── подшапка: название маршрута и чип сложности
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
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Text(
                                widget.routeTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if ((widget.difficultyText ?? '').isNotEmpty)
                              Center(
                                child: _DifficultyChip(
                                  text: widget.difficultyText!,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    if (_loading)
                      const SliverFillRemaining(
                        child: Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      )
                    else if (_workouts == null || _workouts!.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Нет тренировок по этому маршруту',
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        sliver: SliverList.separated(
                          itemCount: _workouts!.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 2),
                          itemBuilder: (context, i) => _ResultCard(
                            item: _workouts![i],
                            userId: widget.userId,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Чип сложности под шапкой.
class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final lc = text.toLowerCase();
    final c = lc.contains('лёгк')
        ? AppColors.success
        : lc.contains('средн')
            ? AppColors.warning
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: c,
        ),
      ),
    );
  }
}

/// Карточка результата: карта из uploads, дата/время, длительность, темп, пульс.
/// Клик — переход на экран описания тренировки.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.item,
    required this.userId,
  });

  final RouteWorkoutItem item;
  final int userId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openActivityDescription(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(0),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkShadowSoft
                  : AppColors.shadowSoft,
              offset: const Offset(0, 1),
              blurRadius: 1,
              spreadRadius: 0,
            ),
          ],
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
      debugPrint('Open activity error: $e $st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}

class _ResultRow extends StatefulWidget {
  const _ResultRow({required this.item, required this.userId});
  final RouteWorkoutItem item;
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

  /// Загружает данные тренировки для получения точек маршрута.
  /// Использует ту же логику, что и экран "Профиль-Тренировки".
  Future<void> _loadWorkoutData() async {
    try {
      // Загружаем данные активности для получения точек маршрута
      final map = await RoutesService().getActivityById(
        activityId: widget.item.activityId,
        userId: widget.userId,
      );
      
      if (map == null || !mounted) {
        if (mounted) setState(() { _loadingMap = false; });
        return;
      }
      
      final ta = TrainingActivity.fromJson(map);
      final points = ta.points.map((p) => LatLng(p.lat, p.lng)).toList();
      
      if (mounted) {
        setState(() {
          _points = points;
          _loadingMap = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMap = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _formatWhen(widget.item.when);
    final hrText = widget.item.heartRate != null ? '${widget.item.heartRate}' : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Превью карты конкретной тренировки (80x74, как на экране Профиль-Тренировки)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: _loadingMap
                ? SizedBox(
                    width: 80,
                    height: 74,
                    child: _mapPlaceholder(context),
                  )
                : _points != null && _points!.isNotEmpty
                    ? SizedBox(
                        width: 80,
                        height: 74,
                        child: _buildStaticMiniMap(
                          context,
                          _points!,
                          activityId: widget.item.activityId,
                          userId: widget.userId,
                        ),
                      )
                    : SizedBox(
                        width: 80,
                        height: 74,
                        child: _mapPlaceholder(context),
                      ),
          ),
          const SizedBox(width: 10),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
                const SizedBox(height: 10),
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
    );
  }

  /// Строит статичную мини-карту маршрута (80x74px).
  /// Использует ту же логику, что и экран "Профиль-Тренировки".
  /// 
  /// ⚡ PERFORMANCE OPTIMIZATION для маленьких карт:
  /// - Использует DPR 1.5 (вместо полного devicePixelRatio) для уменьшения веса файла
  /// - Ограничивает maxWidth/maxHeight до 160x140px для еще большей экономии
  /// - Прореживает точки (каждую 30-ю) для треков с большим количеством точек
  /// - Кеширование через CachedNetworkImage с memCacheWidth/maxWidthDiskCache
  /// - Использует сохраненные изображения карт с сервера, если они есть
  Widget _buildStaticMiniMap(
    BuildContext context,
    List<LatLng> points, {
    int? activityId,
    int? userId,
  }) {
    const widthDp = 80.0;
    const heightDp = 74.0;

    // ────────────────────────────────────────────────────────────────
    // 🔹 ПРОРЕЖИВАНИЕ ТОЧЕК: для треков с большим количеством точек
    // ────────────────────────────────────────────────────────────────
    final thinnedPoints = _thinPoints(points, step: 30);

    // Проверяем валидность прореженных точек
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

    // ────────────────────────────────────────────────────────────────
    // 🔹 ОПТИМИЗАЦИЯ РАЗМЕРА: используем ограниченный DPR для мини-карт
    // ────────────────────────────────────────────────────────────────
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final optimizedDpr = (dpr > 1.5 ? 1.5 : dpr).clamp(1.0, 1.5);

    final widthPx = (widthDp * optimizedDpr).round();
    final heightPx = (heightDp * optimizedDpr).round();

    // ────────────────────────────────────────────────────────────────
    // 🔹 ЛОГИКА: сначала проверяем кеш мини-карты, если есть - используем сохраненное
    // Если нет в кеше - генерируем Mapbox с увеличенным strokeWidth для читаемости
    // и сохраняем в фоне как мини-карту
    // ────────────────────────────────────────────────────────────────
    final routeMapService = RouteMapService();
    String mapUrl;
    bool shouldSaveAfterLoad = false;

    // Проверяем наличие сохраненной мини-карты в кеше (синхронно)
    final cachedUrl = activityId != null
        ? routeMapService.getCachedRouteMapUrl(activityId, thumbnail: true)
        : null;

    if (cachedUrl != null) {
      // Используем сохраненное изображение мини-карты из кеша
      mapUrl = cachedUrl;
      shouldSaveAfterLoad = false;
    } else {
      // Если нет в кеше - генерируем через Mapbox с увеличенным strokeWidth для читаемости
      try {
        mapUrl = StaticMapUrlBuilder.fromPoints(
          points: thinnedPoints,
          widthPx: widthPx.toDouble(),
          heightPx: heightPx.toDouble(),
          strokeWidth:
              4.0, // Увеличенная ширина линии для лучшей читаемости на маленьких картах
          padding: 8.0,
          maxWidth: 160.0, // Дополнительное ограничение для маленьких карт
          maxHeight: 140.0, // Дополнительное ограничение для маленьких карт
        );

        // Сохраняем изображение на сервер в фоне после загрузки как мини-карту
        if (activityId != null && userId != null) {
          shouldSaveAfterLoad = true;
        }

        // Проверяем сервер в фоне для следующей загрузки (на случай если уже есть на сервере)
        if (activityId != null) {
          routeMapService
              .getRouteMapUrl(activityId, thumbnail: true)
              .catchError((_) {
                // Игнорируем ошибки проверки в фоне
                return null;
              });
        }
      } catch (e) {
        // Если не удалось сгенерировать URL (например, некорректные точки),
        // возвращаем дефолтное изображение
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
      // Сохраняем изображение на сервер после успешной загрузки как мини-карту
      imageBuilder: shouldSaveAfterLoad
          ? (context, imageProvider) {
              // Сохраняем изображение асинхронно в фоне, не блокируя UI
              final routeMapService = RouteMapService();
              routeMapService.saveRouteMapFromUrl(
                activityId: activityId!,
                userId: userId!,
                mapboxUrl: mapUrl,
                thumbnail: true, // Сохраняем как мини-карту для экрана профиля
              );
              return Image(image: imageProvider);
            }
          : null,
    );
  }

  /// Прореживает точки маршрута для оптимизации построения карты.
  static List<LatLng> _thinPoints(
    List<LatLng> points, {
    int step = 30,
    int threshold = 100,
  }) {
    // Если точек мало или step <= 1, возвращаем как есть
    if (points.length <= 2 || step <= 1) {
      return points;
    }

    // Если точек меньше порога, не прореживаем
    if (points.length < threshold) {
      return points;
    }

    final thinnedPoints = <LatLng>[];

    // Всегда добавляем первую точку
    thinnedPoints.add(points.first);

    // Добавляем каждую step-ю точку, начиная с индекса step
    for (int i = step; i < points.length - 1; i += step) {
      thinnedPoints.add(points[i]);
    }

    // Всегда добавляем последнюю точку (если она еще не добавлена)
    final lastPoint = points.last;
    if (thinnedPoints.last != lastPoint) {
      thinnedPoints.add(lastPoint);
    }

    return thinnedPoints;
  }

  /// Проверяет, что точки маршрута валидны для построения карты.
  static bool _arePointsValidForMap(List<LatLng> points) {
    if (points.isEmpty || points.length < 2) {
      return false;
    }

    // Находим минимальные и максимальные координаты
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

    // Проверяем, что есть достаточный разброс координат
    // Минимум 0.001 градуса (~100 метров) для валидной карты
    const minDifference = 0.001;
    final latDifference = maxLat - minLat;
    final lngDifference = maxLng - minLng;

    return latDifference >= minDifference || lngDifference >= minDifference;
  }

  static Widget _mapPlaceholder(BuildContext context) {
    return Container(
      width: 80,
      height: 74,
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
          size: 14,
          color: iconColor ?? AppColors.getTextSecondaryColor(context),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }
}
