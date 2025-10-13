import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Контент вкладки «Клубы»
/// Табличный список «в одну коробку» (как на карте/в маршрутных списках).
class SearchClubsContent extends StatelessWidget {
  final String query;
  const SearchClubsContent({super.key, required this.query});

  static const _clubs = <_Club>[
    _Club('Бег вреден', 'Владимир', 267, 'assets/find_club_1.png'),
    _Club('I Love Circle', 'Владимир', 120, 'assets/find_club_2.png'),
    _Club('I Love Ski', 'Москва', 1384, 'assets/find_club_3.png'),
    _Club('I Love Running', 'Москва', 3439, 'assets/find_club_4.png'),
    _Club('Плывущие по реке', 'Нижний Новгород', 354, 'assets/find_club_5.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final items = q.isEmpty
        ? _clubs
        : _clubs
              .where(
                (e) =>
                    e.title.toLowerCase().contains(q) ||
                    e.city.toLowerCase().contains(q),
              )
              .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: _SectionTitle('Рекомендованные клубы')),

        // ───── Табличный блок (как в map_screen списках)
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
                bottom: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
              ),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final c = items[i];
                return Column(
                  children: [
                    _ClubRow(c: c),
                    if (i != items.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Color(0xFFEAEAEA),
                      ),
                  ],
                );
              }),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ───── «Создать клуб»
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SizedBox(
                width: 220, // как у «Пригласить»
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Создать клуб', style: AppTextStyles.name),
                ),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _ClubRow extends StatelessWidget {
  final _Club c;
  const _ClubRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Превью
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              c.asset,
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
          const SizedBox(width: 12),

          // Название и детали
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${c.city}  ·  Участников: ${_fmt(c.members)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _Club {
  final String title;
  final String city;
  final int members;
  final String asset;
  const _Club(this.title, this.city, this.members, this.asset);
}

String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    b.write(s[i]);
    if (rev > 1 && rev % 3 == 1) b.write('\u202F'); // узкий неразрывный
  }
  return b.toString();
}
