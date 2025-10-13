import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Контент вкладки «Друзья»
/// Переключатели уже в родительском экране. Здесь — секция и «табличный» блок.
class SearchFriendsContent extends StatelessWidget {
  final String query;
  const SearchFriendsContent({super.key, required this.query});

  static const _friends = <_Friend>[
    _Friend('Алексей Лукашин', 35, 'Владимир', 'assets/avatar_1.png'),
    _Friend('Татьяна Свиридова', 39, 'Владимир', 'assets/avatar_3.png'),
    _Friend('Борис Жарких', 40, 'Владимир', 'assets/avatar_2.png'),
    _Friend('Юрий Селиванов', 37, 'Москва', 'assets/avatar_5.png'),
    _Friend(
      'Екатерина Виноградова',
      30,
      'Санкт-Петербург',
      'assets/avatar_4.png',
    ),
    _Friend('Анастасия Бутузова', 35, 'Ярославль', 'assets/avatar_9.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final items = q.isEmpty
        ? _friends
        : _friends
              .where(
                (e) =>
                    e.name.toLowerCase().contains(q) ||
                    e.city.toLowerCase().contains(q),
              )
              .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(
          child: _SectionTitle('Рекомендованные друзья'),
        ),

        // ───── Табличный блок как в 200k_run_screen: белый фон, тонкие линии сверху/снизу и разделители между строками
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
                bottom: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
              ),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final f = items[i];
                return Column(
                  children: [
                    _FriendRow(friend: f),
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

        // ───── Подпись перед кнопкой
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'Пригласите друзей, которые еще не пользуются',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.greytext,
                ),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ───── Широкая кнопка «Пригласить»
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SizedBox(
                width: 220, // одинаковая ширина с кнопкой «Создать клуб»
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.surface,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Пригласить', style: AppTextStyles.name),
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

class _FriendRow extends StatelessWidget {
  final _Friend friend;
  const _FriendRow({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // Аватар
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              friend.avatar,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 44,
                height: 44,
                color: Colors.black.withValues(alpha: 0.06),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.person,
                  size: 20,
                  color: AppColors.greytext,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Имя + возраст/город
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.numberstat,
                ),
                const SizedBox(height: 2),
                Text(
                  '${friend.age} лет, ${friend.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.date,
                ),
              ],
            ),
          ),

          // Кнопка «добавить»
          IconButton(
            onPressed: () {},
            splashRadius: 24,
            icon: const Icon(
              CupertinoIcons.person_crop_circle_badge_plus,
              size: 26, // можно 28, если хочется ещё крупнее
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Friend {
  final String name;
  final int age;
  final String city;
  final String avatar;
  const _Friend(this.name, this.age, this.city, this.avatar);
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
