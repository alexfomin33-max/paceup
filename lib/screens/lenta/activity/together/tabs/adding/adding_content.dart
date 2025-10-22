import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../theme/app_theme.dart';

class AddingContent extends StatelessWidget {
  const AddingContent({super.key});

  static const _candidates = <_Person>[
    _Person(
      'Борис Жарких',
      40,
      'Владимир',
      'assets/avatar_2.png',
      pending: true,
    ),
    _Person('Светлана Никитина', 35, 'Ростов', 'assets/avatar_3.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12), // ← только поле поиска
          child: _SearchField(),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity, // ← full width
          decoration: const BoxDecoration(
            color: AppColors.surface,
            // border: Border(
            //   top: BorderSide(color: AppColors.border, width: 0.5),
            //   bottom: BorderSide(color: AppColors.border, width: 0.5),
            // ),
          ),
          child: Column(
            children: List.generate(_candidates.length, (i) {
              final p = _candidates[i];
              return Column(
                children: [
                  _RowTile(
                    person: p,
                    trailing: p.pending
                        ? const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              CupertinoIcons.hourglass,
                              size: 22,
                              color: AppColors.textTertiary,
                            ),
                          )
                        : SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                CupertinoIcons.add_circled,
                                size: 22,
                                color: AppColors.brandPrimary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints:
                                  const BoxConstraints(), // не раздуваем макет
                              splashRadius: 18,
                            ),
                          ),
                  ),
                  // if (i != _candidates.length - 1)
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
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Поиск',
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 8, right: 4),
          child: Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 30),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
      ),
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
  final bool pending;
  const _Person(
    this.name,
    this.age,
    this.city,
    this.avatar, {
    this.pending = false,
  });
}
