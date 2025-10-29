import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../../theme/app_theme.dart';
import '../../../../../../../widgets/app_bar.dart'; // ← глобальный AppBar
import 'my_results/my_results_screen.dart';
import 'all_results/all_results_screen.dart';
import 'members_route/members_route_screen.dart';
import '../../../../../../widgets/interactive_back_swipe.dart';
import '../../../../../../widgets/transparent_route.dart';

/// Экран описания маршрута (без общих виджетов)
class RouteDescriptionScreen extends StatelessWidget {
  const RouteDescriptionScreen({
    super.key,
    required this.title,
    required this.mapAsset,
    required this.distanceKm,
    required this.durationText,
    required this.ascentM,
    required this.difficulty, // 'easy' | 'medium' | 'hard'
    this.createdText = '8 июня 2025',
    this.authorName = 'Евгений Бойко',
    this.authorAvatar = 'assets/avatar_0.png',
  });

  final String title;
  final String mapAsset;
  final double distanceKm;
  final String durationText;
  final int ascentM;
  final String difficulty;

  final String createdText;
  final String authorName;
  final String authorAvatar;

  @override
  Widget build(BuildContext context) {
    final chip = _difficultyChip(difficulty);

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PaceAppBar(
          title: 'Маршрут',
          showBottomDivider: false, // ← без нижней линии
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(
                CupertinoIcons.ellipsis,
                size: 18,
                color: AppColors.iconPrimary,
              ),
              tooltip: 'Ещё',
            ),
          ],
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Заголовок + чип — по центру
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15, // меньше, чем было
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(child: chip),
                    const SizedBox(height: 12),

                    // Ниже можно оставить служебную инфу слева (как была)
                    Text(
                      'Создан: $createdText',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          size: 22,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.skeletonBase,
                          backgroundImage: AssetImage(authorAvatar),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Карта-превью — без паддингов и без скруглений
            SliverToBoxAdapter(
              child: Image.asset(
                mapAsset,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 200,
                  color: AppColors.skeletonBase,
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.map,
                    size: 28,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            // ── Три метрики — карточка БЕЗ внутренних паддингов
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricBlock(
                        label: 'Расстояние',
                        value: '${distanceKm.toStringAsFixed(2)} км',
                      ),
                    ),
                    Expanded(
                      child: _MetricBlock(label: 'Время', value: durationText),
                    ),
                    Expanded(
                      child: _MetricBlock(
                        label: 'Набор высоты',
                        value: '$ascentM м',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Нижняя карточка: 3 колонки (иконка+тайтл | правый текст | шеврон)
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    const _ActionRow(
                      icon: CupertinoIcons.rosette,
                      title: 'Личный рекорд',
                      trailingText: '1:32:57',
                      trailingChevron: false, // у первой строки нет галочки
                      onTap: null, // не кликается
                    ),
                    const _DividerLine(),
                    _ActionRow(
                      icon: CupertinoIcons.timer,
                      title: 'Мои результаты',
                      trailingText: 'Забегов: 10',
                      trailingChevron: true,
                      onTap: () {
                        Navigator.of(context).push(
                          TransparentPageRoute(
                            builder: (_) => MyResultsScreen(
                              routeId: 0, // int
                              routeTitle: title, // String
                              difficultyText: _difficultyText(
                                difficulty,
                              ), // String? (по желанию)
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
                              routeId: 0, // подставь реальный
                              routeTitle: title,
                              difficultyText: _difficultyText(difficulty),
                            ),
                          ),
                        );
                      },
                    ),
                    const _DividerLine(),
                    _ActionRow(
                      icon: CupertinoIcons.person_2_fill,
                      title: 'Все участники маршрута',
                      trailingText: '124',
                      trailingChevron: true,
                      onTap: () {
                        Navigator.of(context).push(
                          TransparentPageRoute(
                            builder: (_) => MembersRouteScreen(
                              routeId: 0, // твой id
                              routeTitle: title,
                              difficultyText: _difficultyText(difficulty),
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
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
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
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
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
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 36,
      endIndent: 8,
      color: AppColors.divider,
    );
  }
}
