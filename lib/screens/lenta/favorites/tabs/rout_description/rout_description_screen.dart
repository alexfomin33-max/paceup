import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../theme/app_theme.dart';

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
    this.authorName = 'Константин Разумовский',
    this.authorAvatar = 'assets/Avatar_0.png',
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.text,
          ),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Назад',
        ),
        centerTitle: true,
        title: const Text(
          'Маршрут',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              CupertinoIcons.ellipsis,
              size: 18,
              color: AppColors.text,
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
              color: Colors.white,
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
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: chip),
                  const SizedBox(height: 12),

                  // Ниже можно оставить служебную инфу слева (как была)
                  Text(
                    'Создан: $createdText',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        size: 22,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black.withValues(alpha: 0.06),
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
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
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
                color: Colors.black.withValues(alpha: 0.06),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.map,
                  size: 28,
                  color: AppColors.greytext,
                ),
              ),
            ),
          ),

          // ── Три метрики — карточка БЕЗ внутренних паддингов
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFEAEAEA), width: 0.5),
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
                color: Colors.white,
                border: Border.all(color: const Color(0xFFEAEAEA), width: 0.5),
              ),
              child: const Column(
                children: [
                  _ActionRow(
                    icon: CupertinoIcons.rosette,
                    title: 'Личный рекорд',
                    trailingText: '1:32:57',
                    trailingChevron: false, // у первой строки нет галочки
                  ),
                  _DividerLine(),
                  _ActionRow(
                    icon: CupertinoIcons.timer,
                    title: 'Мои результаты',
                    trailingText: 'Забегов: 10',
                    trailingChevron: true,
                  ),
                  _DividerLine(),
                  _ActionRow(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    title: 'Общие результаты',
                    trailingChevron: true,
                  ),
                  _DividerLine(),
                  _ActionRow(
                    icon: CupertinoIcons.person_2_fill,
                    title: 'Все участники маршрута',
                    trailingText: '124',
                    trailingChevron: true,
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _difficultyChip(String d) {
    late final Color c;
    late final String t;
    switch (d) {
      case 'easy':
        c = const Color(0xFF37C76A);
        t = 'Лёгкий маршрут';
        break;
      case 'medium':
        c = const Color(0xFFF3A536);
        t = 'Средний маршрут';
        break;
      default:
        c = const Color(0xFFE8534A);
        t = 'Сложный маршрут';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: c,
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              color: AppColors.greytext,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
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

  const _ActionRow({
    required this.icon,
    required this.title,
    this.trailingText,
    this.trailingChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                  Icon(icon, size: 18, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.text,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
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
                    color: AppColors.secondary,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 0.5, color: Color(0xFFEAEAEA));
  }
}
