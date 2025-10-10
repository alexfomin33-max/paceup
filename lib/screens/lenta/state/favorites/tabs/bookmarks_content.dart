import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

/// Вкладка «Закладки» — карточный список с промежутками (как в Маршрутах)
class BookmarksContent extends StatelessWidget {
  const BookmarksContent({super.key});

  static const _items = <_Bookmark>[
    _Bookmark(
      'assets/bookmark_1.png',
      '"Ночь. Стрелка. Ярославль"',
      '29 июля 2025',
      783,
    ),
    _Bookmark(
      'assets/bookmark_2.png',
      'Минский полумарафон 2025',
      '7 сентября 2025',
      1264,
    ),
    _Bookmark(
      'assets/bookmark_3.png',
      'Марафон «Алые паруса»',
      '22 июня 2025',
      13590,
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
                const SizedBox(height: 2), // такой же зазор, как в Маршрутах
            itemBuilder: (context, i) => _BookmarkCard(e: _items[i]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final _Bookmark e;
  const _BookmarkCard({required this.e});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(0),
        border: Border.all(color: const Color(0xFFEAEAEA), width: 0.5),
      ),
      child: _BookmarkRow(e: e),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  final _Bookmark e;
  const _BookmarkRow({required this.e});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          // Превью
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
                  CupertinoIcons.photo,
                  size: 20,
                  color: AppColors.greytext,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Правый столбец
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Первая строка: Название + вертикальные 3 точки
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
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 28,
                      onPressed: () {},
                      child: const Icon(
                        CupertinoIcons.ellipsis_vertical,
                        size: 18,
                        color: AppColors.greytext,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Вторая строка: дата + участники
                Text(
                  '${e.dateText}  ·  Участников: ${_fmt(e.members)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bookmark {
  final String asset;
  final String title;
  final String dateText;
  final int members;
  const _Bookmark(this.asset, this.title, this.dateText, this.members);
}

String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    b.write(s[i]);
    if (rev > 1 && rev % 3 == 1) b.write('\u202F'); // узкий неразрывный пробел
  }
  return b.toString();
}
