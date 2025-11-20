import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../theme/app_theme.dart';

class MemberContent extends StatelessWidget {
  const MemberContent({super.key});

  static const _members = <_Person>[
    _Person('Алексей Лукашин', 35, 'Владимир', 'assets/avatar_1.png'),
    _Person('Александр Палаткин', 38, 'Воронеж', 'assets/avatar_2.png'),
    _Person(
      'Екатерина Виноградова',
      30,
      'Санкт-Петербург',
      'assets/avatar_4.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Табличный блок как в subscriptions_content.dart
        Container(
          width: double.infinity, // ← добавили
          decoration: const BoxDecoration(
            color: AppColors.surface,
            // border: Border(
            //   top: BorderSide(color: AppColors.border, width: 0.5),
            //   bottom: BorderSide(color: AppColors.border, width: 0.5),
            // ),
          ),
          child: Column(
            children: List.generate(_members.length, (i) {
              final p = _members[i];
              return Column(
                children: [
                  _RowTile(
                    person: p,
                    trailing: const SizedBox.shrink(), // без правой кнопки
                  ),
                  // if (i != _members.length - 1)
                  //   const Divider(
                  //     height: 1,
                  //     thickness: 0.5,
                  //     color: AppColors.divider,
                  //   ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 20),

        // Кнопка «Покинуть группу»
        SizedBox(
          height: 44,
          width: 200,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: BorderSide.none,
              foregroundColor: AppColors.error,
              backgroundColor: AppColors.backgroundRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
            ),
            child: const Text(
              'Покинуть группу',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  final _Person person;
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

class _Person {
  final String name;
  final int age;
  final String city;
  final String avatar;
  const _Person(this.name, this.age, this.city, this.avatar);
}
