import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../core/services/routes_service.dart';
import '../../../../../../../../core/widgets/app_bar.dart'; // ← глобальный AppBar
import '../../../../../../profile/screens/profile_screen.dart';
import 'my_results/my_results_screen.dart';
import 'all_results/all_results_screen.dart';
import 'members_route/members_route_screen.dart';
import '../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../core/widgets/transparent_route.dart';
import '../../edit_route_bottom_sheet.dart';

/// Экран описания маршрута. Загружает детали из API (дата, автор, рекорды).
class RouteDescriptionScreen extends StatefulWidget {
  const RouteDescriptionScreen({
    super.key,
    required this.routeId,
    required this.userId,
    required this.initialRoute,
    this.onRouteDeleted,
  });

  final int routeId;
  final int userId;
  final SavedRouteItem initialRoute;
  /// Вызывается после удаления маршрута; затем выполняется pop на экран избранных.
  final VoidCallback? onRouteDeleted;

  @override
  State<RouteDescriptionScreen> createState() => _RouteDescriptionScreenState();
}

class _RouteDescriptionScreenState extends State<RouteDescriptionScreen> {
  RouteDetail? _detail;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
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
    } catch (e, st) {
      if (mounted) setState(() { _error = e; _loading = false; });
      debugPrint('RouteDetail load error: $e $st');
    }
  }

  String get _title =>
      _detail?.name ?? widget.initialRoute.name;
  String get _mapAsset => 'assets/training_map.png';
  String? get _mapImageUrl =>
      _detail?.routeMapUrl ?? widget.initialRoute.routeMapUrl;
  double get _distanceKm =>
      _detail != null ? _detail!.distanceKm : widget.initialRoute.distanceKm;
  /// Время: при загруженных деталях — лучшее время лидера маршрута (самого быстрого),
  /// иначе личный рекорд или из списка.
  String get _durationText {
    final leaderTime = _detail?.leaderBestDurationText;
    if (leaderTime != null && leaderTime.isNotEmpty && leaderTime != '—') {
      return leaderTime;
    }
    final pb = _detail?.personalBestText;
    if (pb != null && pb.isNotEmpty && pb != '—') return pb;
    return widget.initialRoute.durationText ?? '—';
  }
  int get _ascentM =>
      _detail != null ? _detail!.ascentM : widget.initialRoute.ascentM;
  String get _difficulty =>
      _detail?.difficulty ?? widget.initialRoute.difficulty;

  static Widget _mapPlaceholder(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceMuted
            : AppColors.skeletonBase,
        alignment: Alignment.center,
        child: Icon(
          CupertinoIcons.map,
          size: 28,
          color: AppColors.getTextSecondaryColor(context),
        ),
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

  @override
  Widget build(BuildContext context) {
    final chip = _difficultyChip(_difficulty);
    final createdText = _loading && _detail == null
        ? '—'
        : _formatCreatedAt(_detail?.createdAt);
    // Лидер — самый быстрый по маршруту; если нет результатов — не показываем блок
    final leader = _detail?.leader;
    final personalBestText = _detail?.personalBestText ?? '—';
    final myWorkoutsCount = _detail?.myWorkoutsCount ?? 0;
    final participantsCount = _detail?.participantsCount ?? 0;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: PaceAppBar(
          title: 'Маршрут',
          showBottomDivider: false, // ← без нижней линии
          actions: [
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xll),
              ),
              color: AppColors.surface,
              elevation: 8,
              icon: Icon(
                Icons.more_horiz,
                size: 20,
                color: AppColors.getIconSecondaryColor(context),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  showEditRouteBottomSheet(
                    context,
                    route: widget.initialRoute,
                    userId: widget.userId,
                    onSaved: () {
                      _loadDetail();
                    },
                  );
                } else if (value == 'delete') {
                  _confirmAndDeleteRoute(context);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
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
                          color: AppColors.getTextPrimaryColor(ctx),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 22,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 12),
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
            ),
          ],
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
                onRefresh: () async {
                  await _loadDetail();
                },
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                  // ── Заголовок + чип — по центру
                  SliverToBoxAdapter(
                    child: Container(
                      color: AppColors.getSurfaceColor(context),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              _title,
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
                          Center(child: chip),
                          const SizedBox(height: 12),
                          Text(
                            'Создан: $createdText',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Лидер: самый быстрый по маршруту (аватар и имя), кликабельно — переход в профиль
                          if (leader != null)
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  TransparentPageRoute(
                                    builder: (_) => ProfileScreen(
                                      userId: leader.id,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.emoji_events_outlined,
                                    size: 22,
                                    color: AppColors.gold,
                                  ),
                                  const SizedBox(width: 8),
                                  leader.avatar.isNotEmpty
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: leader.avatar,
                                            width: 36,
                                            height: 36,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                _avatarPlaceholder(context),
                                          ),
                                        )
                                      : CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? AppColors.darkSurfaceMuted
                                                  : AppColors.skeletonBase,
                                          child:
                                              _avatarPlaceholder(context),
                                        ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      leader.fullName.isNotEmpty
                                          ? leader.fullName
                                          : '—',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Карта-превью
                  // Используем AspectRatio для сохранения пропорций и BoxFit.contain
                  // для полного отображения карты без обрезки
                  SliverToBoxAdapter(
                    child: _mapImageUrl != null && _mapImageUrl!.isNotEmpty
                        ? AspectRatio(
                            aspectRatio: 16 / 9,
                            child: CachedNetworkImage(
                              imageUrl: _mapImageUrl!,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              // Добавляем cacheKey для принудительного обновления при изменении URL
                              cacheKey: '${_mapImageUrl}_v2',
                              errorWidget: (_, __, ___) =>
                                  _mapPlaceholder(context),
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.asset(
                              _mapAsset,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, __) =>
                                  _mapPlaceholder(context),
                            ),
                          ),
                  ),

                  // ── Три метрики
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceColor(context),
                        border: Border.all(
                          color: AppColors.getBorderColor(context),
                          width: 0.5,
                        ),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: _MetricBlock(
                              label: 'Расстояние',
                              value:
                                  '${_distanceKm.toStringAsFixed(2)} км',
                            ),
                          ),
                          Expanded(
                            child: _MetricBlock(
                              label: 'Время',
                              value: _durationText,
                            ),
                          ),
                          Expanded(
                            child: _MetricBlock(
                              label: 'Набор высоты',
                              value: '$_ascentM м',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // ── Нижняя карточка: личный рекорд, мои результаты, участники
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceColor(context),
                        border: Border.all(
                          color: AppColors.getBorderColor(context),
                          width: 0.5,
                        ),
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
                      child: Column(
                        children: [
                          _ActionRow(
                            icon: CupertinoIcons.rosette,
                            title: 'Личный рекорд',
                            trailingText: personalBestText,
                            trailingChevron: false,
                            onTap: null,
                          ),
                          const _DividerLine(),
                          _ActionRow(
                            icon: CupertinoIcons.timer,
                            title: 'Мои результаты',
                            trailingText:
                                'Забегов: $myWorkoutsCount',
                            trailingChevron: true,
                            onTap: () {
                              Navigator.of(context).push(
                                TransparentPageRoute(
                                  builder: (_) => MyResultsScreen(
                                    routeId: widget.routeId,
                                    routeTitle: _title,
                                    userId: widget.userId,
                                    difficultyText:
                                        _difficultyText(_difficulty),
                                  ),
                                ),
                              );
                            },
                          ),
                          const _DividerLine(),
                          _ActionRow(
                            icon: CupertinoIcons.chart_bar_alt_fill,
                            title: 'Общие результаты',
                            trailingChevron: true,
                            onTap: () {
                              Navigator.of(context).push(
                                TransparentPageRoute(
                                  builder: (_) => AllResultsScreen(
                                    routeId: widget.routeId,
                                    routeTitle: _title,
                                    difficultyText:
                                        _difficultyText(_difficulty),
                                  ),
                                ),
                              );
                            },
                          ),
                          const _DividerLine(),
                          _ActionRow(
                            icon: CupertinoIcons.person_2_fill,
                            title: 'Все участники маршрута',
                            trailingText: '$participantsCount',
                            trailingChevron: true,
                            onTap: () {
                              Navigator.of(context).push(
                                TransparentPageRoute(
                                  builder: (_) => MembersRouteScreen(
                                    routeId: widget.routeId,
                                    routeTitle: _title,
                                    difficultyText:
                                        _difficultyText(_difficulty),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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

  static Widget _avatarPlaceholder(BuildContext context) {
    return Icon(
      CupertinoIcons.person_fill,
      size: 24,
      color: AppColors.getTextSecondaryColor(context),
    );
  }

  Widget _difficultyChip(String d) {
    late final Color c;
    late final String t;
    switch (d) {
      case 'easy':
        c = AppColors.success;
        t = 'Лёгкий маршрут';
        break;
      case 'medium':
        c = AppColors.warning;
        t = 'Средний маршрут';
        break;
      default:
        c = AppColors.error;
        t = 'Сложный маршрут';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(
        t,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: c,
        ),
      ),
    );
  }

  String _difficultyText(String d) {
    switch (d) {
      case 'easy':
        return 'Лёгкий маршрут';
      case 'medium':
        return 'Средний маршрут';
      default:
        return 'Сложный маршрут';
    }
  }
}

// ── блок метрики (без внешних паддингов у карточки)
class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;
  const _MetricBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // внутренний минимальный отступ, чтобы текст не прилипал к границам между колонками
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── строка действий: 3 колонки
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final bool trailingChevron;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    this.trailingText,
    this.trailingChevron = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            // 1-я колонка: иконка + тайтл (лево)
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.brandPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2-я колонка: trailingText (правое выравнивание)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailingText == null
                      ? const SizedBox.shrink()
                      : Text(
                          trailingText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                ),
              ),
            ),

            // 3-я колонка: chevron (правый край)
            SizedBox(
              width: 28,
              child: trailingChevron
                  ? const Icon(
                      CupertinoIcons.chevron_forward,
                      size: 16,
                      color: AppColors.brandPrimary,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 36,
      endIndent: 8,
      color: AppColors.getDividerColor(context),
    );
  }
}
