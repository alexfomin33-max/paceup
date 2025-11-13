import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../models/event.dart';
import '../../../../../providers/events/my_events_provider.dart';
import '../../../../../providers/services/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Вкладка «Мои события» — карточный список с зазором 2 px
class MyEventsContent extends ConsumerStatefulWidget {
  const MyEventsContent({super.key});

  @override
  ConsumerState<MyEventsContent> createState() => _MyEventsContentState();
}

class _MyEventsContentState extends ConsumerState<MyEventsContent> {
  // Текущий месяц (по умолчанию текущий месяц)
  late DateTime month;
  int? selectedDay; // выделенный день
  bool _monthInitialized = false; // флаг, что месяц уже инициализирован из событий

  @override
  void initState() {
    super.initState();
    month = DateTime.now();
    month = DateTime(month.year, month.month, 1);
  }

  /// Устанавливает месяц календаря на месяц ближайшего события
  void _updateMonthFromEvents(List<Event> events) {
    if (_monthInitialized || events.isEmpty) return;

    final now = DateTime.now();
    DateTime? nearestDate;

    // Ищем ближайшее событие (будущее или самое близкое к текущей дате)
    for (final event in events) {
      final eventDate = event.parsedDate;
      if (eventDate == null) continue;

      // Если это первое событие или оно ближе к текущей дате
      if (nearestDate == null) {
        nearestDate = eventDate;
      } else {
        // Предпочитаем будущие события
        final isFuture = eventDate.isAfter(now);
        final nearestIsFuture = nearestDate.isAfter(now);

        if (isFuture && !nearestIsFuture) {
          nearestDate = eventDate;
        } else if (isFuture == nearestIsFuture) {
          // Если оба в будущем или оба в прошлом - берем ближайшее
          final diff = (eventDate.difference(now)).abs();
          final nearestDiff = (nearestDate.difference(now)).abs();
          if (diff < nearestDiff) {
            nearestDate = eventDate;
          }
        }
      }
    }

    final nearest = nearestDate;
    if (nearest != null) {
      setState(() {
        month = DateTime(nearest.year, nearest.month, 1);
        _monthInitialized = true;
      });
    }
  }

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

  // ── Получение множества дней с событиями для текущего месяца
  Set<int> _getMarkedDays(List<Event> events) {
    final markedDays = <int>{};
    for (final event in events) {
      final eventDate = event.parsedDate;
      if (eventDate != null &&
          eventDate.year == month.year &&
          eventDate.month == month.month) {
        markedDays.add(eventDate.day);
      }
    }
    return markedDays;
  }

  @override
  Widget build(BuildContext context) {
    // Получаем текущего пользователя из AuthService
    final currentUserIdAsync = ref.watch(currentUserIdProvider);

    // Обрабатываем состояние загрузки userId
    return currentUserIdAsync.when(
      data: (userId) {
        if (userId == null) {
          // Пользователь не авторизован
          return const CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Необходима авторизация',
                      style: AppTextStyles.h14w4,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Загружаем события текущего пользователя через provider
        // Загрузка происходит автоматически при создании провайдера
        final eventsState = ref.watch(myEventsProvider(userId));

        // Обновляем месяц календаря на месяц ближайшего события
        if (eventsState.events.isNotEmpty && !eventsState.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateMonthFromEvents(eventsState.events);
          });
        }

        return RefreshIndicator.adaptive(
          onRefresh: () async {
            await ref.read(myEventsProvider(userId).notifier).refresh();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Пагинация месяцев (вынесена наверх)
              SliverToBoxAdapter(
                child: Padding(
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
                            style: AppTextStyles.h15w5,
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
                    hasDots: _getMarkedDays(eventsState.events),
                    onDayTap: (d) => setState(() => selectedDay = d),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Состояния загрузки и ошибок
              if (eventsState.isLoading && eventsState.events.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CupertinoActivityIndicator(),
                    ),
                  ),
                )
              else if (eventsState.error != null && eventsState.events.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ошибка: ${eventsState.error}',
                            style: AppTextStyles.h14w4,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          CupertinoButton(
                            onPressed: () {
                              ref
                                  .read(myEventsProvider(userId).notifier)
                                  .loadInitial();
                            },
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (eventsState.events.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'У вас пока нет событий',
                        style: AppTextStyles.h14w4,
                      ),
                    ),
                  ),
                )
              else
                // ── Карточный список с зазором 2 px (как в Закладках/Маршрутах)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  sliver: SliverList.separated(
                    itemCount: eventsState.events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, i) =>
                        _EventCard(event: eventsState.events[i]),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
      loading: () => const CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CupertinoActivityIndicator()),
            ),
          ),
        ],
      ),
      error: (err, stack) => CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Ошибка: $err',
                  style: AppTextStyles.h14w4,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        // стиль карточки такой же, как в других вкладках
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          const BoxShadow(
            color: AppColors.shadowSoft,
            offset: Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: _EventRow(event: event),
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
      minimumSize: const Size(28, 28),
      onPressed: onTap,
      child: Icon(icon, size: 18, color: AppColors.iconPrimary),
    );
  }
}

class _EventRow extends StatelessWidget {
  final Event event;
  const _EventRow({required this.event});

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
            child: event.logoUrl != null && event.logoUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: event.logoUrl!,
                    width: 80,
                    height: 55,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 80,
                      height: 55,
                      color: AppColors.skeletonBase,
                      alignment: Alignment.center,
                      child: const Icon(
                        CupertinoIcons.photo,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    placeholder: (_, __) => Container(
                      width: 80,
                      height: 55,
                      color: AppColors.skeletonBase,
                      alignment: Alignment.center,
                      child: const CupertinoActivityIndicator(),
                    ),
                  )
                : Container(
                    width: 80,
                    height: 55,
                    color: AppColors.skeletonBase,
                    alignment: Alignment.center,
                    child: const Icon(
                      CupertinoIcons.photo,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h14w6,
                ),
                const SizedBox(height: 6),
                Text(
                  '${event.dateFormatted}  ·  Участников: ${_fmt(event.participantsCount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h13w4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          const BoxShadow(
            color: AppColors.shadowSoft,
            offset: Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
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
                return Padding(
                  // Добавляем вертикальный padding для создания промежутка между рядами кружочков
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (c) {
                      final cell = r * 7 + c;
                      final d = cell - lead + 1;
                      if (d < 1 || d > daysInMonth) {
                        return const SizedBox(width: 36, height: 36);
                      }
                      final isSelected = selectedDay == d;
                      final marked = hasDots.contains(d);
                      return Padding(
                        // Добавляем горизонтальный padding для создания промежутка между кружочками
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: GestureDetector(
                          onTap: () => onDayTap(d),
                          behavior: HitTestBehavior.opaque,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Внешний контейнер для border (кружочек)
                              if (marked)
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.brandPrimary,
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              // Внутренний контейнер для фона и текста
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.brandPrimary.withValues(
                                          alpha: 0.4,
                                        )
                                      : null,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$d',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w400
                                        : FontWeight.w400,
                                    color: (c >= 5)
                                        ? AppColors.error
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
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

