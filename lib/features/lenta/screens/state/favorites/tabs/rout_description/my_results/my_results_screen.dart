import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../../core/widgets/interactive_back_swipe.dart';

/// Экран: Мои результаты для выбранного маршрута
/// Шапка — как в rout_description_screen.dart (без кнопки "три точки").
/// Карточки — как в routes_content.dart, без чипа сложности.
class MyResultsScreen extends StatelessWidget {
  final int routeId;
  final String routeTitle;
  final String?
  difficultyText; // можно оставить для шапки под AppBar (опционально)

  const MyResultsScreen({
    super.key,
    required this.routeId,
    required this.routeTitle,
    this.difficultyText,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),

        // ─── глобальная шапка без нижнего бордера ───
        appBar: const PaceAppBar(
          title: 'Мои результаты',
          showBottomDivider: false,
        ),

        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // — подшапка как в rout_description_screen.dart
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceColor(context),
                  boxShadow: [
                    BoxShadow(
                      // ── Тень из темы (более заметная в темной теме)
                      color: Theme.of(context).brightness == Brightness.dark
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
                        routeTitle,
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
                    if ((difficultyText ?? '').isNotEmpty)
                      Center(child: _DifficultyChip(text: difficultyText!)),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // — список карточек в стиле routes_content.dart (без чипа сложности)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              sliver: SliverList.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, i) => _ResultCard(e: _items[i]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// Чип сложности под шапкой (оставляем, как в rout_description_screen.dart)
class _DifficultyChip extends StatelessWidget {
  final String text;
  const _DifficultyChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final lc = text.toLowerCase();
    Color c;
    if (lc.contains('лёгк')) {
      c = AppColors.success;
    } else if (lc.contains('средн')) {
      c = AppColors.warning;
    } else {
      c = AppColors.error;
    }
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

/// ===== Карточка результата — оформление как в routes_content.dart, БЕЗ сложности =====
class _ResultCard extends StatelessWidget {
  final _ResultItem e;
  const _ResultCard({required this.e});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(0), // как в routes_content.dart
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            // ── Тень из темы (более заметная в темной теме)
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadowSoft
                : AppColors.shadowSoft,
            offset: const Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: _ResultRow(e: e),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final _ResultItem e;
  const _ResultRow({required this.e});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // превью 90x60 со скруглением 4 — одинаково с routes_content.dart
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: Image.asset(
              e.asset,
              width: 90,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 90,
                height: 60,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurfaceMuted
                    : AppColors.skeletonBase,
                alignment: Alignment.center,
                child: Icon(
                  CupertinoIcons.map,
                  size: 20,
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // правая часть
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Верхняя строка: заголовок (дата/время результата) — без чипа сложности
                Text(
                  e.title,
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

                // Нижняя строка-метрик с выравниванием: слева | по центру | справа
                Row(
                  children: [
                    Expanded(
                      child: _MetricAligned(
                        cupertinoIcon: CupertinoIcons.time,
                        text: e.durationText,
                        align: MainAxisAlignment.start, // влево
                        textAlign: TextAlign.left,
                        iconColor: AppColors.brandPrimary,
                      ),
                    ),
                    Expanded(
                      child: _MetricAligned(
                        materialIcon: Icons.speed,
                        text: e.paceText,
                        align: MainAxisAlignment.center, // по центру
                        textAlign: TextAlign.center,
                        iconColor: AppColors.brandPrimary,
                      ),
                    ),
                    Expanded(
                      child: _MetricAligned(
                        cupertinoIcon: CupertinoIcons.heart,
                        text: '${e.hr}',
                        align: MainAxisAlignment.center, // вправо
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
}

/// — такой же Metric, как в routes_content.dart
class _MetricAligned extends StatelessWidget {
  final IconData? cupertinoIcon;
  final IconData? materialIcon;
  final String text;
  final MainAxisAlignment align; // старт/центр/конец ряда
  final TextAlign textAlign; // выравнивание самого текста
  final Color? iconColor;

  const _MetricAligned({
    this.cupertinoIcon,
    this.materialIcon,
    required this.text,
    required this.align,
    required this.textAlign,
    this.iconColor,
  });

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
        // Flexible, чтобы корректно ужиматься при правом/центральном выравнивании
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

/// ===== Модель и мок-данные (картинки те же, что и в routes_content.dart) =====

class _ResultItem {
  final String asset; // 'assets/training_map.png'
  final String title; // '18 июня, 20:52'
  final String durationText; // '1:35:08'
  final String paceText; // '4:15 /км'
  final int hr; // 141

  const _ResultItem({
    required this.asset,
    required this.title,
    required this.durationText,
    required this.paceText,
    required this.hr,
  });
}

const _items = <_ResultItem>[
  _ResultItem(
    asset: 'assets/training_map.png',
    title: '18 июня, 20:52',
    durationText: '1:35:08',
    paceText: '4:15 /км',
    hr: 141,
  ),
  _ResultItem(
    asset: 'assets/training_map.png',
    title: '17 июня, 09:32',
    durationText: '1:34:25',
    paceText: '4:14 /км',
    hr: 143,
  ),
  _ResultItem(
    asset: 'assets/training_map.png',
    title: '16 июня, 10:35',
    durationText: '1:40:24',
    paceText: '4:22 /км',
    hr: 138,
  ),
  _ResultItem(
    asset: 'assets/training_map.png',
    title: '15 июня, 08:13',
    durationText: '1:32:57',
    paceText: '4:10 /км',
    hr: 146,
  ),
];
