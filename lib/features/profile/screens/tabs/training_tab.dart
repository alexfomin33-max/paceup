import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../providers/training/training_provider.dart';
import '../../../../../core/widgets/route_card.dart';
import '../../../lenta/screens/activity/description_screen.dart';
import '../../../../domain/models/activity_lenta.dart' as al;
import '../../../../../providers/services/auth_provider.dart';
import '../../../../../core/widgets/transparent_route.dart';

class TrainingTab extends ConsumerStatefulWidget {
  const TrainingTab({super.key});

  @override
  ConsumerState<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends ConsumerState<TrainingTab>
    with AutomaticKeepAliveClientMixin {
  // Текущий месяц
  late DateTime _month;

  // Мультиселект видов спорта: 0 бег, 1 вело, 2 плавание
  final Set<int> _sports = {0, 1, 2};

  // Флаг для инициализации месяца только один раз при первой загрузке
  bool _monthInitialized = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем месяц текущей датой (будет обновлён из API)
    _month = DateTime.now();
    _month = DateTime(_month.year, _month.month, 1);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Получаем данные из провайдера
    final trainingDataAsync = ref.watch(trainingActivitiesProvider(_sports));

    return trainingDataAsync.when(
      data: (data) {
        // Если получили месяц последней тренировки, устанавливаем его только при первой загрузке
        if (data.lastWorkoutMonth != null && mounted && !_monthInitialized) {
          try {
            final parts = data.lastWorkoutMonth!.split('-');
            if (parts.length == 2) {
              final year = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final newMonth = DateTime(year, month, 1);
              // Обновляем месяц только при первой загрузке
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _month = newMonth;
                    _monthInitialized = true;
                  });
                }
              });
            }
          } catch (e) {
            // Игнорируем ошибки парсинга
            _monthInitialized =
                true; // Помечаем как инициализированный даже при ошибке
          }
        } else if (data.lastWorkoutMonth != null) {
          // Помечаем как инициализированный, если месяц уже был установлен ранее
          _monthInitialized = true;
        }

        // Фильтруем тренировки по текущему месяцу
        final items = data.activities
            .where((w) {
              return w.when.year == _month.year && w.when.month == _month.month;
            })
            .toList(growable: false);

        // Получаем календарь для текущего месяца
        final monthKey =
            '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
        final calendarData = <int, String>{};

        // Получаем дни для текущего месяца из календаря
        if (data.calendar.containsKey(monthKey)) {
          final daysMap = data.calendar[monthKey]!;
          for (final entry in daysMap.entries) {
            final day = int.tryParse(entry.key);
            final dist = entry.value;
            if (day != null) {
              calendarData[day] = dist;
            }
          }
        }

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
                    if (_sports.contains(i)) {
                      _sports.remove(i);
                    } else {
                      _sports.add(i);
                    }
                    // Инвалидируем провайдер для перезагрузки данных
                    ref.invalidate(trainingActivitiesProvider(_sports));
                  }),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ── Карточка календаря
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _CalendarCard(month: _month, bubbles: calendarData),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // ── Таблица тренировок (единый контейнер на всю ширину, без скруглений)
            if (items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      data.activities.isEmpty
                          ? 'Нет тренировок за выбранный месяц'
                          : 'Нет тренировок в ${_MonthToolbar._monthTitle(_month)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: _WorkoutTable(
                  items: items.map((a) => _Workout.fromTraining(a)).toList(),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SelectableText.rich(
            TextSpan(
              text: 'Ошибка загрузки тренировок:\n',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.getTextPrimaryColor(context),
              ),
              children: [
                TextSpan(
                  text: ErrorHandler.format(error),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
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
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimaryColor(context),
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

  static String _monthTitle(DateTime m) {
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
        child: Icon(
          icon,
          size: 18,
          color: AppColors.getIconPrimaryColor(context),
        ),
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
          color: selected
              ? AppColors.brandPrimary
              : AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected
              ? AppColors.getSurfaceColor(context)
              : AppColors.getTextPrimaryColor(context),
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
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadowSoft
                : AppColors.shadowSoft,
            offset: const Offset(0, 1),
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
            color: weekend
                ? AppColors.error
                : AppColors.getTextSecondaryColor(context),
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
                              : AppColors.getTextPrimaryColor(context),
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
                              // Цвет всегда светлый, чтобы в тёмной теме текст был
                              // читаемым на синем фоне
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
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border(
          top: BorderSide(color: AppColors.getBorderColor(context), width: 0.5),
          bottom: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadowSoft
                : AppColors.shadowSoft,
            offset: const Offset(0, 1),
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
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.getDividerColor(context),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _WorkoutRow extends ConsumerWidget {
  final _Workout item;
  const _WorkoutRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final auth = ref.read(authServiceProvider);
        final userId = await auth.getUserId();
        if (userId == null) return;

        // Получаем данные пользователя (пока используем дефолтные значения)
        final userName = 'Пользователь';
        final userAvatar = 'assets/avatar_2.png';

        final activity = item.toActivity(userId, userName, userAvatar);

        if (!context.mounted) return;

        Navigator.of(context).push(
          TransparentPageRoute(
            builder: (_) => ActivityDescriptionPage(
              activity: activity,
              currentUserId: userId,
            ),
          ),
        );
      },
      child: Padding(
        // слева/сверху/снизу уменьшены, справа прежний 12
        padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
        child: Row(
          children: [
            // Мини-карта 80x55 (статичная карта маршрута)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: SizedBox(
                width: 80,
                height: 55,
                child: item.points.isEmpty
                    ? const Image(
                        image: AssetImage('assets/training_map.png'),
                        fit: BoxFit.cover,
                      )
                    : RouteCard(points: item.points, height: 55),
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
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Три метрики — строго таблично, с вертикальными разделителями
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Иконка вида спорта в отдельной колонке с фиксированной шириной
                        SizedBox(
                          width: 21,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Icon(
                              item.kind == 0
                                  ? Icons.directions_run
                                  : (item.kind == 1
                                        ? Icons.pedal_bike
                                        : Icons.pool),
                              size: 15,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _metric(
                            context,
                            null,
                            item.distText,
                            MainAxisAlignment.start,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 0.5,
                          color: AppColors.getDividerColor(context),
                          indent: 0,
                          endIndent: 0,
                        ),
                        Expanded(
                          child: _metric(
                            context,
                            null,
                            item.durText,
                            MainAxisAlignment.center,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 0.5,
                          color: AppColors.getDividerColor(context),
                          indent: 0,
                          endIndent: 0,
                        ),
                        Expanded(
                          child: _metric(
                            context,
                            null,
                            item.paceText,
                            MainAxisAlignment.center,
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
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    IconData? icon,
    String text,
    MainAxisAlignment alignment,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: AppColors.getTextSecondaryColor(context),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ],
      ),
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

/// Модель тренировки
class _Workout {
  final int id;
  final DateTime when;
  final int kind; // 0 бег, 1 вело, 2 плавание
  final String distText;
  final String durText;
  final String paceText;
  final List<LatLng> points; // Точки маршрута для карты
  final double distance; // км для конвертации
  final int duration; // секунды для конвертации
  final double pace; // темп для конвертации

  _Workout(
    this.id,
    this.when,
    this.kind,
    this.distText,
    this.durText,
    this.paceText,
    this.distance,
    this.duration,
    this.pace, [
    this.points = const [],
  ]);

  /// Создаёт из TrainingActivity
  factory _Workout.fromTraining(TrainingActivity activity) {
    // Конвертируем RoutePoint в LatLng
    final latLngPoints = activity.points
        .map((p) => LatLng(p.lat, p.lng))
        .toList(growable: false);

    return _Workout(
      activity.id,
      activity.when,
      activity.sportType,
      activity.distanceText,
      activity.durationText,
      activity.paceText,
      activity.distance,
      activity.duration,
      activity.pace,
      latLngPoints,
    );
  }

  /// Конвертирует в Activity для description_screen
  al.Activity toActivity(int userId, String userName, String userAvatar) {
    // Определяем тип спорта как строку
    final sportTypeStr = kind == 0 ? 'run' : (kind == 1 ? 'bike' : 'swim');

    // Создаём ActivityStats из доступных данных
    final stats = al.ActivityStats(
      distance: distance * 1000, // км -> метры
      realDistance: distance * 1000,
      avgSpeed: pace > 0 ? 60.0 / pace : 0.0, // км/ч (приблизительно)
      avgPace: pace,
      minAltitude: 0.0,
      minAltitudeCoords: null,
      maxAltitude: 0.0,
      maxAltitudeCoords: null,
      cumulativeElevationGain: 0.0,
      cumulativeElevationLoss: 0.0,
      startedAt: when,
      startedAtCoords: points.isNotEmpty
          ? al.Coord(lat: points.first.latitude, lng: points.first.longitude)
          : null,
      finishedAt: when.add(Duration(seconds: duration)),
      finishedAtCoords: points.isNotEmpty
          ? al.Coord(lat: points.last.latitude, lng: points.last.longitude)
          : null,
      duration: duration,
      bounds: points.length >= 2
          ? [
              al.Coord(lat: points.first.latitude, lng: points.first.longitude),
              al.Coord(lat: points.last.latitude, lng: points.last.longitude),
            ]
          : [],
      avgHeartRate: null,
      heartRatePerKm: {},
      pacePerKm: {},
    );

    // Конвертируем LatLng в Coord
    final coordPoints = points
        .map((p) => al.Coord(lat: p.latitude, lng: p.longitude))
        .toList();

    return al.Activity(
      id: id,
      type: sportTypeStr,
      dateStart: when,
      dateEnd: when.add(Duration(seconds: duration)),
      lentaId: id, // Используем id активности как lentaId
      lentaDate: when,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      likes: 0,
      comments: 0,
      userGroup: 0,
      equipments: const [],
      stats: stats,
      points: coordPoints,
      postDateText: '',
      postMediaUrl: '',
      postContent: '',
      islike: false,
      mediaImages: const [],
      mediaVideos: const [],
    );
  }
}
