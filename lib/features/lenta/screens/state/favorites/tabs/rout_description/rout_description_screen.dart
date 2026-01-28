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

/// Экран описания маршрута. Загружает детали из API (дата, автор, рекорды).
class RouteDescriptionScreen extends StatefulWidget {
  const RouteDescriptionScreen({
    super.key,
    required this.routeId,
    required this.userId,
    required this.initialRoute,
  });

  final int routeId;
  final int userId;
  final SavedRouteItem initialRoute;

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

  String get _title => widget.initialRoute.name;
  String get _mapAsset => 'assets/training_map.png';
  String? get _mapImageUrl =>
      _detail?.routeMapUrl ?? widget.initialRoute.routeMapUrl;
  double get _distanceKm =>
      _detail != null ? _detail!.distanceKm : widget.initialRoute.distanceKm;
  /// Время: при загруженных деталях — личный рекорд (лучший среди забегов), иначе из списка.
  String get _durationText {
    final pb = _detail?.personalBestText;
    if (pb != null && pb.isNotEmpty && pb != '—') return pb;
    return widget.initialRoute.durationText ?? '—';
  }
  int get _ascentM =>
      _detail != null ? _detail!.ascentM : widget.initialRoute.ascentM;
  String get _difficulty =>
      _detail?.difficulty ?? widget.initialRoute.difficulty;

  static Widget _mapPlaceholder(BuildContext context) {
    return Container(
      height: 200,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceMuted
          : AppColors.skeletonBase,
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.map,
        size: 28,
        color: AppColors.getTextSecondaryColor(context),
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

  @override
  Widget build(BuildContext context) {
    final chip = _difficultyChip(_difficulty);
    final createdText = _loading && _detail == null
        ? '—'
        : _formatCreatedAt(_detail?.createdAt);
    final author = _detail?.author;
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
            IconButton(
              onPressed: () {},
              icon: Icon(
                CupertinoIcons.ellipsis,
                size: 18,
                color: AppColors.getIconPrimaryColor(context),
              ),
              tooltip: 'Ещё',
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
                          // Автор: аватар и имя из базы, кликабельно — переход в профиль
                          InkWell(
                            onTap: author != null
                                ? () {
                                    Navigator.of(context).push(
                                      TransparentPageRoute(
                                        builder: (_) => ProfileScreen(
                                          userId: author.id,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.emoji_events_outlined,
                                  size: 22,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(width: 8),
                                author != null && author.avatar.isNotEmpty
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: author.avatar,
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
                                    author != null && author.fullName.isNotEmpty
                                        ? author.fullName
                                        : '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          AppColors.getTextPrimaryColor(context),
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
                  SliverToBoxAdapter(
                    child: _mapImageUrl != null && _mapImageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _mapImageUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _mapPlaceholder(context),
                          )
                        : Image.asset(
                            _mapAsset,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, __) =>
                                _mapPlaceholder(context),
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
