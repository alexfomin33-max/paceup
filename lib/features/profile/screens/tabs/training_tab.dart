import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../providers/training/training_provider.dart';
import '../../../../../core/utils/static_map_url_builder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../lenta/screens/activity/description_screen.dart';
import '../../../../domain/models/activity_lenta.dart' as al;
import '../../../../../providers/services/auth_provider.dart';
import '../../../../../core/widgets/transparent_route.dart';
import '../../../../../core/utils/activity_format.dart';
import '../../../../../core/services/route_map_service.dart';

class TrainingTab extends ConsumerStatefulWidget {
  /// ID пользователя, чьи тренировки нужно отобразить
  final int userId;
  const TrainingTab({super.key, required this.userId});

  @override
  ConsumerState<TrainingTab> createState() => TrainingTabState();
}

class TrainingTabState extends ConsumerState<TrainingTab>
    with AutomaticKeepAliveClientMixin {
  // Текущий месяц
  late DateTime _month;

  // Мультиселект видов спорта: 0 бег(включая indoor-running), 1 вело(включая indoor-cycling), 2 плавание, 3 лыжи, 6 walking, 7 hiking
  // indoor-cycling и indoor-running не показываются отдельно, они суммируются с bike и run соответственно
  Set<int> _sports = {0, 1, 2, 3, 6, 7};

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

  /// Публичный метод для обновления данных тренировок
  void refresh() {
    ref.invalidate(
      trainingActivitiesProvider((userId: widget.userId, sports: _sports)),
    );
  }

  /// Pull-to-refresh: инвалидирует провайдер и ждёт завершения загрузки
  /// (как в main_tab.dart)
  Future<void> _refresh() async {
    ref.invalidate(
      trainingActivitiesProvider((userId: widget.userId, sports: _sports)),
    );
    await ref.read(
      trainingActivitiesProvider((
        userId: widget.userId,
        sports: _sports,
      )).future,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Получаем данные из провайдера с userId профиля
    final trainingDataAsync = ref.watch(
      trainingActivitiesProvider((userId: widget.userId, sports: _sports)),
    );

    // ────────────────────────────────────────────────────────────────
    // Всегда CustomScrollView с BouncingScrollPhysics и
    // CupertinoSliverRefreshControl (как в main_tab.dart).
    // Оверскролл сверху даёт pull-to-refresh для перезагрузки контента.
    // ────────────────────────────────────────────────────────────────
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _refresh),
        ...trainingDataAsync.when(
          data: (data) {
            // Если получили месяц последней тренировки — только при первой загрузке
            if (data.lastWorkoutMonth != null &&
                mounted &&
                !_monthInitialized) {
              try {
                final parts = data.lastWorkoutMonth!.split('-');
                if (parts.length == 2) {
                  final year = int.parse(parts[0]);
                  final month = int.parse(parts[1]);
                  final newMonth = DateTime(year, month, 1);
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
                _monthInitialized = true;
              }
            } else if (data.lastWorkoutMonth != null) {
              _monthInitialized = true;
            }

            // Фильтруем по текущему месяцу и выбранным видам спорта
            final items = data.activities
                .where((w) {
                  return w.when.year == _month.year &&
                      w.when.month == _month.month &&
                      _sports.contains(w.sportType);
                })
                .toList(growable: false);

            // Группируем тренировки по дню и типу спорта, суммируем дистанции
            final dayBubbles = <int, List<_BubbleData>>{};
            final daySportDistances = <int, Map<int, double>>{};
            for (final activity in data.activities) {
              if (activity.when.year == _month.year &&
                  activity.when.month == _month.month &&
                  _sports.contains(activity.sportType)) {
                final day = activity.when.day;
                final distanceValue = activity.distance;
                daySportDistances
                    .putIfAbsent(day, () => <int, double>{})
                    .update(
                      activity.sportType,
                      (value) => value + distanceValue,
                      ifAbsent: () => distanceValue,
                    );
              }
            }
            for (final entry in daySportDistances.entries) {
              final day = entry.key;
              final sportDistances = entry.value;
              final bubbles = <_BubbleData>[];
              for (final sportEntry in sportDistances.entries) {
                final sportType = sportEntry.key;
                final totalDistance = sportEntry.value;
                // Плавание (2) — два знака (сотые, метры); остальные — один (десятичные)
                final frac = sportType == 2 ? 2 : 1;
                final distanceText = totalDistance
                    .toStringAsFixed(frac)
                    .replaceAll('.', ',');
                bubbles.add(
                  _BubbleData(distanceText: distanceText, sportType: sportType),
                );
              }
              dayBubbles[day] = bubbles;
            }

            return [
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
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
                      final newSports = Set<int>.from(_sports);
                      if (newSports.contains(i)) {
                        newSports.remove(i);
                      } else {
                        newSports.add(i);
                      }
                      _sports = newSports;
                    }),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _CalendarCard(month: _month, dayBubbles: dayBubbles),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              if (items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        data.activities.isEmpty
                            ? 'Нет тренировок за выбранный месяц'
                            : 'Нет тренировок в '
                                  '${_MonthToolbar._monthTitle(_month)}',
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _WorkoutTable(
                      items: items
                          .map((a) => _Workout.fromTraining(a))
                          .toList(),
                      profileUserId: widget.userId,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ];
          },
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CupertinoActivityIndicator(
                    radius: 10,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ),
          ],
          error: (error, stack) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
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
            ),
          ],
        ),
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
          sportType: 0,
          onTap: () => onToggleSport(0),
        ),
        const SizedBox(width: 8),
        _SportIcon(
          selected: sports.contains(1),
          icon: Icons.directions_bike,
          sportType: 1,
          onTap: () => onToggleSport(1),
        ),
        const SizedBox(width: 8),
        _SportIcon(
          selected: sports.contains(2),
          icon: Icons.pool,
          sportType: 2,
          onTap: () => onToggleSport(2),
        ),
        const SizedBox(width: 8),
        _SportIcon(
          selected: sports.contains(3),
          icon: Icons.downhill_skiing,
          sportType: 3,
          onTap: () => onToggleSport(3),
        ),
        const SizedBox(width: 8),
        _SportIcon(
          selected: sports.contains(6),
          icon: Icons.directions_walk,
          sportType: 6,
          onTap: () => onToggleSport(6),
        ),
        const SizedBox(width: 8),
        _SportIcon(
          selected: sports.contains(7),
          icon: Icons.terrain,
          sportType: 7,
          onTap: () => onToggleSport(7),
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
  final int sportType; // 0 бег(включая indoor-running), 1 вело(включая indoor-cycling), 2 плавание, 3 лыжи, 6 walking, 7 hiking
  final VoidCallback onTap;
  const _SportIcon({
    required this.selected,
    required this.icon,
    required this.sportType,
    required this.onTap,
  });

  /// Получить цвет активной иконки в зависимости от типа спорта
  Color _getActiveColor() {
    switch (sportType) {
      case 1: // велосипед (включая indoor-cycling)
        return AppColors.female; // Розовый цвет, как в main_tab.dart
      case 2: // плавание
        return AppColors.green;
      case 3: // лыжи
        return AppColors.warning; // Оранжевый цвет для лыж
      case 6: // walking
      case 7: // hiking
      default: // бег (0, включая indoor-running)
        return AppColors.brandPrimary;
    }
  }

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
              ? _getActiveColor()
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

/// Данные для одной пилюли в календаре
class _BubbleData {
  final String distanceText;
  final int sportType;

  const _BubbleData({required this.distanceText, required this.sportType});
}

class _CalendarCard extends StatelessWidget {
  final DateTime month;
  final Map<int, List<_BubbleData>> dayBubbles; // день => список пилюль

  const _CalendarCard({required this.month, required this.dayBubbles});

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
            dayBubbles: dayBubbles,
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
  final Map<int, List<_BubbleData>> dayBubbles; // день => список пилюль
  final double tallHeight;
  final double compactHeight;
  final double dayTop;
  final double bubbleTop;

  const _MonthGrid({
    required this.month,
    required this.dayBubbles,
    required this.tallHeight,
    required this.compactHeight,
    required this.dayTop,
    required this.bubbleTop,
  });

  /// Определяет декорацию облачка на основе типа спорта
  BoxDecoration _getBubbleDecoration(int sportType) {
    Color color;
    switch (sportType) {
      case 1: // велосипед (включая indoor-cycling)
        color = AppColors.female;
        break;
      case 2: // плавание
        color = AppColors.green;
        break;
      case 3: // лыжи
        color = AppColors.warning;
        break;
      case 6: // walking
      case 7: // hiking
      default: // бег (0, включая indoor-running)
        color = AppColors.brandPrimary;
    }
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
  }

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
        // Находим максимальное количество пилюль в строке для определения высоты
        int maxBubblesInRow = 0;
        for (int c = 0; c < 7; c++) {
          final idx = r * 7 + c;
          final dayNum = idx - startOffset + 1;
          if (dayNum >= 1 && dayNum <= last.day) {
            final bubbles = dayBubbles[dayNum];
            if (bubbles != null && bubbles.length > maxBubblesInRow) {
              maxBubblesInRow = bubbles.length;
            }
          }
        }
        // Высота ячейки зависит от количества пилюль.
        // Берём расчётную высоту стеком: отступ до пилюль + высота пилюль +
        // промежутки + нижний запас, затем сравниваем с компактной высотой.
        const bubbleHeight = 20.0; // 11px текст + ~9px padding ≈ 20px
        const bubbleGap = 2.0;
        final bubblesHeight = maxBubblesInRow > 0
            ? bubbleTop +
                  maxBubblesInRow * bubbleHeight +
                  (maxBubblesInRow - 1) * bubbleGap +
                  4 // небольшой запас снизу
            : compactHeight;
        final rowHeight = maxBubblesInRow > 0
            ? bubblesHeight.clamp(compactHeight, double.infinity)
            : compactHeight;

        return Row(
          children: List.generate(7, (c) {
            final idx = r * 7 + c;
            final dayNum = idx - startOffset + 1;

            if (dayNum < 1 || dayNum > last.day) {
              return Expanded(child: SizedBox(height: rowHeight));
            }

            final isWeekend = (c == 5) || (c == 6);
            final bubbles = dayBubbles[dayNum];

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
                    // Отображаем все пилюли друг под другом
                    if (bubbles != null && bubbles.isNotEmpty)
                      Positioned(
                        top: bubbleTop,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: bubbles.asMap().entries.map((entry) {
                            final index = entry.key;
                            final bubble = entry.value;
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index < bubbles.length - 1 ? 2 : 0,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: _getBubbleDecoration(
                                  bubble.sportType,
                                ),
                                child: Text(
                                  bubble.distanceText,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: AppColors.surface,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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
  final int profileUserId;
  const _WorkoutTable({required this.items, required this.profileUserId});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: List.generate(items.length, (i) {
        final w = items[i];
        return Padding(
          padding: EdgeInsets.only(bottom: i < items.length - 1 ? 6 : 0),
          child: _WorkoutCard(item: w, profileUserId: profileUserId),
        );
      }),
    );
  }
}

/// Отдельная карточка тренировки.
/// Каждая карточка имеет собственный контейнер с скруглениями и отступами.
class _WorkoutCard extends ConsumerWidget {
  final _Workout item;
  final int profileUserId;
  const _WorkoutCard({required this.item, required this.profileUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final auth = ref.read(authServiceProvider);
        final currentUserId = await auth.getUserId();
        if (currentUserId == null) return;
        if (!context.mounted) return;

        // ────────────────────────────────────────────────────────────────
        // ⚡ PERFORMANCE: переход сразу по данным карточки.
        // Раньше _loadActivityById (до 6 HTTP к /activities_lenta.php)
        // блокировал переход на 1–30+ сек. toActivity() даёт достаточно для
        // ActivityDescriptionPage; экран сам подгружает _loadUserData и
        // _loadChartsData в initState.
        // ────────────────────────────────────────────────────────────────
        final activity = item.toActivity(
          profileUserId,
          'Пользователь',
          'assets/avatar_2.png',
        );

        Navigator.of(context, rootNavigator: true).push(
          TransparentPageRoute(
            builder: (_) => ActivityDescriptionPage(
              activity: activity,
              currentUserId: currentUserId,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 12, 2),
          child: Row(
            children: [
              // Мини-карта/изображение 80x70
              // Логика приоритетов:
              // 1. Если есть фотографии → показываем первую фотографию (приоритет над картой)
              // 2. Если нет фотографий, но есть трек → показываем карту маршрута
              // 3. Если нет фотографий И нет трека → показываем заглушку
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: SizedBox(
                  width: 80,
                  height: 74,
                  child: _WorkoutCard._buildActivityImage(
                    context,
                    item,
                    userId: profileUserId,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Текстовая часть
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Дата/время
                    Text(
                      _fmtDate(item.when),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Три метрики — строго таблично, выровнены по левому краю
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Иконка вида спорта в отдельной колонке с фиксированной шириной
                          SizedBox(
                            width: 18,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: item.kind == 1
                                      ? AppColors
                                            .female // Розовый для велосипеда
                                      : (item.kind == 2
                                            ? AppColors
                                                  .green // Зеленый для плавания
                                            : (item.kind == 3
                                                  ? AppColors
                                                        .warning // Оранжевый для лыж
                                                  : AppColors
                                                        .brandPrimary)), // Синий для бега
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xl,
                                  ),
                                ),
                                child: Icon(
                                  item.kind == 0
                                      ? Icons.directions_run
                                      : (item.kind == 1
                                            ? Icons.directions_bike
                                            : (item.kind == 2
                                                  ? Icons.pool
                                                  : Icons.downhill_skiing)),
                                  size: 12,
                                  color: AppColors.getSurfaceColor(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _metric(
                            context,
                            null,
                            item.distText,
                            MainAxisAlignment.start,
                          ),
                          Expanded(
                            child: _metric(
                              context,
                              null,
                              item.durText,
                              MainAxisAlignment.center,
                            ),
                          ),
                          _metric(
                            context,
                            null,
                            _formatPaceWithUnits(item.paceText, item.kind),
                            MainAxisAlignment.start,
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
      ),
    );
  }

  /// Строит изображение для активности согласно логике приоритетов:
  /// 1. Если есть фотографии (firstImageUrl) → показываем первую фотографию
  /// 2. Если нет фотографий, но есть валидный трек → показываем карту MapBox
  /// 3. Если нет фотографий И нет трека → показываем заглушку
  static Widget _buildActivityImage(
    BuildContext context,
    _Workout item, {
    required int userId,
  }) {
    // 1. Если есть фотографии → показываем первую фотографию (приоритет над картой)
    if (item.firstImageUrl != null && item.firstImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item.firstImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: AppColors.getBackgroundColor(context),
          child: Center(
            child: CupertinoActivityIndicator(
              radius: 10,
              color: AppColors.getIconSecondaryColor(context),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          // Если ошибка загрузки фотографии, показываем карту или заглушку
          if (item.hasValidTrack) {
            return _buildStaticMiniMap(
              context,
              item.points,
              activityId: item.id,
              userId: userId,
            );
          }
          return _buildPlaceholderImage(item.kind);
        },
      );
    }

    // 2. Если нет фотографий, но есть валидный трек → показываем карту MapBox
    if (item.hasValidTrack) {
      return _buildStaticMiniMap(
        context,
        item.points,
        activityId: item.id,
        userId: userId,
      );
    }

    // 3. Если нет фотографий И нет трека → показываем заглушку
    return _buildPlaceholderImage(item.kind);
  }

  /// Строит статичную мини-карту маршрута (80x70px).
  ///
  /// ⚡ PERFORMANCE OPTIMIZATION для маленьких карт:
  /// - Использует DPR 1.5 (вместо полного devicePixelRatio) для уменьшения веса файла
  /// - Ограничивает maxWidth/maxHeight до 160x140px для еще большей экономии
  /// - Прореживает точки (каждую 30-ю) для треков с большим количеством точек
  /// - Кеширование через CachedNetworkImage с memCacheWidth/maxWidthDiskCache
  /// - Использует сохраненные изображения карт с сервера, если они есть
  static Widget _buildStaticMiniMap(
    BuildContext context,
    List<LatLng> points, {
    int? activityId,
    int? userId,
  }) {
    const widthDp = 80.0;
    const heightDp = 74.0; // Соответствует высоте виджета в UI

    // ────────────────────────────────────────────────────────────────
    // 🔹 ПРОРЕЖИВАНИЕ ТОЧЕК: для треков с большим количеством точек
    // ────────────────────────────────────────────────────────────────
    // Берем каждую 30-ю точку, чтобы уменьшить размер URL и ускорить генерацию
    final thinnedPoints = _thinPoints(points, step: 30);

    // Проверяем валидность прореженных точек
    if (!_arePointsValidForMap(thinnedPoints)) {
      // Если после прореживания точки все еще невалидны, возвращаем дефолтное изображение
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.getSurfaceColor(context),
        child: const Icon(
          Icons.map_outlined,
          color: AppColors.brandPrimary,
          size: 24,
        ),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ОПТИМИЗАЦИЯ РАЗМЕРА: используем ограниченный DPR для мини-карт
    // ────────────────────────────────────────────────────────────────
    // Для маленьких карт достаточно DPR 1.5 вместо полного devicePixelRatio
    // Это уменьшает размер файла в 2-3 раза без заметной потери качества
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final optimizedDpr = (dpr > 1.5 ? 1.5 : dpr).clamp(1.0, 1.5);

    final widthPx = (widthDp * optimizedDpr).round();
    final heightPx = (heightDp * optimizedDpr).round();

    // ────────────────────────────────────────────────────────────────
    // 🔹 ЛОГИКА: сначала проверяем кеш мини-карты, если есть - используем сохраненное
    // Если нет в кеше - генерируем Mapbox с увеличенным strokeWidth для читаемости
    // и сохраняем в фоне как мини-карту
    // ────────────────────────────────────────────────────────────────
    final routeMapService = RouteMapService();
    String mapUrl;
    bool shouldSaveAfterLoad = false;

    // Проверяем наличие сохраненной мини-карты в кеше (синхронно)
    final cachedUrl = activityId != null
        ? routeMapService.getCachedRouteMapUrl(activityId, thumbnail: true)
        : null;

    if (cachedUrl != null) {
      // Используем сохраненное изображение мини-карты из кеша
      mapUrl = cachedUrl;
      shouldSaveAfterLoad = false; // Не сохраняем, так как уже есть на сервере
    } else {
      // Если нет в кеше - генерируем через Mapbox с увеличенным strokeWidth для читаемости
      try {
        mapUrl = StaticMapUrlBuilder.fromPoints(
          points: thinnedPoints,
          widthPx: widthPx.toDouble(),
          heightPx: heightPx.toDouble(),
          strokeWidth:
              4.0, // Увеличенная ширина линии для лучшей читаемости на маленьких картах
          padding: 8.0,
          maxWidth: 160.0, // Дополнительное ограничение для маленьких карт
          maxHeight: 140.0, // Дополнительное ограничение для маленьких карт
        );

        // Сохраняем изображение на сервер в фоне после загрузки как мини-карту
        if (activityId != null && userId != null) {
          shouldSaveAfterLoad = true;
        }

        // Проверяем сервер в фоне для следующей загрузки (на случай если уже есть на сервере)
        if (activityId != null) {
          routeMapService
              .getRouteMapUrl(activityId, thumbnail: true)
              .catchError((_) {
                // Игнорируем ошибки проверки в фоне
                return null;
              });
        }
      } catch (e) {
        // Если не удалось сгенерировать URL (например, некорректные точки),
        // возвращаем дефолтное изображение
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.getSurfaceColor(context),
          child: const Icon(
            Icons.map_outlined,
            color: AppColors.brandPrimary,
            size: 24,
          ),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: mapUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      memCacheWidth: widthPx,
      maxWidthDiskCache: widthPx,
      placeholder: (context, url) => Container(
        color: AppColors.getBackgroundColor(context),
        child: Center(
          child: CupertinoActivityIndicator(
            radius: 10,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.getBackgroundColor(context),
        child: Icon(
          CupertinoIcons.map,
          color: AppColors.getIconSecondaryColor(context),
          size: 32,
        ),
      ),
      // Сохраняем изображение на сервер после успешной загрузки как мини-карту
      imageBuilder: shouldSaveAfterLoad
          ? (context, imageProvider) {
              // Сохраняем изображение асинхронно в фоне, не блокируя UI
              final routeMapService = RouteMapService();
              routeMapService.saveRouteMapFromUrl(
                activityId: activityId!,
                userId: userId!,
                mapboxUrl: mapUrl,
                thumbnail: true, // Сохраняем как мини-карту для экрана профиля
              );
              return Image(image: imageProvider);
            }
          : null,
    );
  }

  /// Прореживает точки маршрута для оптимизации построения карты.
  static List<LatLng> _thinPoints(
    List<LatLng> points, {
    int step = 30,
    int threshold = 100,
  }) {
    // Если точек мало или step <= 1, возвращаем как есть
    if (points.length <= 2 || step <= 1) {
      return points;
    }

    // Если точек меньше порога, не прореживаем
    if (points.length < threshold) {
      return points;
    }

    final thinnedPoints = <LatLng>[];

    // Всегда добавляем первую точку
    thinnedPoints.add(points.first);

    // Добавляем каждую step-ю точку, начиная с индекса step
    for (int i = step; i < points.length - 1; i += step) {
      thinnedPoints.add(points[i]);
    }

    // Всегда добавляем последнюю точку (если она еще не добавлена)
    final lastPoint = points.last;
    if (thinnedPoints.last != lastPoint) {
      thinnedPoints.add(lastPoint);
    }

    return thinnedPoints;
  }

  /// Проверяет, что точки маршрута валидны для построения карты.
  static bool _arePointsValidForMap(List<LatLng> points) {
    if (points.isEmpty || points.length < 2) {
      return false;
    }

    // Находим минимальные и максимальные координаты
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Проверяем, что есть достаточный разброс координат
    // Минимум 0.001 градуса (~100 метров) для валидной карты
    const minDifference = 0.001;
    final latDifference = maxLat - minLat;
    final lngDifference = maxLng - minLng;

    return latDifference >= minDifference || lngDifference >= minDifference;
  }

  /// Строит изображение-заглушку при отсутствии фото и карты маршрута.
  /// Бег — nogps.jpg, Велосипед — nogsp_bike.jpg, Плавание — nogps_swim.jpg,
  /// Лыжи — nogps_ski.jpg
  static Widget _buildPlaceholderImage(int kind) {
    final asset = kind == 0
        ? 'assets/nogps.jpg' // Бег
        : (kind == 1
              ? 'assets/nogsp_bike.jpg' // Велосипед
              : (kind == 2
                    ? 'assets/nogps_swim.jpg' // Плавание
                    : (kind == 3
                          ? 'assets/nogps_ski.jpg' // Лыжи
                          : 'assets/nogps.jpg'))); // fallback
    return Image(image: AssetImage(asset), fit: BoxFit.cover);
  }

  /// Отображает метрику с выравниванием по левому краю
  Widget _metric(
    BuildContext context,
    IconData? icon,
    String text,
    MainAxisAlignment alignment,
  ) {
    // Разделяем текст на числовую часть и единицы измерения
    final unitPattern = RegExp(
      r'\s*(км|м|ч|мин|сек|/км|/100м|км/ч|м/с)\s*$',
      caseSensitive: false,
    );
    final match = unitPattern.firstMatch(text);

    String numberPart = text;
    String? unitPart;

    if (match != null) {
      numberPart = text.substring(0, match.start).trim();
      unitPart = match.group(0)?.trim();
    }

    return Row(
      mainAxisAlignment: alignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.getTextSecondaryColor(context)),
          const SizedBox(width: 8),
        ],
        Text.rich(
          TextSpan(
            text: numberPart,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimaryColor(context),
            ),
            children: unitPart != null
                ? [
                    TextSpan(
                      text: ' $unitPart',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ]
                : null,
          ),
        ),
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

  /// Форматирует темп с правильными единицами измерения в зависимости от типа спорта
  /// kind: 0=бег, 1=вело, 2=плавание, 3=лыжи
  static String _formatPaceWithUnits(String paceText, int kind) {
    // Убираем старые единицы измерения
    final paceValue = paceText
        .replaceAll('/км', '')
        .replaceAll('км/ч', '')
        .replaceAll('м/с', '')
        .replaceAll('/100м', '')
        .trim();

    // Добавляем правильные единицы в зависимости от типа спорта
    switch (kind) {
      case 1: // велосипед
        return '$paceValue км/ч';
      case 2: // плавание
        return '$paceValue /100м';
      case 0: // бег
      case 3: // лыжи
      default:
        return '$paceValue /км';
    }
  }
}

/// Модель тренировки
class _Workout {
  final int id;
  final DateTime when;
  final int kind; // 0 бег, 1 вело, 2 плавание, 3 лыжи
  final String distText;
  final String durText;
  final String paceText;
  final List<LatLng> points; // Точки маршрута для карты
  final double distance; // км для конвертации
  final int duration; // секунды для конвертации
  final double pace; // темп для конвертации
  final bool hasValidTrack; // Есть ли валидный трек маршрута
  final String? firstImageUrl; // URL первого изображения (если есть)

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
    this.hasValidTrack = false,
    this.firstImageUrl,
  ]);

  /// Создаёт из TrainingActivity
  factory _Workout.fromTraining(TrainingActivity activity) {
    // Конвертируем RoutePoint в LatLng
    final latLngPoints = activity.points
        .map((p) => LatLng(p.lat, p.lng))
        .toList(growable: false);

    // ──────────────────────────────────────────────────────────────
    // 🏊 ПЕРЕСЧЕТ ТЕМПА ДЛЯ ПЛАВАНИЯ: мин/100м вместо м/сек
    // ──────────────────────────────────────────────────────────────
    String paceText = activity.paceText;
    double pace = activity.pace;

    // ──────────────────────────────────────────────────────────────
    // 🏊 ФОРМАТИРОВАНИЕ ДИСТАНЦИИ ДЛЯ ПЛАВАНИЯ: метры вместо километров
    // ──────────────────────────────────────────────────────────────
    String distanceText = activity.distanceText;
    if (activity.sportType == 2) {
      // Для плавания конвертируем километры в метры
      final distanceMeters = activity.distance * 1000;
      // Форматируем как целое число или с одним знаком после запятой
      if (distanceMeters == distanceMeters.roundToDouble()) {
        // Целое число: "300 м"
        distanceText = '${distanceMeters.toInt()} м';
      } else {
        // Дробное число: "300,5 м" (запятая для русской локали)
        distanceText =
            '${distanceMeters.toStringAsFixed(1).replaceAll('.', ',')} м';
      }
    }

    if (activity.sportType == 2) {
      // Для плавания пересчитываем темп в формат "мин/100м"
      if (activity.distance > 0 && activity.duration > 0) {
        // Рассчитываем темп из расстояния и времени: (время в сек * 100) / (расстояние в м * 60)
        final distanceMeters =
            activity.distance * 1000; // конвертируем км в метры
        final paceMinPer100m =
            (activity.duration * 100) / (distanceMeters * 60);
        paceText = formatPace(paceMinPer100m);
        pace = paceMinPer100m;
      } else if (activity.pace > 0) {
        // Если есть темп в мин/км, пересчитываем в мин/100м (делим на 10)
        final paceMinPer100m = activity.pace / 10.0;
        paceText = formatPace(paceMinPer100m);
        pace = paceMinPer100m;
      }
    }

    return _Workout(
      activity.id,
      activity.when,
      activity.sportType,
      distanceText,
      activity.durationText,
      paceText,
      activity.distance,
      activity.duration,
      pace,
      latLngPoints,
      activity.hasValidTrack,
      activity.firstImageUrl,
    );
  }

  /// Конвертирует в Activity для description_screen
  al.Activity toActivity(int userId, String userName, String userAvatar) {
    // Определяем тип спорта как строку
    final sportTypeStr = kind == 0
        ? 'run'
        : (kind == 1
              ? 'bike'
              : (kind == 2 ? 'swim' : (kind == 3 ? 'ski' : 'run')));

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
