import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

/// Экран описания маршрута (без внешних общих карточек)
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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(
              CupertinoIcons.ellipsis_vertical,
              size: 18,
              color: AppColors.text,
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Заголовок + чип + дата + автор
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  chip,
                  const SizedBox(height: 12),
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
                      Icon(
                        Icons.emoji_events,
                        size: 18,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 14,
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

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Карта-превью
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  mapAsset,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
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
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 10)),

          // ── Три метрики (равные колонки) — локальная "карточка"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFEAEAEA),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
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
                        child: _MetricBlock(
                          label: 'Время',
                          value: durationText,
                        ),
                      ),
                      Expanded(
                        child: _MetricBlock(
                          label: 'Набор высоты',
                          value: '${ascentM} м',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Нижний список действий — локальная "карточка"
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFEAEAEA),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(0),
                ),
                child: Column(
                  children: const [
                    _ActionRow(
                      icon: CupertinoIcons.rosette,
                      title: 'Личный рекорд',
                      trailingText: '1:32:57',
                    ),
                    _DividerLine(),
                    _ActionRow(
                      icon: CupertinoIcons.timer,
                      title: 'Мои результаты',
                      trailingText: 'Забегов: 10',
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
                    ),
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}

// — блок метрики
class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;
  const _MetricBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.greytext,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

// — строка действий
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
            if (trailingText != null)
              Text(
                trailingText!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            if (trailingChevron)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: AppColors.greytext,
                ),
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
    return const Divider(height: 1, thickness: 0.5, color: Color(0xFFEAEAEA));
  }
}
