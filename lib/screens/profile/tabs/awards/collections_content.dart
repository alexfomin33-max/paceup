import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Sliver-контент для вкладки «Коллекции»
List<Widget> buildCollectionsSlivers() {
  // ── Города Золотого кольца
  final cities = <_CollItem>[
    const _CollItem('assets/city_1.png', 'Сергиев Посад'),
    const _CollItem('assets/city_2.png', 'Переславль'),
    const _CollItem('assets/city_3.png', 'Ростов Великий'),
    const _CollItem('assets/city_4.png', 'Углич'),
    const _CollItem('assets/city_5.png', 'Ярославль'),
    const _CollItem('assets/city_6.png', 'Кострома'),
    const _CollItem('assets/city_7.png', 'Иваново'),
    const _CollItem('assets/city_8.png', 'Суздаль', locked: true),
    const _CollItem('assets/city_9.png', 'Владимир', locked: true),
  ];

  // ── Горы
  final mountains = <_CollItem>[
    const _CollItem('assets/mountain_1.png', 'Эверест'),
    const _CollItem('assets/mountain_2.png', 'Эльбрус'),
    const _CollItem('assets/mountain_3.png', 'Килиманджаро'),
    const _CollItem('assets/mountain_4.png', 'Чогори'),
    const _CollItem('assets/mountain_5.png', 'Фудзияма'),
    const _CollItem('assets/mountain_6.webp', 'Монблан', locked: true),
  ];

  return [
    const SliverToBoxAdapter(child: _SectionTitle('Бегом по Золотому Кольцу')),
    const SliverToBoxAdapter(child: SizedBox(height: 10)),
    _CollectionsSliverGrid(items: cities),

    const SliverToBoxAdapter(child: SizedBox(height: 10)),

    const SliverToBoxAdapter(child: _SectionTitle('Покорение вершин')),
    const SliverToBoxAdapter(child: SizedBox(height: 10)),
    _CollectionsSliverGrid(items: mountains),
  ];
}

// ───────────────── UI helpers ─────────────────

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
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}

class _CollItem {
  final String asset;
  final String title;
  final bool locked;
  const _CollItem(this.asset, this.title, {this.locked = false});
}

class _CollectionsSliverGrid extends StatelessWidget {
  final List<_CollItem> items;
  const _CollectionsSliverGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), // немного места снизу
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _CollectionTile(item: items[i]),
          childCount: items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.04,
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

class _CollectionTile extends StatelessWidget {
  final _CollItem item;
  const _CollectionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    // Изображение занимает всю ширину и 2/3 высоты карточки
    Widget image = ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppRadius.md),
        topRight: Radius.circular(AppRadius.md),
      ),
      child: Image.asset(item.asset, width: double.infinity, fit: BoxFit.cover),
    );

    // Для "locked" — обесцвечиваем картинку
    if (item.locked) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_kGreyscaleMatrix),
        child: image,
      );
    }

    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.getBorderColor(context), 
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadowSoft
                : AppColors.shadowSoft,
            offset: const Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Изображение занимает 2/3 высоты карточки
          Expanded(flex: 2, child: image),
          // Текст занимает 1/3 высоты карточки
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Center(
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return item.locked ? Opacity(opacity: 0.38, child: card) : card;
  }
}
