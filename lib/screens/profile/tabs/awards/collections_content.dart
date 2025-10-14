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
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.04,
        ),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final _CollItem item;
  const _CollectionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.7),
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Column(
        children: [
          ClipOval(
            child: Image.asset(
              item.asset,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
          ),
        ],
      ),
    );

    return item.locked ? Opacity(opacity: 0.38, child: card) : card;
  }
}
