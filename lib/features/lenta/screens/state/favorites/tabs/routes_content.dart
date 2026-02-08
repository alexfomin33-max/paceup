import 'dart:async';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/services/routes_service.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../edit_route_bottom_sheet.dart';
import 'rout_description/rout_description_screen.dart';
import 'rout_description/route_share_screen.dart';

// ────────────────────────────────────────────────────────────────
// Дистанция без округления (отсечение до 2 знаков, как в тренировке)
// ────────────────────────────────────────────────────────────────
String _formatDistanceKm(double km) {
  final truncated = (km * 100).truncateToDouble() / 100;
  return truncated.toStringAsFixed(2);
}

// ────────────────────────────────────────────────────────────────
// Параметры постраничной загрузки (15 элементов за шаг).
// ────────────────────────────────────────────────────────────────
const int _kRoutesPageSize = 15;
const Duration _kRoutesLoadDebounceDelay = Duration(milliseconds: 200);

/// Провайдер списка сохранённых маршрутов пользователя.
final myRoutesProvider = FutureProvider.family<RoutesPage, int>(
  (ref, userId) async {
    if (userId <= 0) {
      return const RoutesPage(
        routes: [],
        hasMore: false,
        nextOffset: 0,
      );
    }
    return RoutesService().getMyRoutesPage(
      userId: userId,
      limit: _kRoutesPageSize,
      offset: 0,
    );
  },
);

/// Вкладка «Маршруты» — загрузка из API, тот же макет (карта, название, сложность, метрики).
/// При заходе на экран инвалидирует провайдер списка маршрутов для актуальных данных.
class RoutesContent extends ConsumerStatefulWidget {
  const RoutesContent({super.key});

  @override
  ConsumerState<RoutesContent> createState() => _RoutesContentState();
}

class _RoutesContentState extends ConsumerState<RoutesContent> {
  bool _didRequestRefresh = false;
  // ────────────────────────────────────────────────────────────────
  // Локальные данные для пагинации и оптимистических правок.
  // ────────────────────────────────────────────────────────────────
  bool _needsProviderSeed = true;
  List<SavedRouteItem> _localRoutes = const [];
  int _localUserId = 0;
  bool _hasMore = false;
  int _nextOffset = 0;
  bool _isLoadingMore = false;
  final Set<int> _seenRouteIds = <int>{};
  Timer? _loadDebounceTimer;

  @override
  void dispose() {
    // ── Отменяем таймер подгрузки, чтобы не вызвать setState после dispose
    _loadDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Однократное обновление данных при появлении вкладки (после первого кадра)
    if (!_didRequestRefresh) {
      _didRequestRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final uid = ref.read(currentUserIdProvider).valueOrNull ?? 0;
        if (uid > 0) ref.invalidate(myRoutesProvider(uid));
      });
    }
    final userIdAsync = ref.watch(currentUserIdProvider);
    return userIdAsync.when(
      data: (userId) {
        final uid = userId ?? 0;
        final routesAsync = ref.watch(myRoutesProvider(uid));
        if (routesAsync.isLoading) {
          _needsProviderSeed = true;
        }
        return routesAsync.when(
          data: (page) {
            final viewRoutes = _resolveRoutesData(
              userId: uid,
              page: page,
              shouldSeed: _needsProviderSeed,
            );
            _needsProviderSeed = false;
            if (viewRoutes.isEmpty) {
              // До плашки меню: навбар 60 + запас 12 + viewPadding
              final bottomPadding =
                  MediaQuery.of(context).viewPadding.bottom + 60 + 12;
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'Нет сохранённых маршрутов',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
                ],
              );
            }
            // До плашки меню: навбар 60 + запас 12 + viewPadding
            final bottomPadding =
                MediaQuery.of(context).viewPadding.bottom + 60 + 12;
            final totalCount = viewRoutes.length;
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
               
                // ── Краткое описание вкладки (иконка + текст, без фона)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20,20,12,20 ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [


                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Сохранённые маршруты',
                                style: AppTextStyles.h14w5.copyWith(
                                  color: AppColors.getTextPrimaryColor(
                                    context,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Нажмите на карточку, чтобы открыть '
                                'детали, статистику и результаты.',
                                style: AppTextStyles.h14w4.copyWith(
                                  color: AppColors.getTextSecondaryColor(
                                    context,
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
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        // ── Подгружаем следующую страницу при скролле вниз
                        _maybeLoadMore(
                          index: i,
                          totalCount: totalCount,
                          userId: uid,
                        );
                        final r = viewRoutes[i];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i < totalCount - 1 ? 6 : 0,
                          ),
                          child: _SavedRouteCard(
                            // ── Стабильный ключ элемента, чтобы снизить переразметку
                            key: ValueKey(r.id),
                            route: r,
                            userId: uid,
                            onRouteUpdated: (name, difficulty) {
                              _applyOptimisticUpdate(
                                routeId: r.id,
                                name: name,
                                difficulty: difficulty,
                              );
                            },
                            onRouteDeleted: () {
                              _applyOptimisticDelete(routeId: r.id);
                              if (uid > 0) {
                                ref.invalidate(myRoutesProvider(uid));
                              }
                            },
                          ),
                        );
                      },
                      childCount: totalCount,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
              ],
            );
          },
          loading: () => const Center(
            child: CupertinoActivityIndicator(
              radius: 12,
              color: AppColors.brandPrimary,
            ),
          ),
          error: (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText.rich(
                TextSpan(
                  text: 'Ошибка: ${e.toString()}',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CupertinoActivityIndicator(
          radius: 12,
          color: AppColors.brandPrimary,
        ),
      ),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText.rich(
            TextSpan(
              text: 'Ошибка: ${e.toString()}',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Синхронизация данных: берём свежую страницу от провайдера.
  // ────────────────────────────────────────────────────────────────
  List<SavedRouteItem> _resolveRoutesData({
    required int userId,
    required RoutesPage page,
    required bool shouldSeed,
  }) {
    final needsUserReset = _localUserId != userId;
    if (needsUserReset) {
      _resetLocalState(userId: userId);
    }
    if (shouldSeed || needsUserReset) {
      _seedFromProvider(page: page);
    }
    return _localRoutes;
  }

  // ────────────────────────────────────────────────────────────────
  // Сброс локального состояния (используем при смене пользователя).
  // ────────────────────────────────────────────────────────────────
  void _resetLocalState({required int userId}) {
    _localUserId = userId;
    _localRoutes = const [];
    _seenRouteIds.clear();
    _hasMore = false;
    _nextOffset = 0;
    _isLoadingMore = false;
    _loadDebounceTimer?.cancel();
    _loadDebounceTimer = null;
  }

  // ────────────────────────────────────────────────────────────────
  // Инициализация локальных данных из первой страницы провайдера.
  // ────────────────────────────────────────────────────────────────
  void _seedFromProvider({required RoutesPage page}) {
    _localRoutes = page.routes;
    _seenRouteIds
      ..clear()
      ..addAll(page.routes.map((r) => r.id));
    _hasMore = page.hasMore;
    _nextOffset = page.nextOffset;
    _isLoadingMore = false;
  }

  // ────────────────────────────────────────────────────────────────
  // Постраничная подгрузка при достижении конца списка.
  // ────────────────────────────────────────────────────────────────
  void _maybeLoadMore({
    required int index,
    required int totalCount,
    required int userId,
  }) {
    if (userId <= 0) return;
    if (totalCount == 0) return;
    if (index != totalCount - 1) return;
    if (!_hasMore) return;
    if (_isLoadingMore) return;
    if (_loadDebounceTimer?.isActive ?? false) return;
    _isLoadingMore = true;
    // ── Debounce: защищаемся от частых вызовов на быстром скролле
    _loadDebounceTimer = Timer(_kRoutesLoadDebounceDelay, () {
      _loadDebounceTimer = null;
      if (!mounted) return;
      _loadNextPage(userId: userId);
    });
  }

  // ────────────────────────────────────────────────────────────────
  // Загрузка следующей страницы с сервера.
  // ────────────────────────────────────────────────────────────────
  Future<void> _loadNextPage({required int userId}) async {
    try {
      final page = await RoutesService().getMyRoutesPage(
        userId: userId,
        limit: _kRoutesPageSize,
        offset: _nextOffset,
      );
      if (!mounted) return;
      setState(() {
        final newItems = page.routes
            .where((item) => _seenRouteIds.add(item.id))
            .toList();
        _localRoutes = [
          ..._localRoutes,
          ...newItems,
        ];
        _hasMore = page.hasMore;
        _nextOffset = page.nextOffset;
        _isLoadingMore = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      log(
        'Routes pagination load error: $e',
        stackTrace: st,
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Проверка: данные маршрута уже совпадают, обновление не нужно.
  // ────────────────────────────────────────────────────────────────
  bool _hasSameData({
    required int routeId,
    required String name,
    required String difficulty,
  }) {
    for (final item in _localRoutes) {
      if (item.id == routeId) {
        return item.name == name && item.difficulty == difficulty;
      }
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────────
  // Оптимистическое обновление имени и сложности маршрута.
  // ────────────────────────────────────────────────────────────────
  void _applyOptimisticUpdate({
    required int routeId,
    required String name,
    required String difficulty,
  }) {
    if (_localRoutes.isEmpty) return;
    // ── Ранний выход: данные не изменились, setState не нужен
    if (_hasSameData(
      routeId: routeId,
      name: name,
      difficulty: difficulty,
    )) {
      return;
    }
    final updated = _updateRouteInList(
      routeId: routeId,
      name: name,
      difficulty: difficulty,
    );
    setState(() {
      _localRoutes = updated;
    });
  }

  // ────────────────────────────────────────────────────────────────
  // Оптимистическое удаление маршрута из локального списка.
  // ────────────────────────────────────────────────────────────────
  void _applyOptimisticDelete({required int routeId}) {
    if (_localRoutes.isEmpty) return;
    final updated = _localRoutes
        .where((item) => item.id != routeId)
        .toList();
    if (updated.length == _localRoutes.length) return;
    setState(() {
      _localRoutes = updated;
    });
  }

  // ────────────────────────────────────────────────────────────────
  // Обновление данных маршрута в списке (иммутабельное копирование).
  // ────────────────────────────────────────────────────────────────
  List<SavedRouteItem> _updateRouteInList({
    required int routeId,
    required String name,
    required String difficulty,
  }) {
    return _localRoutes.map((item) {
      if (item.id != routeId) {
        return item;
      }
      return SavedRouteItem(
        id: item.id,
        name: name,
        difficulty: difficulty,
        distanceKm: item.distanceKm,
        ascentM: item.ascentM,
        routeMapUrl: item.routeMapUrl,
        bestDurationSec: item.bestDurationSec,
        lastDurationSec: item.lastDurationSec,
        durationText: item.durationText,
      );
    }).toList();
  }
}

/// Карточка сохранённого маршрута из API (карта по URL, метрики, сложность).
class _SavedRouteCard extends StatelessWidget {
  const _SavedRouteCard({
    super.key,
    required this.route,
    required this.userId,
    required this.onRouteUpdated,
    required this.onRouteDeleted,
  });

  final SavedRouteItem route;
  final int userId;
  final void Function(String name, String difficulty) onRouteUpdated;
  final VoidCallback onRouteDeleted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // ── Открываем экран описания маршрута без нижнего навигационного меню
        // ── Используем TransparentPageRoute для отображения предыдущей страницы при свайпе назад
        pushWithoutNavBar(
          context,
          TransparentPageRoute(
            builder: (_) => RouteDescriptionScreen(
              routeId: route.id,
              userId: userId,
              initialRoute: route,
              isInitiallySaved: true,
              onRouteDeleted: onRouteDeleted,
              onRouteUpdated: onRouteUpdated,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.twinchip,
            width: 1.0,
          ),
        ),
        // Отступы как в карточках training_tab: all(6) + fromLTRB(2,2,12,2)
        padding: const EdgeInsets.all(6),
        child: _SavedRouteRow(
          route: route,
          onEdit: () {
            showEditRouteBottomSheet(
              context,
              route: route,
              userId: userId,
              onSaved: (name, difficulty) {
                onRouteUpdated(name, difficulty);
              },
            );
          },
          onDelete: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Удалить маршрут?'),
                content: Text(
                  'Маршрут «${route.name}» будет удалён из избранного.',
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
            if (confirm != true || !context.mounted) return;
            try {
              await RoutesService().deleteRoute(
                routeId: route.id,
                userId: userId,
              );
              if (context.mounted) onRouteDeleted();
            } catch (e) {
              if (context.mounted) {
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
          },
          // ───────────────────────────────────────────────────────
          // Репост маршрута в чат: доступно для автора/сохранившего
          // ───────────────────────────────────────────────────────
          onShare: (userId > 0 && route.id > 0)
              ? () {
                  // ── Открываем экран выбора чата (личный/клуб)
                  Navigator.of(context, rootNavigator: true).push(
                    TransparentPageRoute(
                      builder: (_) => RouteShareScreen(
                        routeId: route.id,
                        userId: userId,
                        routeName: route.name,
                      ),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final _RouteItem e;
  const _RouteCard({required this.e});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (e.title == 'Ладога - Лунёво - Ладога') {
          final mockRoute = SavedRouteItem(
            id: 0,
            name: e.title,
            difficulty: _difficultyKey(e.difficulty),
            distanceKm: e.distanceKm,
            ascentM: e.ascentM,
            durationText: e.durationText,
          );
          // ── Открываем экран описания маршрута без нижнего навигационного меню
          // ── Используем TransparentPageRoute для отображения предыдущей страницы при свайпе назад
          pushWithoutNavBar(
            context,
            TransparentPageRoute(
              builder: (_) => RouteDescriptionScreen(
                routeId: 0,
                userId: 0,
                initialRoute: mockRoute,
                isInitiallySaved: false,
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.twinchip,
            width: 1.0,
          ),
        ),
        // Отступы как в карточках training_tab
        padding: const EdgeInsets.all(6),
        child: _RouteRow(e: e),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Бейдж «бег» для метрик: общий константный виджет
// ───────────────────────────────────────────────────────────────
class _RouteRunBadge extends StatelessWidget {
  const _RouteRunBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // ── Фиксированная ширина нужна для стабильного выравнивания метрик
    return const SizedBox(
      width: 18,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 18,
          height: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              borderRadius: BorderRadius.all(
                Radius.circular(AppRadius.xl),
              ),
            ),
            child: Icon(
              Icons.directions_run,
              size: 12,
              color: AppColors.surface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка карточки сохранённого маршрута (картинка по URL, название, чип, метрики).
class _SavedRouteRow extends StatelessWidget {
  const _SavedRouteRow({
    required this.route,
    required this.onEdit,
    required this.onDelete,
    this.onShare,
  });

  final SavedRouteItem route;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    // ── Размеры кэша для карты в пикселях
    // ── (с учётом DPR)
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (80 * dpr).round();
    final cacheHeight = (76 * dpr).round();
    // Внутренний отступ карточки — как в training_tab _WorkoutCard
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 12, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ───────────────────────────────────────────────────────
          // Превью карты: изоляция перерисовок карточки
          // ───────────────────────────────────────────────────────
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: route.routeMapUrl != null &&
                      route.routeMapUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: route.routeMapUrl!,
                      width: 80,
                      height: 76,
                      fit: BoxFit.cover,
                      memCacheWidth: cacheWidth,
                      memCacheHeight: cacheHeight,
                      // Добавляем cacheKey для принудительного обновления при изменении URL
                      cacheKey: '${route.routeMapUrl}_v2',
                      errorWidget: (_, __, ___) => _mapPlaceholder(context),
                    )
                  : _mapPlaceholder(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        route.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _difficultyChipFromString(route.difficulty),
                    const SizedBox(width: 4),
                    // Иконка «три точки» — меню; фиксированная ширина, прижата к правому краю
                    SizedBox(
                      width: 16,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.xll),
                          ),
                          color: AppColors.surface,
                          elevation: 8,
                          icon: Icon(
                            Icons.more_vert,
                            size: 20,
                            color:
                                AppColors.getIconSecondaryColor(context),
                          ),
                          onSelected: (value) {
                            if (value == 'share') {
                              onShare?.call();
                            } else if (value == 'edit') {
                              onEdit();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder: (ctx) {
                            // ─────────────────────────────────────
                            // Список пунктов меню маршрута (по доступу)
                            // ─────────────────────────────────────
                            final items = <PopupMenuEntry<String>>[];
                            if (onShare != null) {
                              items.add(
                                PopupMenuItem<String>(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.share,
                                        size: 22,
                                        color: AppColors.brandPrimary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Поделиться',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          color:
                                              AppColors.getTextPrimaryColor(
                                            ctx,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            items.addAll([
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
                                        color:
                                            AppColors.getTextPrimaryColor(
                                          ctx,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline,
                                      size: 22,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Удалить',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]);
                            return items;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // ─────────────────────────────────────────────
                // Метрики маршрута: лёгкий Row без IntrinsicHeight
                // ─────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const _RouteRunBadge(),
                    const SizedBox(width: 6),
                    _RouteRow._metric(
                      context,
                      null,
                      '${_formatDistanceKm(route.distanceKm)} км',
                      MainAxisAlignment.start,
                    ),
                    Expanded(
                      child: _RouteRow._metric(
                        context,
                        null,
                        _RouteRow._durationWithoutMin(route.durationText),
                        MainAxisAlignment.center,
                      ),
                    ),
                    _RouteRow._metric(
                      context,
                      null,
                      '${route.ascentM} м',
                      MainAxisAlignment.start,
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

  Widget _mapPlaceholder(BuildContext context) {
    return Container(
      width: 80,
      height: 76,
      color: AppColors.getBackgroundColor(context),
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.map,
        size: 24,
        color: AppColors.getIconSecondaryColor(context),
      ),
    );
  }

  /// Сложность маршрута — иконка огня (Cupertino) с цветом по уровню.
  Widget _difficultyChipFromString(String d) {
    late final Color c;
    switch (d) {
      case 'easy':
        c = AppColors.success;
        break;
      case 'hard':
        c = AppColors.error;
        break;
      default:
        c = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Icon(
        CupertinoIcons.flame_fill,
        size: 14,
        color: c,
      ),
    );
  }
}

/// Строка карточки для мока (_RouteCard). Список маршрутов использует
/// _SavedRouteCard → _SavedRouteRow — отступы менять там (стр. ~329).
class _RouteRow extends StatelessWidget {
  final _RouteItem e;
  const _RouteRow({required this.e});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 12, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ───────────────────────────────────────────────────────
          // Превью карты: изоляция перерисовок карточки
          // ───────────────────────────────────────────────────────
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.asset(
                e.asset,
                width: 80,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 80,
                  height: 76,
                  color: AppColors.getBackgroundColor(context),
                  alignment: Alignment.center,
                  child: Icon(
                    CupertinoIcons.map,
                    size: 24,
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Огонёк (сложность) сразу после названия маршрута
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _difficultyChip(e.difficulty),
                  ],
                ),
                const SizedBox(height: 18),
                // ─────────────────────────────────────────────
                // Метрики маршрута: лёгкий Row без IntrinsicHeight
                // ─────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const _RouteRunBadge(),
                    const SizedBox(width: 6),
                    _RouteRow._metric(
                      context,
                      null,
                      '${e.distanceKm.toStringAsFixed(2)} км',
                      MainAxisAlignment.start,
                    ),
                    Expanded(
                      child: _RouteRow._metric(
                        context,
                        null,
                        _RouteRow._durationWithoutMin(e.durationText),
                        MainAxisAlignment.center,
                      ),
                    ),
                    _RouteRow._metric(
                      context,
                      null,
                      '${e.ascentM} м',
                      MainAxisAlignment.start,
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

  /// Убирает суффикс «мин» у строки времени для отображения в карточке.
  static String _durationWithoutMin(String? s) {
    if (s == null || s.isEmpty) return '—';
    final t = s.replaceFirst(RegExp(r'\s*мин\s*$'), '').trim();
    return t.isEmpty ? '—' : t;
  }

  /// Отображает метрику с выравниванием по левому краю
  static Widget _metric(
    BuildContext context,
    IconData? icon,
    String text,
    MainAxisAlignment alignment,
  ) {
    // Разделяем текст на числовую часть и единицы измерения
    final unitPattern = RegExp(
      r'\s*(км|м|ч|мин|сек|/км|/100м|км/ч|м/с)\s*$',
      caseSensitive: false,
    );
    final match = unitPattern.firstMatch(text);

    String numberPart = text;
    String? unitPart;

    if (match != null) {
      numberPart = text.substring(0, match.start).trim();
      unitPart = match.group(0)?.trim();
    }

    return Row(
      mainAxisAlignment: alignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.getTextSecondaryColor(context)),
          const SizedBox(width: 8),
        ],
        Text.rich(
          TextSpan(
            text: numberPart,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimaryColor(context),
            ),
            children: unitPart != null
                ? [
                    TextSpan(
                      text: ' $unitPart',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }

  /// Сложность маршрута — иконка огня (Cupertino) с цветом по уровню.
  Widget _difficultyChip(_Difficulty d) {
    late final Color c;
    switch (d) {
      case _Difficulty.easy:
        c = AppColors.success;
        break;
      case _Difficulty.medium:
        c = AppColors.warning;
        break;
      case _Difficulty.hard:
        c = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Icon(
        CupertinoIcons.flame_fill,
        size: 14,
        color: c,
      ),
    );
  }
}

enum _Difficulty { easy, medium, hard }

class _RouteItem {
  final String asset;
  final String title;
  final double distanceKm;
  final int ascentM;
  final String durationText;
  final _Difficulty difficulty;

  const _RouteItem({
    required this.asset,
    required this.title,
    required this.distanceKm,
    required this.ascentM,
    required this.durationText,
    required this.difficulty,
  });
}
// — утилита: перевод enum сложности в строковый ключ для экрана описания
String _difficultyKey(_Difficulty d) {
  switch (d) {
    case _Difficulty.easy:
      return 'easy';
    case _Difficulty.medium:
      return 'medium';
    case _Difficulty.hard:
      return 'hard';
  }
}

