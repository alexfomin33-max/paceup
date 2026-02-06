import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../core/services/routes_service.dart';
import '../../../../../../profile/screens/profile_screen.dart';
import 'my_results/my_results_screen.dart';
import 'all_results/all_results_screen.dart';
import 'members_route/members_route_screen.dart';
import '../../../../../../../core/widgets/transparent_route.dart';

/// Данные для контента нижнего листа описания маршрута.
class RouteDescriptionSheetData {
  const RouteDescriptionSheetData({
    required this.title,
    required this.difficulty,
    required this.createdText,
    this.leader,
    required this.routeId,
    required this.userId,
    required this.distanceText,
    required this.durationText,
    required this.ascentText,
    required this.personalBestText,
    required this.myWorkoutsCount,
    required this.participantsCount,
    required this.onPersonalBestTap,
  });

  final String title;
  final String difficulty;
  final String createdText;
  final RouteAuthor? leader;
  final int routeId;
  final int userId;
  final String distanceText;
  final String durationText;
  final String ascentText;
  final String personalBestText;
  final int myWorkoutsCount;
  final int participantsCount;
  final VoidCallback? onPersonalBestTap;
}

/// Контент нижнего листа: выезжает на высоту контента, в свёрнутом виде
/// видна только верхняя часть с названием маршрута (тап — раскрыть).
class RouteDescriptionBottomSheetContent extends StatelessWidget {
  const RouteDescriptionBottomSheetContent({
    super.key,
    required this.scrollController,
    required this.dragController,
    required this.data,
  });

  final ScrollController scrollController;
  final DraggableScrollableController dragController;
  final RouteDescriptionSheetData data;

  @override
  Widget build(BuildContext context) {
    final chip = _difficultyChip(context, data.difficulty);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xll),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          // ── Планка-хэндл: тап раскрывает лист
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                dragController.animateTo(
                  0.5,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getBorderColor(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Верхняя часть (видна в свёрнутом виде): название + чип
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                dragController.animateTo(
                  0.5,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: Container(
                color: AppColors.getSurfaceColor(context),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    chip,
                  ],
                ),
              ),
            ),
          ),
          // ── Метрики под названием: Расстояние, Время, Набор высоты
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricBlock(
                      icon: Icons.straighten,
                      value: data.distanceText,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: data.onPersonalBestTap,
                      child: _MetricBlock(
                        icon: CupertinoIcons.timer,
                        value: data.durationText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MetricBlock(
                      icon: CupertinoIcons.arrow_up,
                      value: data.ascentText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Остальной контент: дата, лидер, действия
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.getSurfaceColor(context),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Text(
                  //   'Создан: ${data.createdText}',
                  //   style: TextStyle(
                  //     fontFamily: 'Inter',
                  //     fontSize: 13,
                  //     color: AppColors.getTextSecondaryColor(context),
                  //   ),
                  // ),
                  // const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: data.leader != null
                        ? InkWell(
                            key: ValueKey('leader_${data.leader!.id}'),
                            onTap: () {
                              Navigator.of(context).push(
                                TransparentPageRoute(
                                  builder: (_) => ProfileScreen(
                                    userId: data.leader!.id,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      data.leader!.avatar.isNotEmpty
                                          ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl:
                                                    data.leader!.avatar,
                                                width: 52,
                                                height: 52,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    _avatarPlaceholder(
                                                        context),
                                              ),
                                            )
                                          : CircleAvatar(
                                              radius: 26,
                                              backgroundColor:
                                                  Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? AppColors.darkSurfaceMuted
                                                  : AppColors.skeletonBase,
                                              child: _avatarPlaceholder(
                                                  context),
                                            ),
                                      Positioned(
                                        right: -3,
                                        top: -3,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.gold,
                                            border: Border.all(
                                              color: AppColors
                                                  .getSurfaceColor(context),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.emoji_events_outlined,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data.leader!.fullName.isNotEmpty
                                        ? data.leader!.fullName
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
                          )
                        : SizedBox(
                            key: const ValueKey('leader_placeholder'),
                            child: _leaderPlaceholder(context),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          // ── Карточка действий (стиль settings_screen)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: _cardDecoration(context),
                child: Column(
                  children: [
                    _ActionRow(
                      icon: CupertinoIcons.rosette,
                      title: 'Личный рекорд',
                      trailingText: data.personalBestText.replaceAll(' мин', ''),
                      trailingChevron: true,
                      onTap: data.onPersonalBestTap,
                    ),
                    _ActionRow(
                      icon: CupertinoIcons.timer,
                      title: 'Мои результаты',
                      trailingText: 'Забегов: ${data.myWorkoutsCount}',
                      trailingChevron: true,
                      onTap: () {
                        Navigator.of(context).push(
                          TransparentPageRoute(
                            builder: (_) => MyResultsScreen(
                              routeId: data.routeId,
                              routeTitle: data.title,
                              userId: data.userId,
                              difficultyText:
                                  _difficultyText(data.difficulty),
                            ),
                          ),
                        );
                      },
                    ),
                    _ActionRow(
                      icon: CupertinoIcons.chart_bar_alt_fill,
                      title: 'Общие результаты',
                      trailingChevron: true,
                      onTap: () {
                        Navigator.of(context).push(
                          TransparentPageRoute(
                            builder: (_) => AllResultsScreen(
                              routeId: data.routeId,
                              routeTitle: data.title,
                              difficultyText:
                                  _difficultyText(data.difficulty),
                            ),
                          ),
                        );
                      },
                    ),
                    _ActionRow(
                      icon: CupertinoIcons.person_2_fill,
                      title: 'Все участники маршрута',
                      trailingText: '${data.participantsCount}',
                      trailingChevron: true,
                      onTap: () {
                        Navigator.of(context).push(
                          TransparentPageRoute(
                            builder: (_) => MembersRouteScreen(
                              routeId: data.routeId,
                              routeTitle: data.title,
                              difficultyText:
                                  _difficultyText(data.difficulty),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
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

  /// Плейсхолдер строки лидера (аватар + имя), пока данные не загружены.
  static Widget _leaderPlaceholder(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.skeletonBase,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 160,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.skeletonBase,
                  borderRadius:
                      BorderRadius.circular(AppRadius.xs),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 120,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.skeletonGlow,
                  borderRadius:
                      BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _difficultyChip(BuildContext context, String d) {
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

  static String _difficultyText(String d) {
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

// ────────────────────────────────────────────────────────────────────
// Блок метрики: иконка + значение (без подписи), как в карточке маршрута
// ────────────────────────────────────────────────────────────────────
class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.getTextSecondaryColor(context);
    final primary = AppColors.getTextPrimaryColor(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: secondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Строка действий (стиль settings_screen)
// ────────────────────────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    this.trailingText,
    this.trailingChevron = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final bool trailingChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final defaultTextColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;

    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 28,
              alignment: Alignment.centerLeft,
              child: Icon(icon, size: 20, color: AppColors.brandPrimary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: TextStyle(color: defaultTextColor),
              ),
              const SizedBox(width: 10),
            ],
            if (trailingChevron)
              const Icon(
                CupertinoIcons.chevron_forward,
                size: 18,
                color: AppColors.brandPrimary,
              ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: AppColors.getSurfaceColor(context),
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
      border: const Border.fromBorderSide(
        BorderSide(color: AppColors.twinchip, width: 0.7),
      ),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkShadowSoft
              : AppColors.shadowMedium,
          offset: const Offset(0, 2),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ],
    );
