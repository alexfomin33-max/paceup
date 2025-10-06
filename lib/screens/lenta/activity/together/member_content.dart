import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class MemberContent extends StatelessWidget {
  const MemberContent({super.key});

  static const _members = <_Person>[
    _Person('Алексей Лукашин', 35, 'Владимир', 'assets/Avatar_1.png'),
    _Person('Дмитрий Фадеев', 38, 'Воронеж', 'assets/Avatar_2.png'),
    _Person(
      'Екатерина Виноградова',
      30,
      'Санкт-Петербург',
      'assets/Avatar_4.png',
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
            color: Colors.white,
            // border: Border(
            //   top: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
            //   bottom: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
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
                  //     color: Color(0xFFEAEAEA),
                  //   ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 16),

        // Кнопка «Покинуть группу»
        SizedBox(
          height: 44,
          width: 250,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.red, width: 1),
              foregroundColor: AppColors.red,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              person.avatar,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
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
                    color: AppColors.text,
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
                    color: AppColors.greytext,
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
