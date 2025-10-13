import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Sliver-контент для вкладки «Медали»
List<Widget> buildMedalsSlivers() {
  const green = Color(0xFFE9F7E3);
  const yellow = Color(0xFFFFF0D9);

  // ИЮНЬ 2025 — зелёный тинт у выполненных
  final june = <_MedalSpec>[
    const _MedalSpec(CupertinoIcons.star, '5 дней', done: true, tint: green),
    const _MedalSpec(CupertinoIcons.star, '10 дней'),
    const _MedalSpec(CupertinoIcons.star, '15 дней'),
    const _MedalSpec(CupertinoIcons.star, '20 дней'),
    const _MedalSpec(Icons.directions_run, '50 км', done: true, tint: green),
    const _MedalSpec(Icons.directions_run, '100 км', done: true, tint: green),
    const _MedalSpec(Icons.directions_run, '200 км'),
    const _MedalSpec(Icons.directions_run, '300 км'),
    const _MedalSpec(CupertinoIcons.arrow_up, '500 м', done: true, tint: green),
    const _MedalSpec(CupertinoIcons.arrow_up, '1000 м'),
    const _MedalSpec(CupertinoIcons.arrow_up, '1500 м'),
    const _MedalSpec(CupertinoIcons.arrow_up, '2000 м'),
    const _MedalSpec(
      CupertinoIcons.stopwatch,
      '250 мин',
      done: true,
      tint: green,
    ),
    const _MedalSpec(
      CupertinoIcons.stopwatch,
      '500 мин',
      done: true,
      tint: green,
    ),
    const _MedalSpec(CupertinoIcons.stopwatch, '1000 мин'),
    const _MedalSpec(CupertinoIcons.stopwatch, '2000 мин'),
  ];

  // МАЙ 2025 — жёлтый тинт у выполненных
  final may = <_MedalSpec>[
    const _MedalSpec(CupertinoIcons.star, '5 дней', done: true, tint: yellow),
    const _MedalSpec(CupertinoIcons.star, '10 дней', done: true, tint: yellow),
    const _MedalSpec(CupertinoIcons.star, '15 дней', done: true, tint: yellow),
    const _MedalSpec(CupertinoIcons.star, '20 дней', done: true, tint: yellow),
    const _MedalSpec(Icons.directions_run, '50 км', done: true, tint: yellow),
    const _MedalSpec(Icons.directions_run, '100 км', done: true, tint: yellow),
    const _MedalSpec(Icons.directions_run, '200 км', done: true, tint: yellow),
    const _MedalSpec(Icons.directions_run, '300 км'),
    const _MedalSpec(
      CupertinoIcons.arrow_up,
      '500 м',
      done: true,
      tint: yellow,
    ),
    const _MedalSpec(
      CupertinoIcons.arrow_up,
      '1000 м',
      done: true,
      tint: yellow,
    ),
    const _MedalSpec(
      CupertinoIcons.arrow_up,
      '1500 м',
      done: true,
      tint: yellow,
    ),
    const _MedalSpec(
      CupertinoIcons.arrow_up,
      '2000 м',
      done: true,
      tint: yellow,
    ),
    const _MedalSpec(
      CupertinoIcons.stopwatch,
      '250 мин',
      done: true,
      tint: yellow,
    ),
    const _MedalSpec(
      CupertinoIcons.stopwatch,
      '500 мин',
      done: true,
      tint: yellow,
    ),
    const _MedalSpec(
      CupertinoIcons.stopwatch,
      '1000 мин',
      done: true,
      tint: yellow,
    ),
    const _MedalSpec(CupertinoIcons.stopwatch, '2000 мин'),
  ];

  return [
    const SliverToBoxAdapter(child: _SectionTitle('Июнь 2025')),
    const SliverToBoxAdapter(child: SizedBox(height: 10)),
    SliverToBoxAdapter(child: _MedalsMonthCard(items: june)),

    // ⬆️ карточка июня — увеличиваем отступ до «Май 2025»
    const SliverToBoxAdapter(child: SizedBox(height: 20)),

    const SliverToBoxAdapter(child: _SectionTitle('Май 2025')),
    const SliverToBoxAdapter(child: SizedBox(height: 10)),
    SliverToBoxAdapter(child: _MedalsMonthCard(items: may)),
    const SliverToBoxAdapter(child: SizedBox(height: 12)),
  ];
}

/// ───────────── UI helpers ─────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _MedalSpec {
  final IconData icon;
  final String label;
  final bool done;
  final Color? tint;
  const _MedalSpec(this.icon, this.label, {this.done = false, this.tint});
}

/// Карточка месяца: без тени, только тонкий бордер 0.5
class _MedalsMonthCard extends StatelessWidget {
  final List<_MedalSpec> items;
  const _MedalsMonthCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: const Color(0xFFEAEAEA),
            width: 0.5,
          ), // ← тонкий бордер
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: _BadgesWrap(items: items),
      ),
    );
  }
}

/// Wrap даёт ровно 4 колонки без дробной ширины
class _BadgesWrap extends StatelessWidget {
  final List<_MedalSpec> items;
  const _BadgesWrap({required this.items});

  static const _cols = 4;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = (c.maxWidth - _gap * (_cols - 1)) / _cols;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: items
              .map(
                (e) => SizedBox(
                  width: w,
                  child: _MedalBadge(spec: e),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

/// Бейдж как в tasks_screen.dart: кружок + маленькая подпись на нижней кромке
class _MedalBadge extends StatelessWidget {
  final _MedalSpec spec;
  const _MedalBadge({required this.spec});

  @override
  Widget build(BuildContext context) {
    final done = spec.done;
    final circle = done
        ? (spec.tint ?? const Color(0xFFEFF6EE))
        : const Color(0xFFF1F3F5);
    final iconColor = done ? AppColors.text : AppColors.greytext;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // круг с иконкой
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
            child: Icon(spec.icon, size: 26, color: iconColor),
          ),
          // подпись как в _IconBadge из tasks_screen.dart
          Positioned(
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
