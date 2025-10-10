import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import 'rout_description/rout_description_screen.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          sliver: SliverList.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: 2), // зазор между карточками
            itemBuilder: (context, i) {
              final e = _items[i];

              // Оборачиваем карточку жестом. Навигация только для нужного маршрута.
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (e.title == 'Ладога - Лунёво - Ладога') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
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
                child: _RouteCard(e: e),
              );
            },
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(0),
        border: Border.all(color: const Color(0xFFEAEAEA), width: 0.5),
      ),
      child: _RouteRow(e: e),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final _RouteItem e;
  const _RouteRow({required this.e});

  @override
  Widget build(BuildContext context) {
    final chip = _difficultyChip(e.difficulty);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              e.asset,
              width: 90,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 90,
                height: 60,
                color: Colors.black.withValues(alpha: 0.06),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.map,
                  size: 20,
                  color: AppColors.greytext,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
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
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    chip,
                  ],
                ),
                const SizedBox(height: 8),
                // Метрики: дистанция, время, набор
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        materialIcon: Icons.directions_run,
                        text: '${e.distanceKm.toStringAsFixed(2)} км',
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        cupertinoIcon: CupertinoIcons.time,
                        text: e.durationText,
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        cupertinoIcon: CupertinoIcons.arrow_up,
                        text: '${e.ascentM} м',
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

  Widget _difficultyChip(_Difficulty d) {
    late final Color c;
    late final String t;
    switch (d) {
      case _Difficulty.easy:
        c = const Color(0xFF37C76A);
        t = 'Лёгкий';
      case _Difficulty.medium:
        c = const Color(0xFFF3A536);
        t = 'Средний';
      case _Difficulty.hard:
        c = const Color(0xFFE8534A);
        t = 'Сложный';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: c,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData? cupertinoIcon; // для Cupertino-иконок
  final IconData? materialIcon; // для Material-иконок (бегун)
  final String text;

  const _Metric({this.cupertinoIcon, this.materialIcon, required this.text});

  @override
  Widget build(BuildContext context) {
    final icon = materialIcon ?? cupertinoIcon!;
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(icon, size: 14, color: AppColors.greytext),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.text,
            ),
          ),
        ),
      ],
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
