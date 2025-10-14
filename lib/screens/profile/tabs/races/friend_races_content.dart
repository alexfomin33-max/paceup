import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// «Друзей» — заголовок/дата снаружи + таблица со строками друзей и вертикальными разделителями.
List<Widget> buildFriendRacesSlivers() {
  final groups = <_RaceGroup>[
    _RaceGroup('СберПрайм Казанский марафон 2025', DateTime(2025, 5, 3), const [
      _FriendResult(
        'Алексей Лукашин',
        'assets/avatar_1.png',
        42.2,
        '3:38:37',
        '4:15 /км',
      ),
      _FriendResult(
        'Татьяна Свиридова',
        'assets/avatar_3.png',
        10.0,
        '43:50',
        '4:48 /км',
      ),
    ]),
    _RaceGroup('Московский полумарафон 2025', DateTime(2025, 4, 27), const [
      _FriendResult(
        'Борис Жарких',
        'assets/avatar_2.png',
        21.1,
        '1:36:42',
        '4:11 /км',
      ),
      _FriendResult(
        'Александр Палаткин',
        'assets/avatar_6.png',
        21.1,
        '1:44:51',
        '4:58 /км',
      ),
      _FriendResult(
        'Светлана Алешина',
        'assets/avatar_7.png',
        21.1,
        '2:03:14',
        '5:52 /км',
      ),
    ]),
    _RaceGroup('Полумарафон "Красная нить"', DateTime(2024, 7, 5), const [
      _FriendResult(
        'Юрий Селиванов',
        'assets/avatar_5.png',
        10.0,
        '42:38',
        '4:24 /км',
      ),
    ]),
  ];

  return [
    SliverList.builder(
      itemCount: groups.length,
      itemBuilder: (context, i) => _RaceFriendsBlock(group: groups[i]),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 12)),
  ];
}

// ===== модели =====
class _RaceGroup {
  final String title;
  final DateTime date;
  final List<_FriendResult> results;
  const _RaceGroup(this.title, this.date, this.results);
}

class _FriendResult {
  final String name;
  final String avatarAsset;
  final double km;
  final String time;
  final String pace;
  const _FriendResult(
    this.name,
    this.avatarAsset,
    this.km,
    this.time,
    this.pace,
  );
}

// ===== UI =====
class _RaceFriendsBlock extends StatelessWidget {
  final _RaceGroup group;
  const _RaceFriendsBlock({required this.group});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Заголовок и дата
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.name,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmt(group.date),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF6B6B6B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Таблица: верх/низ границы, внутри строки с вертикальными разделителями
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Column(
            children: List.generate(group.results.length, (i) {
              final r = group.results[i];
              return Column(
                children: [
                  // IntrinsicHeight, чтобы VerticalDivider растягивался по высоте строки
                  IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Ячейка 1: аватар + имя (шире)
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                ClipOval(
                                  child: Image.asset(
                                    r.avatarAsset,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    r.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.normaltext,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // │ разделитель
                          const FractionallySizedBox(
                            heightFactor: 0.5, // половина высоты строки
                            child: VerticalDivider(
                              width: 1,
                              thickness: 0.5,
                              color: AppColors.divider,
                            ),
                          ),

                          // Ячейка 2: км
                          Expanded(
                            child: Center(
                              child: Text(
                                '${r.km.toStringAsFixed(1)} км',
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: AppTextStyles.tablestat,
                              ),
                            ),
                          ),

                          const FractionallySizedBox(
                            heightFactor: 0.5, // половина высоты строки
                            child: VerticalDivider(
                              width: 1,
                              thickness: 0.5,
                              color: AppColors.divider,
                            ),
                          ),

                          // Ячейка 3: время
                          Expanded(
                            child: Center(
                              child: Text(
                                r.time,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: AppTextStyles.tablestat,
                              ),
                            ),
                          ),

                          const FractionallySizedBox(
                            heightFactor: 0.5, // половина высоты строки
                            child: VerticalDivider(
                              width: 1,
                              thickness: 0.5,
                              color: AppColors.divider,
                            ),
                          ),

                          // Ячейка 4: темп
                          Expanded(
                            child: Center(
                              child: Text(
                                r.pace,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: AppTextStyles.tablestat,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Горизонтальный разделитель между строками
                  if (i != group.results.length - 1)
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

        // увеличенный зазор до следующего заголовка
        const SizedBox(height: 20),
      ],
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
