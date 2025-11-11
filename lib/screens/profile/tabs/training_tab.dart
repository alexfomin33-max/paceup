import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class TrainingTab extends StatefulWidget {
  const TrainingTab({super.key});

  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab>
    with AutomaticKeepAliveClientMixin {
  // Текущий месяц
  DateTime _month = DateTime(2025, 6, 1);

  // Мультиселект видов спорта: 0 бег, 1 вело, 2 плавание
  final Set<int> _sports = {0, 1, 2};

  @override
  bool get wantKeepAlive => true;

  // Пузырьки на календаре (пример для Июня 2025)
  final Map<int, String> _juneBubbles = const {
    2: '8,4',
    4: '24,2',
    6: '5,1',
    7: '8,5',
    10: '7,2',
    11: '16,1',
    12: '5,8',
    13: '6,0',
    15: '10,7',
    18: '21,2',
    21: '11,3',
    24: '8,5',
    25: '16,0',
    27: '9,7',
  };

  // Демо-лента тренировок
  late final List<_Workout> _all = [
    _Workout(
      DateTime(2025, 6, 18, 20, 52),
      0,
      '21,24 км',
      '1:48:52',
      '4:15 /км',
    ),
    _Workout(DateTime(2025, 6, 17, 9, 32), 2, '2,85 км', '35:28', '1,52 м/с'),
    _Workout(
      DateTime(2025, 6, 16, 10, 35),
      1,
      '58,42 км',
      '2:35:11',
      '35,7 км/ч',
    ),
    _Workout(DateTime(2025, 6, 15, 8, 13), 0, '10,70 км', '58:52', '5:48 /км'),
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final items = _all
        .where((w) => _sports.contains(w.kind))
        .toList(growable: false);
    final bubbles = (_month.year == 2025 && _month.month == 6)
        ? _juneBubbles
        : const <int, String>{};

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 14)),

        // ── Панель: «Июнь 2025», ◄ ►, иконки справа
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _MonthToolbar(
              month: _month,
              sports: _sports,
              onPrev: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1, 1),
              ),
              onNext: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1, 1),
              ),
              onToggleSport: (i) => setState(() {
                _sports.contains(i) ? _sports.remove(i) : _sports.add(i);
              }),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ── Карточка календаря
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _CalendarCard(month: _month, bubbles: bubbles),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        // ── Таблица тренировок (единый контейнер на всю ширину, без скруглений)
        SliverToBoxAdapter(child: _WorkoutTable(items: items)),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

/// ===================
/// Верхняя панель
/// ===================

class _MonthToolbar extends StatelessWidget {
  final DateTime month;
  final Set<int> sports; // выбранные виды спорта
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onToggleSport;

  const _MonthToolbar({
    required this.month,
    required this.sports,
    required this.onPrev,
    required this.onNext,
    required this.onToggleSport,
  });

  @override
  Widget build(BuildContext context) {
    final title = _monthTitle(month);
    return Row(
      children: [
        _NavIcon(CupertinoIcons.left_chevron, onTap: onPrev),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        _NavIcon(
          CupertinoIcons.right_chevron,
          onTap: onNext,
        ), // ► рядом с заголовком
        const Spacer(),
        _SportIcon(
          selected: sports.contains(0),
          icon: Icons.directions_run,
          onTap: () => onToggleSport(0),
        ),
        const SizedBox(width: 8),
        _SportIcon(
          selected: sports.contains(1),
          icon: Icons.directions_bike,
          onTap: () => onToggleSport(1),
        ),
        const SizedBox(width: 8),
        _SportIcon(
          selected: sports.contains(2),
          icon: Icons.pool,
          onTap: () => onToggleSport(2),
        ),
      ],
    );
  }

  String _monthTitle(DateTime m) {
    const mnames = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return '${mnames[m.month - 1]} ${m.year}';
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavIcon(this.icon, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: AppColors.iconPrimary),
      ),
    );
  }
}

class _SportIcon extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  const _SportIcon({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected ? AppColors.surface : AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// ===================
/// Календарь
/// ===================

class _CalendarCard extends StatelessWidget {
  final DateTime month;
  final Map<int, String> bubbles;

  const _CalendarCard({required this.month, required this.bubbles});

  // 🔽 две высоты вместо одной
  static const double _cellHeightTall = 52; // есть облачка
  static const double _cellHeightCompact = 34; // нет облачков
  static const double _dayTop = 6;
  static const double _bubbleTop = 24;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.7),
        boxShadow: [
          const BoxShadow(
            color: AppColors.shadowSoft,
            offset: Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        children: [
          const Row(
            children: [
              _Dow('Пн'),
              _Dow('Вт'),
              _Dow('Ср'),
              _Dow('Чт'),
              _Dow('Пт'),
              _Dow('Сб', weekend: true),
              _Dow('Вс', weekend: true),
            ],
          ),
          const SizedBox(height: 6),
          _MonthGrid(
            month: month,
            bubbles: bubbles,
            tallHeight: _cellHeightTall,
            compactHeight: _cellHeightCompact,
            dayTop: _dayTop,
            bubbleTop: _bubbleTop,
          ),
        ],
      ),
    );
  }
}

class _Dow extends StatelessWidget {
  final String t;
  final bool weekend;
  const _Dow(this.t, {this.weekend = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          t,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: weekend ? AppColors.error : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<int, String> bubbles;
  final double tallHeight;
  final double compactHeight;
  final double dayTop;
  final double bubbleTop;

  const _MonthGrid({
    required this.month,
    required this.bubbles,
    required this.tallHeight,
    required this.compactHeight,
    required this.dayTop,
    required this.bubbleTop,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);

    // 1=Пн ... 7=Вс → Пн=0
    final startOffset = first.weekday - 1;
    final totalCells = startOffset + last.day;
    final rows = (totalCells / 7.0).ceil();

    return Column(
      children: List.generate(rows, (r) {
        // Проверяем, есть ли хотя бы одно облачко в строке r
        bool hasAnyBubble = false;
        for (int c = 0; c < 7; c++) {
          final idx = r * 7 + c;
          final dayNum = idx - startOffset + 1;
          if (dayNum >= 1 &&
              dayNum <= last.day &&
              bubbles.containsKey(dayNum)) {
            hasAnyBubble = true;
            break;
          }
        }
        final rowHeight = hasAnyBubble ? tallHeight : compactHeight;

        return Row(
          children: List.generate(7, (c) {
            final idx = r * 7 + c;
            final dayNum = idx - startOffset + 1;

            if (dayNum < 1 || dayNum > last.day) {
              return Expanded(child: SizedBox(height: rowHeight));
            }

            final isWeekend = (c == 5) || (c == 6);
            final bubble = bubbles[dayNum];

            return Expanded(
              child: SizedBox(
                height: rowHeight,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // цифра дня — все по одной горизонтали
                    Positioned(
                      top: dayTop,
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isWeekend
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (bubble != null)
                      Positioned(
                        top: bubbleTop,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Text(
                            bubble,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

/// ===================
/// Таблица тренировок
/// ===================

class _WorkoutTable extends StatelessWidget {
  final List<_Workout> items;
  const _WorkoutTable({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            offset: Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final w = items[i];
          final last = i == items.length - 1;
          return Column(
            children: [
              _WorkoutRow(item: w),
              if (!last)
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.divider,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  final _Workout item;
  const _WorkoutRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // слева/сверху/снизу уменьшены, справа прежний 12
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      child: Row(
        children: [
          // Мини-карта 70x46
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: const Image(
              image: AssetImage('assets/training_map.png'),
              width: 70,
              height: 46,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),

          // Текстовая часть
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Дата/время (иконку слева убрали)
                Row(
                  children: [
                    Text(
                      _fmtDate(item.when),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: AppColors.iconSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Три метрики — строго таблично, с вертикальными разделителями
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: _metric(
                            item.kind == 0
                                ? Icons.directions_run
                                : (item.kind == 1
                                      ? Icons.pedal_bike
                                      : Icons.pool),
                            item.distText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Center(
                          child: _metric(Icons.access_time, item.durText),
                        ),
                      ),

                      Expanded(
                        child: Center(
                          child: _metric(Icons.speed, item.paceText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.brandPrimary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
      ],
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$dd ${months[d.month - 1]}, $hh:$mm';
  }
}

/// Модель
class _Workout {
  final DateTime when;
  final int kind; // 0 бег, 1 вело, 2 плавание
  final String distText;
  final String durText;
  final String paceText;
  _Workout(this.when, this.kind, this.distText, this.durText, this.paceText);
}
