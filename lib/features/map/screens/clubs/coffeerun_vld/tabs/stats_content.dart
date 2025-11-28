import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';

class CoffeeRunVldStatsContent extends StatefulWidget {
  const CoffeeRunVldStatsContent({super.key});

  @override
  State<CoffeeRunVldStatsContent> createState() =>
      _CoffeeRunVldStatsContentState();
}

class _CoffeeRunVldStatsContentState extends State<CoffeeRunVldStatsContent> {
  int _seg = 0; // 0 неделя, 1 месяц, 2 год
  static const double _kmColW = 70; // подберите 88–110 по вкусу

  static const _week = <_StatRow>[
    _StatRow(1, 'Алексей Лукашин', 'assets/avatar_1.png', 67.04),
    _StatRow(2, 'Татьяна Свиридова', 'assets/avatar_3.png', 64.46),
    _StatRow(3, 'Борис Жарких', 'assets/avatar_2.png', 58.01),
    _StatRow(4, 'Юрий Селиванов', 'assets/avatar_5.png', 42.82),
    _StatRow(5, 'Екатерина Виноградова', 'assets/avatar_4.png', 36.56),
    _StatRow(6, 'Анастасия Бутузова', 'assets/avatar_9.png', 25.18),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _week; // демо одинаковые
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // сегмент
        Container(
          decoration: BoxDecoration(
            color: AppColors.disabled,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            children: List.generate(3, (i) {
              final labels = ['Эта неделя', 'Этот месяц', 'Этот год'];
              final selected = _seg == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _seg = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),

        // список
        Column(
          children: List.generate(items.length, (i) {
            final m = items[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
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
                          ),
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
                        child: Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: _kmColW,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${m.km.toStringAsFixed(2).replaceAll('.', ',')} км',
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w400,

                              // табличные цифры, чтобы разряды не «прыгали»
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.border,
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _StatRow {
  final int rank;
  final String name;
  final String avatar;
  final double km;
  const _StatRow(this.rank, this.name, this.avatar, this.km);
}
