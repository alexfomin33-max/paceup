import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

class MembersContent extends StatelessWidget {
  const MembersContent({super.key});

  static const demo = <_Member>[
    _Member(
      'Татьяна Свиридова',
      'Организатор',
      'assets/avatar_3.png',
      roleIcon: CupertinoIcons.person_crop_circle_fill_badge_checkmark,
    ),
    _Member(
      'Борис Жарких',
      null,
      'assets/avatar_2.png',
      roleIcon: CupertinoIcons.person_crop_circle_fill_badge_checkmark,
    ),
    _Member(
      'Юрий Селиванов',
      null,
      'assets/avatar_5.png',
      roleIcon: CupertinoIcons.person_crop_circle_fill_badge_checkmark,
    ),
    _Member('Алексей Лукашин', null, 'assets/avatar_1.png'),
    _Member('Екатерина Виноградова', null, 'assets/avatar_4.png'),
    _Member('Игорь Балеев', null, 'assets/avatar_10.png'),
  ];
  static int get demoCount => demo.length;

  @override
  Widget build(BuildContext context) {
    // без собственного контейнера — контент кладётся внутрь общего блока
    return Column(
      children: List.generate(demo.length, (i) {
        final m = demo[i];
        return Column(
          children: [
            _MemberRow(member: m),
            if (i != demo.length - 1)
              const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          ],
        );
      }),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final _Member member;
  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              member.avatar,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),

          // имя + роль
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (member.role != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.role!,
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
            onPressed: (member.roleIcon != null) ? null : () {},
            splashRadius: 22,
            icon: Icon(
              member.roleIcon ?? CupertinoIcons.person_crop_circle_badge_plus,
              size: 24,
            ),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
              disabledForegroundColor: AppColors.disabledText,
            ),
          ),
        ],
      ),
    );
  }
}

class _Member {
  final String name;
  final String? role;
  final String avatar;
  final IconData? roleIcon; // если задан — показываем "галочку"
  const _Member(this.name, this.role, this.avatar, {this.roleIcon});
}
