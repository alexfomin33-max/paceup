import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

class CoffeeRunVldMembersContent extends StatelessWidget {
  const CoffeeRunVldMembersContent({super.key});

  static const _members = <_Member>[
    _Member(1, 'Алексей Лукашин', 'Владелец', 'assets/avatar_1.png'),
    _Member(2, 'Татьяна Свиридова', 'Админ', 'assets/avatar_3.png'),
    _Member(3, 'Борис Жарких', null, 'assets/avatar_2.png'),
    _Member(4, 'Юрий Селиванов', null, 'assets/avatar_5.png'),
    _Member(5, 'Екатерина Виноградова', null, 'assets/avatar_4.png'),
    _Member(6, 'Игорь Балеев', null, 'assets/avatar_10.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_members.length, (i) {
        final m = _members[i];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      m.rank.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ClipOval(
                    child: Image.asset(
                      m.avatar,
                      width: 36,
                      height: 36,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (m.role != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            m.role!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary,
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
                      color: AppColors.brandPrimary,
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
