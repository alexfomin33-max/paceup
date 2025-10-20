import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../theme/app_theme.dart';

/// Вкладка «Подписчики»
class SubscribersContent extends StatelessWidget {
  final String query;
  const SubscribersContent({super.key, required this.query});

  // followBack = я уже подписан в ответ (иконка красная X для «отписаться»),
  // иначе — синяя «плюс» (подписаться в ответ).
  static const _people = <_Follower>[
    _Follower('Алексей Лукашин', 35, 'Владимир', 'assets/avatar_1.png', true),
    _Follower('Татьяна Свиридова', 39, 'Владимир', 'assets/avatar_3.png', true),
    _Follower('Борис Жарких', 40, 'Владимир', 'assets/avatar_2.png', true),
    _Follower(
      'Александр Палаткин',
      38,
      'Воронеж',
      'assets/avatar_6.png',
      false,
    ),
    _Follower(
      'Екатерина Виноградова',
      30,
      'Санкт-Петербург',
      'assets/avatar_4.png',
      true,
    ),
    _Follower('Светлана Никитина', 35, 'Ростов', 'assets/avatar_8.png', false),
  ];

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final items = q.isEmpty
        ? _people
        : _people
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

        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final p = items[i];
                final trailing = p.followBack
                    ? IconButton(
                        onPressed: () {},
                        splashRadius: 24,
                        icon: const Icon(
                          CupertinoIcons.person_crop_circle_badge_xmark,
                          size: 26,
                          color: AppColors.error,
                        ),
                      )
                    : IconButton(
                        onPressed: () {},
                        splashRadius: 24,
                        icon: const Icon(
                          CupertinoIcons.person_crop_circle_badge_plus,
                          size: 26,
                          color: AppColors.brandPrimary,
                        ),
                      );

                return Column(
                  children: [
                    _RowTile(person: p, trailing: trailing),
                    if (i != items.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        color: AppColors.divider,
                      ),
                  ],
                );
              }),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  final _Follower person;
  final Widget trailing;
  const _RowTile({required this.person, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              person.avatar,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 44,
                height: 44,
                color: AppColors.skeletonBase,
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.person,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${person.age} лет, ${person.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _Follower {
  final String name;
  final int age;
  final String city;
  final String avatar;
  final bool followBack; // я подписан на него в ответ
  const _Follower(this.name, this.age, this.city, this.avatar, this.followBack);
}
