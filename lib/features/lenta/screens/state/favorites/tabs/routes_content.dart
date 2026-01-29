import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/services/routes_service.dart';
import '../../../../../../providers/services/auth_provider.dart';
import 'rout_description/rout_description_screen.dart';
import '../../../../../../core/widgets/transparent_route.dart';

/// Провайдер списка сохранённых маршрутов пользователя.
final myRoutesProvider = FutureProvider.family<List<SavedRouteItem>, int>(
  (ref, userId) async {
    if (userId <= 0) return [];
    return RoutesService().getMyRoutes(userId);
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
        return routesAsync.when(
          data: (routes) {
            if (routes.isEmpty) {
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
                ],
              );
            }
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final r = routes[i];
                        final userId =
                            ref.read(currentUserIdProvider).valueOrNull ?? 0;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i < routes.length - 1 ? 6 : 0,
                          ),
                          child: _SavedRouteCard(
                            route: r,
                            userId: userId,
                          ),
                        );
                      },
                      childCount: routes.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
}

/// Карточка сохранённого маршрута из API (карта по URL, метрики, сложность).
class _SavedRouteCard extends StatelessWidget {
  const _SavedRouteCard({
    required this.route,
    required this.userId,
  });

  final SavedRouteItem route;
  final int userId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          TransparentPageRoute(
            builder: (_) => RouteDescriptionScreen(
              routeId: route.id,
              userId: userId,
              initialRoute: route,
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
        padding: const EdgeInsets.all(6),
        child: _SavedRouteRow(route: route),
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
          Navigator.push(
            context,
            TransparentPageRoute(
              builder: (_) => RouteDescriptionScreen(
                routeId: 0,
                userId: 0,
                initialRoute: mockRoute,
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
        padding: const EdgeInsets.all(6),
        child: _RouteRow(e: e),
      ),
    );
  }
}

/// Строка карточки сохранённого маршрута (картинка по URL, название, чип, метрики).
class _SavedRouteRow extends StatelessWidget {
  const _SavedRouteRow({required this.route});

  final SavedRouteItem route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 12, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: route.routeMapUrl != null && route.routeMapUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: route.routeMapUrl!,
                    width: 80,
                    height: 76,
                    fit: BoxFit.cover,
                    // Добавляем cacheKey для принудительного обновления при изменении URL
                    cacheKey: '${route.routeMapUrl}_v2',
                    errorWidget: (_, __, ___) => _mapPlaceholder(context),
                  )
                : _mapPlaceholder(context),
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
                  ],
                ),
                const SizedBox(height: 18),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 18,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.xl,
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_run,
                              size: 12,
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _RouteRow._metric(
                        context,
                        null,
                        '${route.distanceKm.toStringAsFixed(2)} км',
                        MainAxisAlignment.start,
                      ),
                      Expanded(
                        child: _RouteRow._metric(
                          context,
                          null,
                          route.durationText ?? '—',
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

  Widget _difficultyChipFromString(String d) {
    late final Color c;
    late final String t;
    switch (d) {
      case 'easy':
        c = AppColors.success;
        t = 'Лёгкий';
        break;
      case 'hard':
        c = AppColors.error;
        t = 'Сложный';
        break;
      default:
        c = AppColors.warning;
        t = 'Средний';
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
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: c,
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final _RouteItem e;
  const _RouteRow({required this.e});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 12, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
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
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 18,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.xl,
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_run,
                              size: 12,
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                      ),
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
                          e.durationText,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _difficultyChip(_Difficulty d) {
    late final Color c;
    late final String t;
    switch (d) {
      case _Difficulty.easy:
        c = AppColors.success;
        t = 'Лёгкий';
        break;
      case _Difficulty.medium:
        c = AppColors.warning;
        t = 'Средний';
        break;
      case _Difficulty.hard:
        c = AppColors.error;
        t = 'Сложный';
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
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: c,
        ),
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
