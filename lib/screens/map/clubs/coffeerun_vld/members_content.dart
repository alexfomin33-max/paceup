import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:paceup/theme/app_theme.dart';

class CoffeeRunVldMembersContent extends StatelessWidget {
  const CoffeeRunVldMembersContent({super.key});

  static const _members = <_Member>[
    _Member(1, 'Алексей Лукашин', 'Владелец', 'assets/Avatar_1.png'),
    _Member(2, 'Татьяна Свиридова', 'Админ', 'assets/Avatar_3.png'),
    _Member(3, 'Игорь Зелёный', null, 'assets/Avatar_2.png'),
    _Member(4, 'Анатолий Курагин', null, 'assets/Avatar_5.png'),
    _Member(5, 'Екатерина Виноградова', null, 'assets/Avatar_4.png'),
    _Member(6, 'Игорь Балеев', null, 'assets/Avatar_10.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_members.length, (i) {
        final m = _members[i];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      m.rank.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      m.avatar,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                          ),
                        ),
                        if (m.role != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            m.role!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.greytext,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    splashRadius: 22,
                    icon: Icon(
                      m.role != null
                          ? CupertinoIcons
                                .person_crop_circle_fill_badge_checkmark
                          : CupertinoIcons.person_crop_circle_badge_plus,
                      size: 24,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (i != _members.length - 1)
              const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          ],
        );
      }),
    );
  }
}

class _Member {
  final int rank;
  final String name;
  final String? role;
  final String avatar;
  const _Member(this.rank, this.name, this.role, this.avatar);
}
