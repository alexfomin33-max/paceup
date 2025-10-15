import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// возвращает список Sliver'ов для раздела "Достижения"
List<Widget> buildAchievementsSlivers() {
  final records = <_BadgeItem>[
    _BadgeItem('assets/record_1.png', '34,82 км за одну пробежку'),
    _BadgeItem('assets/record_2.png', '58 347 шагов\nза сутки'),
    _BadgeItem('assets/record_3.png', 'Подряд 28 дней\nактивности'),
    _BadgeItem('assets/record_4.png', '3,71 км за\nодин заплыв'),
    _BadgeItem('assets/record_5.png', '124 км за одну\nпоездку'),
    _BadgeItem('assets/record_6.png', '2 победы на\nсоревнованиях'),
  ];

  final ach = <_BadgeItem>[
    _BadgeItem('assets/achive_1.png', 'Полумарафон\n21,1 км', circle: true),
    _BadgeItem('assets/achive_2.png', '150 000 шагов\nза месяц', circle: true),
    _BadgeItem('assets/achive_3.png', 'Ironman, 140.6', circle: true),
    _BadgeItem(
      'assets/achive_4.webp',
      'Проплыть 5 км\nза тренировку',
      locked: true,
      circle: true,
    ),
    _BadgeItem(
      'assets/achive_5.webp',
      'Проехать 50 км\nза тренировку',
      locked: true,
      circle: true,
    ),
    _BadgeItem(
      'assets/achive_6.webp',
      '250 тренировок',
      locked: true,
      circle: true,
    ),
    _BadgeItem(
      'assets/achive_7.webp',
      'Купить или\nпродать слот',
      locked: true,
      circle: true,
    ),
    _BadgeItem(
      'assets/achive_8.webp',
      'Пригласить\n5 друзей',
      locked: true,
      circle: true,
    ),
    _BadgeItem(
      'assets/achive_9.png',
      'Активировать\nподписку PacePro',
      circle: true,
    ),
  ];

  return [
    const SliverToBoxAdapter(child: _SectionTitle('Рекорды')),
    const SliverToBoxAdapter(child: SizedBox(height: 10)),
    _BadgesSliverGrid(items: records),
    const SliverToBoxAdapter(child: SizedBox(height: 10)),
    const SliverToBoxAdapter(child: _SectionTitle('Достижения')),
    const SliverToBoxAdapter(child: SizedBox(height: 10)),
    _BadgesSliverGrid(items: ach),
  ];
}

// ===== UI вспомогательные классы =====

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
          ),
        ),
      ),
    );
  }
}

class _BadgeItem {
  final String asset;
  final String caption;
  final bool locked;
  final bool circle;
  _BadgeItem(
    this.asset,
    this.caption, {
    this.locked = false,
    this.circle = false,
  });
}

class _BadgesSliverGrid extends StatelessWidget {
  final List<_BadgeItem> items;
  const _BadgesSliverGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _BadgeTile(item: items[index]),
          childCount: items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.92,
        ),
      ),
    );
  }
}

/// Матрица для полного обесцвечивания (sRGB)
const List<double> _kGreyscaleMatrix = <double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

class _BadgeTile extends StatelessWidget {
  final _BadgeItem item;
  const _BadgeTile({required this.item});

  @override
  Widget build(BuildContext context) {
    // Базовое изображение с нужной формой (круг/скругление)
    Widget image = item.circle
        ? ClipOval(
            child: Image.asset(
              item.asset,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.asset(
              item.asset,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          );

    // Для "locked" — обесцвечиваем картинку
    if (item.locked) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_kGreyscaleMatrix),
        child: image,
      );
    }

    final content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.7),
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Column(
        children: [
          image,
          const SizedBox(height: 4),
          Text(
            item.caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
          ),
        ],
      ),
    );

    // Сохраняем существующий визуальный код: залоченные — немного "приглушены"
    if (!item.locked) return content;
    return Opacity(opacity: 0.38, child: content);
  }
}
