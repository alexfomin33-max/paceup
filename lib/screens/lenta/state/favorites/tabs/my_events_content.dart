import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

/// Вкладка «Мои события» — карточный список с зазором 2 px
class MyEventsContent extends StatefulWidget {
  const MyEventsContent({super.key});

  @override
  State<MyEventsContent> createState() => _MyEventsContentState();
}

class _MyEventsContentState extends State<MyEventsContent> {
  // Текущий месяц (по умолчанию июнь 2025 — как в макете)
  DateTime month = DateTime(2025, 6, 1);
  int? selectedDay; // выделенный день
  static const marked = {10, 24}; // кружки-метки, как на скрине

  static const _items = <_FavEvent>[
    _FavEvent(
      title: 'Субботний коферан',
      dateText: '10 июня 2025',
      members: 33,
      asset: 'assets/my_event_1.png',
    ),
    _FavEvent(
      title: 'Трейл Изумрудные воды',
      dateText: '24 июня 2025',
      members: 475,
      asset: 'assets/my_event_2.png',
    ),
    _FavEvent(
      title: 'Забег Run With Love',
      dateText: '13 июля 2025',
      members: 118,
      asset: 'assets/my_event_3.png',
    ),
    _FavEvent(
      title: 'Полумарафон «Моя Столица»',
      dateText: '5 октября 2025',
      members: 4932,
      asset: 'assets/my_event_4.png',
    ),
  ];

  void _prevMonth() {
    setState(() {
      month = DateTime(month.year, month.month - 1, 1);
      selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      month = DateTime(month.year, month.month + 1, 1);
      selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Пагинация месяцев (вынесена наверх)
        SliverToBoxAdapter(
          child: Padding(
            // оставляю твоё значение; можно подогнать позже
            padding: const EdgeInsets.symmetric(horizontal: 100),
            child: Row(
              children: [
                _MonthButton(
                  icon: CupertinoIcons.chevron_left,
                  onTap: _prevMonth,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _monthTitle(month),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _MonthButton(
                  icon: CupertinoIcons.chevron_right,
                  onTap: _nextMonth,
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ── Сам календарь (без заголовка месяца)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _InlineCalendar(
              month: month,
              selectedDay: selectedDay,
              hasDots: marked,
              onDayTap: (d) => setState(() => selectedDay = d),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ── Карточный список с зазором 2 px (как в Закладках/Маршрутах)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          sliver: SliverList.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (context, i) => _EventCard(e: _items[i]),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final _FavEvent e;
  const _EventCard({required this.e});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,

        // стиль карточки такой же, как в других вкладках
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: _EventRow(e: e),
    );
  }
}

class _MonthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MonthButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.all(6),
      minSize: 28,
      onPressed: onTap,
      child: Icon(icon, size: 18, color: AppColors.iconPrimary),
    );
  }
}

class _EventRow extends StatelessWidget {
  final _FavEvent e;
  const _EventRow({required this.e});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // внутренние отступы карточки
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: Image.asset(
              e.asset,
              width: 90,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 90,
                height: 60,
                color: AppColors.skeletonBase,
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.photo,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${e.dateText}  ·  Участников: ${_fmt(e.members)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavEvent {
  final String title;
  final String dateText;
  final int members;
  final String asset;
  const _FavEvent({
    required this.title,
    required this.dateText,
    required this.members,
    required this.asset,
  });
}

class _InlineCalendar extends StatelessWidget {
  final DateTime month;
  final int? selectedDay;
  final Set<int> hasDots;
  final ValueChanged<int> onDayTap;

  const _InlineCalendar({
    required this.month,
    required this.selectedDay,
    required this.hasDots,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = (first.weekday + 6) % 7; // Mon=0..Sun=6
    final totalCells = lead + daysInMonth;
    final rows = (totalCells / 7.0).ceil();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          children: [
            // Заголовки дней недели
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _D('Пн'),
                _D('Вт'),
                _D('Ср'),
                _D('Чт'),
                _D('Пт'),
                _D('Сб', weekend: true),
                _D('Вс', weekend: true),
              ],
            ),
            const SizedBox(height: 6),
            // Сетка дней
            Column(
              children: List.generate(rows, (r) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (c) {
                    final cell = r * 7 + c;
                    final d = cell - lead + 1;
                    if (d < 1 || d > daysInMonth) {
                      return const SizedBox(width: 36, height: 36);
                    }
                    final isSelected = selectedDay == d;
                    final marked = hasDots.contains(d);
                    return GestureDetector(
                      onTap: () => onDayTap(d),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brandPrimary.withValues(alpha: 0.11)
                              : null,
                          shape: BoxShape.circle,
                          border: marked
                              ? Border.all(
                                  color: AppColors.brandPrimary,
                                  width: 1.4,
                                )
                              : null,
                        ),
                        child: Text(
                          '$d',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: (c >= 5)
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _D extends StatelessWidget {
  final String t;
  final bool weekend;
  const _D(this.t, {this.weekend = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Center(
        child: Text(
          t,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: weekend ? AppColors.error : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    b.write(s[i]);
    if (rev > 1 && rev % 3 == 1) b.write('\u202F');
  }
  return b.toString();
}

String _monthTitle(DateTime m) {
  const months = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];
  final s = '${months[m.month - 1]} ${m.year}';
  return '${s[0].toUpperCase()}${s.substring(1)}';
}
