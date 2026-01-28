import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';
import 'rout_description/rout_description_screen.dart';
import '../../../../../../core/widgets/transparent_route.dart';

/// Вкладка «Маршруты» — таблица с чипом сложности
class RoutesContent extends StatelessWidget {
  const RoutesContent({super.key});

  static const _items = <_RouteItem>[
    _RouteItem(
      asset: 'assets/training_map.png',
      title: 'Ладога - Лунёво',
      distanceKm: 8.01,
      ascentM: 115,
      durationText: '42:37',
      difficulty: _Difficulty.easy,
    ),
    _RouteItem(
      asset: 'assets/training_map.png',
      title: 'Ладога - Лунёво - Ладога',
      distanceKm: 16.03,
      ascentM: 203,
      durationText: '1:25:46',
      difficulty: _Difficulty.hard,
    ),
    _RouteItem(
      asset: 'assets/training_map.png',
      title: 'Круг по центру города',
      distanceKm: 11.57,
      ascentM: 168,
      durationText: '1:02:35',
      difficulty: _Difficulty.medium,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final e = _items[i];
                return Padding(
                  padding: EdgeInsets.only(bottom: i < _items.length - 1 ? 6 : 0),
                  child: _RouteCard(e: e),
                );
              },
              childCount: _items.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
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
        // Навигация только для нужного маршрута
        if (e.title == 'Ладога - Лунёво - Ладога') {
          Navigator.push(
            context,
            TransparentPageRoute(
              builder: (_) => RouteDescriptionScreen(
                title: e.title,
                mapAsset: e.asset,
                distanceKm: e.distanceKm,
                durationText: e.durationText,
                ascentM: e.ascentM,
                difficulty: _difficultyKey(
                  e.difficulty,
                ), // 'easy'|'medium'|'hard'
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
                // Заголовок + чип сложности
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
                // Три метрики — строго таблично, выровнены по левому краю
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Иконка вида спорта в отдельной колонке с фиксированной шириной
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
      case _Difficulty.medium:
        c = AppColors.warning;
        t = 'Средний';
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
