import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

class CoffeeRunVldGloryContent extends StatelessWidget {
  const CoffeeRunVldGloryContent({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = <_RaceGroup>[
      _RaceGroup(
        'СберПрайм Казанский марафон 2025',
        DateTime(2025, 5, 3),
        const [
          _RaceResult(
            'Алексей Лукашин',
            'assets/Avatar_1.png',
            42.2,
            '3:38:37',
            '4:15 /км',
          ),
          _RaceResult(
            'Татьяна Свиридова',
            'assets/Avatar_3.png',
            10.0,
            '43:50',
            '4:48 /км',
          ),
        ],
      ),
      _RaceGroup('Московский полумарафон 2025', DateTime(2025, 4, 27), const [
        _RaceResult(
          'Игорь Зелёный',
          'assets/Avatar_2.png',
          21.1,
          '1:36:42',
          '4:11 /км',
        ),
        _RaceResult(
          'Дмитрий Фадеев',
          'assets/Avatar_6.png',
          21.1,
          '1:44:51',
          '4:58 /км',
        ),
        _RaceResult(
          'Полина Холина',
          'assets/Avatar_7.png',
          21.1,
          '2:03:14',
          '5:52 /км',
        ),
      ]),
    ];

    return Column(
      children: List.generate(groups.length, (i) {
        return Column(
          children: [
            _RaceHeader(group: groups[i]),
            const SizedBox(height: 8),
            _RaceTable(group: groups[i]),
            const SizedBox(height: 16),
          ],
        );
      }),
    );
  }
}

// ===== модели =====
class _RaceGroup {
  final String title;
  final DateTime date;
  final List<_RaceResult> results;
  const _RaceGroup(this.title, this.date, this.results);
}

class _RaceResult {
  final String name;
  final String avatarAsset;
  final double km;
  final String time;
  final String pace;
  const _RaceResult(this.name, this.avatarAsset, this.km, this.time, this.pace);
}

// ===== UI =====
class _RaceHeader extends StatelessWidget {
  final _RaceGroup group;
  const _RaceHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmt(group.date),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.greytext,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _RaceTable extends StatelessWidget {
  final _RaceGroup group;
  const _RaceTable({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
          bottom: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
        ),
      ),
      child: Column(
        children: List.generate(group.results.length, (i) {
          final r = group.results[i];
          return Column(
            children: [
              IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // │ разделитель
                      const FractionallySizedBox(
                        heightFactor: 0.5,
                        child: VerticalDivider(
                          width: 1,
                          thickness: 0.5,
                          color: Color(0xFFEAEAEA),
                        ),
                      ),

                      // км (по центру ячейки, как в friend_races)
                      Expanded(
                        child: Center(
                          child: Text(
                            '${r.km.toStringAsFixed(1)} км',
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ),

                      const FractionallySizedBox(
                        heightFactor: 0.5,
                        child: VerticalDivider(
                          width: 1,
                          thickness: 0.5,
                          color: Color(0xFFEAEAEA),
                        ),
                      ),

                      // время
                      Expanded(
                        child: Center(
                          child: Text(
                            r.time,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ),

                      const FractionallySizedBox(
                        heightFactor: 0.5,
                        child: VerticalDivider(
                          width: 1,
                          thickness: 0.5,
                          color: Color(0xFFEAEAEA),
                        ),
                      ),

                      // темп
                      Expanded(
                        child: Center(
                          child: Text(
                            r.pace,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (i != group.results.length - 1)
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color(0xFFEAEAEA),
                ),
            ],
          );
        }),
      ),
    );
  }
}
