import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/stats_service.dart';

/// Вкладка «По видам» — интерактивная:
/// • Выпадающий период (неделя/месяц/год)
/// • Переключение вида спорта (бег/вело/плавание)
List<Widget> buildByTypeStatsSlivers(int userId) {
  return [SliverToBoxAdapter(child: _ByTypeContent(userId: userId))];
}

class StatsTab extends StatefulWidget {
  final int? userId;
  /// Индекс вида спорта по умолчанию (0 бег, 1 вело, 2 плавание, 3 лыжи).
  /// Если передан и совпадает с основным видом пользователя — эта иконка активна при открытии.
  final int? initialSport;
  const StatsTab({super.key, this.userId, this.initialSport});

  @override
  State<StatsTab> createState() => StatsTabState();
}

class StatsTabState extends State<StatsTab>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<_ByTypeContentState> _contentKey = GlobalKey<_ByTypeContentState>();

  @override
  bool get wantKeepAlive => true;

  /// Публичный метод для обновления данных статистики
  void refresh() {
    _contentKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userId = widget.userId;
    if (userId == null) {
      return const Center(child: Text('Ошибка: не указан userId'));
    }

    // Отключаем скроллинг у CustomScrollView, чтобы скроллинг управлялся
    // только NestedScrollView в profile_screen.dart
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverToBoxAdapter(
          child: _ByTypeContent(
            key: _contentKey,
            userId: userId,
            initialSport: widget.initialSport,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
      ],
    );
  }
}

class _ByTypeContent extends StatefulWidget {
  final int userId;
  /// Индекс вида спорта по умолчанию (0 бег, 1 вело, 2 плавание, 3 лыжи).
  final int? initialSport;
  const _ByTypeContent({
    super.key,
    required this.userId,
    this.initialSport,
  });
  @override
  State<_ByTypeContent> createState() => _ByTypeContentState();
}

class _ByTypeContentState extends State<_ByTypeContent> {
  final StatsService _statsService = StatsService();

  // Периоды
  static const _periods = ['За неделю', 'За месяц', 'За год'];
  String _period = 'За год';

  // Вид спорта: 0 бег, 1 вело, 2 плавание, 3 лыжи (single-select)
  int _sport = 0;

  // Состояние загрузки
  bool _isLoading = true;
  StatsData? _statsData;
  String? _error;

  // Текущий год для графиков (для периода "За год")
  int _currentYear = DateTime.now().year;

  // Текущая выбранная неделя (для периода "За неделю")
  DateTime _currentWeekStart = _getCurrentWeekStart();

  // Текущий выбранный месяц (для периода "За месяц")
  DateTime _currentMonthStart = _getCurrentMonthStart();

  // Вспомогательные функции для получения начала недели/месяца
  static DateTime _getCurrentWeekStart() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday; // 1 (понедельник) - 7 (воскресенье)
    final daysToMonday = dayOfWeek - 1;
    return DateTime(now.year, now.month, now.day - daysToMonday);
  }

  static DateTime _getCurrentMonthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  @override
  void initState() {
    super.initState();
    // По умолчанию активна иконка основного вида спорта пользователя (users.sport)
    if (widget.initialSport != null &&
        widget.initialSport! >= 0 &&
        widget.initialSport! <= 3) {
      _sport = widget.initialSport!;
    }
    _loadStats();
  }

  /// Публичный метод для обновления данных статистики
  void refresh() {
    _loadStats();
  }

  /// Загружает статистику с текущими фильтрами
  Future<void> _loadStats({int? year, DateTime? weekStart, DateTime? monthStart}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final periodMap = {
        'За неделю': 'week',
        'За месяц': 'month',
        'За год': 'year',
      };

      // indoor-cycling суммируется с bike, indoor-running с run
      final sportTypeMap = {
        0: 'run', // включает indoor-running
        1: 'bike', // включает indoor-cycling
        2: 'swim',
        3: 'ski',
        6: 'walking',
        7: 'hiking',
      };

      final period = periodMap[_period] ?? 'year';
      final sportType = sportTypeMap[_sport];
      
      String? weekStartDateStr;
      String? monthStartDateStr;
      int? yearForRequest;

      if (period == 'week') {
        final weekToUse = weekStart ?? _currentWeekStart;
        weekStartDateStr = '${weekToUse.year}-${weekToUse.month.toString().padLeft(2, '0')}-${weekToUse.day.toString().padLeft(2, '0')}';
        if (weekStart != null) {
          _currentWeekStart = weekStart;
        }
      } else if (period == 'month') {
        final monthToUse = monthStart ?? _currentMonthStart;
        monthStartDateStr = '${monthToUse.year}-${monthToUse.month.toString().padLeft(2, '0')}-01';
        if (monthStart != null) {
          _currentMonthStart = monthStart;
        }
      } else {
        yearForRequest = year ?? _currentYear;
        if (year != null) {
          _currentYear = year;
        }
      }

      final data = await _statsService.getStats(
        userId: widget.userId,
        period: period,
        sportType: sportType,
        year: yearForRequest,
        weekStartDate: weekStartDateStr,
        monthStartDate: monthStartDateStr,
      );

      if (mounted) {
        setState(() {
          _statsData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Преобразует период в API формат
  String _getPeriodApi() {
    switch (_period) {
      case 'За неделю':
        return 'week';
      case 'За месяц':
        return 'month';
      case 'За год':
      default:
        return 'year';
    }
  }

  /// Преобразует вид спорта в API формат
  String? _getSportTypeApi() {
    switch (_sport) {
      case 0:
        return 'run'; // включает indoor-running
      case 1:
        return 'bike'; // включает indoor-cycling
      case 2:
        return 'swim';
      case 3:
        return 'ski';
      case 6:
        return 'walking';
      case 7:
        return 'hiking';
      default:
        return null;
    }
  }

  /// Форматирует число с пробелами в качестве разделителя тысяч
  /// Например: 1500 → "1 500", 12345 → "12 345"
  String _formatNumberWithSpaces(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  /// Форматирует число (double) с пробелами в качестве разделителя тысяч, без округления
  /// Показывает целую часть числа. Например: 17000.5 → "17 000", 12345.789 → "12 345"
  String _formatNumberWithSpacesFromDouble(double number) {
    final intValue = number.truncate();
    return _formatNumberWithSpaces(intValue);
  }

  /// Форматирует набор высоты в метрах без округления
  /// Принимает строку из API (может быть "1.5 км", "1500 м" или число)
  /// Возвращает отформатированную строку в метрах с пробелами после трех знаков
  String _formatElevationGain(String? elevationGain) {
    if (elevationGain == null ||
        elevationGain.isEmpty ||
        elevationGain == '—') {
      return '—';
    }

    try {
      // Убираем пробелы и приводим к нижнему регистру
      final cleaned = elevationGain.trim().toLowerCase();

      // Если содержит "км", парсим и конвертируем в метры без округления
      if (cleaned.contains('км')) {
        final numberStr = cleaned.replaceAll('км', '').trim();
        final number = double.tryParse(numberStr);
        if (number != null) {
          final meters = number * 1000;
          return '${_formatNumberWithSpacesFromDouble(meters)} м';
        }
      }

      // Если содержит "м", парсим число и оставляем в метрах без округления
      if (cleaned.contains('м')) {
        final numberStr = cleaned.replaceAll('м', '').trim();
        final number = double.tryParse(numberStr);
        if (number != null) {
          return '${_formatNumberWithSpacesFromDouble(number)} м';
        }
      }

      // Если просто число, считаем что это метры, показываем без округления
      final number = double.tryParse(cleaned);
      if (number != null) {
        return '${_formatNumberWithSpacesFromDouble(number)} м';
      }

      // Если не удалось распарсить, возвращаем как есть
      return elevationGain;
    } catch (e) {
      // В случае ошибки возвращаем исходное значение
      return elevationGain;
    }
  }

  /// Форматирует каденс
  /// Принимает строку из API (может быть число или "—")
  /// Возвращает отформатированную строку (значение уже скорректировано на бэкенде)
  String _formatCadence(String? cadence) {
    if (cadence == null || cadence.isEmpty || cadence == '—') {
      return '—';
    }

    try {
      // Парсим число из строки
      final number = double.tryParse(cadence);
      if (number != null) {
        // Округляем до целого (значение уже скорректировано на бэкенде)
        return number.round().toString();
      }

      // Если не удалось распарсить, возвращаем как есть
      return cadence;
    } catch (e) {
      // В случае ошибки возвращаем исходное значение
      return cadence;
    }
  }

  /// Получает метрики из загруженных данных
  List<_MetricRowData> _getMetrics() {
    if (_statsData == null) {
      return [];
    }

    final metrics = _statsData!.metrics;
    final sportType = _getSportTypeApi();

    if (sportType == 'run') {
      return [
        _MetricRowData(
          Icons.directions_run_outlined,
          'Забегов',
          metrics.activitiesCount,
        ),
        _MetricRowData(Icons.timer_outlined, 'Общее время', metrics.totalTime),
        _MetricRowData(Icons.place_outlined, 'Расстояние', metrics.distance),
        _MetricRowData(
          Icons.favorite_border,
          'Средний пульс',
          metrics.avgHeartRate ?? '—',
        ),
        _MetricRowData(
          Icons.speed_outlined,
          'Средний темп',
          metrics.avgPace ?? '—',
        ),
        _MetricRowData(
          Icons.directions_walk_outlined,
          'Средний каденс',
          _formatCadence(metrics.avgCadence),
        ),
        _MetricRowData(
          Icons.terrain_outlined,
          'Набор высоты',
          _formatElevationGain(metrics.elevationGain),
        ),
      ];
    } else if (sportType == 'bike') {
      return [
        _MetricRowData(
          Icons.directions_bike_outlined,
          'Заездов',
          metrics.activitiesCount,
        ),
        _MetricRowData(Icons.timer_outlined, 'Общее время', metrics.totalTime),
        _MetricRowData(Icons.place_outlined, 'Расстояние', metrics.distance),
        _MetricRowData(
          Icons.speed_outlined,
          'Средняя скорость',
          metrics.avgSpeed ?? '—',
        ),
        _MetricRowData(
          Icons.terrain_outlined,
          'Набор высоты',
          _formatElevationGain(metrics.elevationGain),
        ),
      ];
    } else if (sportType == 'swim') {
      return [
        _MetricRowData(
          Icons.pool_outlined,
          'Заплывов',
          metrics.activitiesCount,
        ),
        _MetricRowData(Icons.timer_outlined, 'Общее время', metrics.totalTime),
        _MetricRowData(Icons.place_outlined, 'Расстояние', metrics.distance),
        _MetricRowData(
          Icons.speed_outlined,
          'Средний темп',
          metrics.avgPace ?? '—',
        ),
      ];
    } else if (sportType == 'ski') {
      return [
        _MetricRowData(
          Icons.downhill_skiing,
          'Заездов на лыжах',
          metrics.activitiesCount,
        ),
        _MetricRowData(Icons.timer_outlined, 'Общее время', metrics.totalTime),
        _MetricRowData(Icons.place_outlined, 'Расстояние', metrics.distance),
        _MetricRowData(
          Icons.favorite_border,
          'Средний пульс',
          metrics.avgHeartRate ?? '—',
        ),
        _MetricRowData(
          Icons.speed_outlined,
          'Средняя скорость',
          metrics.avgSpeed ?? '—',
        ),
        _MetricRowData(
          Icons.terrain_outlined,
          'Набор высоты',
          _formatElevationGain(metrics.elevationGain),
        ),
      ];
    } else if (sportType == 'walking' || sportType == 'hiking') {
      // walking и hiking используют ту же логику, что и run
      return [
        _MetricRowData(
          Icons.directions_walk_outlined,
          sportType == 'walking' ? 'Прогулок' : 'Походов',
          metrics.activitiesCount,
        ),
        _MetricRowData(Icons.timer_outlined, 'Общее время', metrics.totalTime),
        _MetricRowData(Icons.place_outlined, 'Расстояние', metrics.distance),
        _MetricRowData(
          Icons.favorite_border,
          'Средний пульс',
          metrics.avgHeartRate ?? '—',
        ),
        _MetricRowData(
          Icons.speed_outlined,
          'Средний темп',
          metrics.avgPace ?? '—',
        ),
        _MetricRowData(
          Icons.directions_walk_outlined,
          'Средний каденс',
          _formatCadence(metrics.avgCadence),
        ),
        _MetricRowData(
          Icons.terrain_outlined,
          'Набор высоты',
          _formatElevationGain(metrics.elevationGain),
        ),
      ];
    }

    return [];
  }

  /// Получает данные для графика расстояния
  List<double> _getDistanceChart() {
    if (_statsData == null) {
      return List.filled(12, 0.0);
    }
    return _statsData!.charts.distance.map((e) => e.toDouble()).toList();
  }

  /// Получает данные для графика дней активности
  List<double> _getActiveDaysChart() {
    if (_statsData == null) {
      return List.filled(12, 0.0);
    }
    return _statsData!.charts.activeDays.map((e) => e.toDouble()).toList();
  }

  /// Получает данные для графика времени активности
  List<double> _getActiveTimeChart() {
    if (_statsData == null) {
      return List.filled(12, 0.0);
    }
    return _statsData!.charts.activeTime.map((e) => e.toDouble()).toList();
  }

  /// Вычисляет minY, maxY и tick для графика расстояния
  /// Возвращает (minY, maxY, tick)
  (double, double, double) _getDistanceRange() {
    final values = _getDistanceChart();
    if (values.isEmpty || values.every((v) => v <= 0)) {
      return (0.0, 100.0, 20.0);
    }

    final min = values.where((v) => v > 0).reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    // Добавляем отступ ~5% сверху и снизу
    final range = max - min;
    final padding = range * 0.05;
    final rawMinY = (min - padding).clamp(0.0, double.infinity);
    final rawMaxY = max + padding;

    // Округляем minY вниз, maxY вверх до разумных значений
    final minY = rawMinY <= 0 ? 0.0 : ((rawMinY / 10).floor() * 10).toDouble();
    final maxY = ((rawMaxY / 10).ceil() * 10).toDouble();

    // Вычисляем tick для 5-7 линий
    final rangeY = maxY - minY;
    final targetLines = 6;
    final rawTick = rangeY / targetLines;

    // Округляем tick до разумного значения
    double tick;
    if (rawTick <= 5) {
      tick = 5;
    } else if (rawTick <= 10) {
      tick = 10;
    } else if (rawTick <= 20) {
      tick = 20;
    } else if (rawTick <= 50) {
      tick = 50;
    } else if (rawTick <= 100) {
      tick = 100;
    } else {
      tick = ((rawTick / 50).ceil() * 50).toDouble();
    }

    return (minY, maxY, tick);
  }

  /// Вычисляет minY, maxY и tick для графика дней активности
  /// Для периодов "За неделю" и "За месяц": бинарная шкала 0-1
  /// Для периода "За год": диапазон 0-31 (максимальное количество дней в месяце)
  (double, double, double) _getActiveDaysRange(List<double> values) {
    // Для периодов "За неделю" и "За месяц" используем бинарную шкалу 0-1
    if (_period == 'За неделю' || _period == 'За месяц') {
      const minY = 0.0;
      const maxY = 1.0;
      const tick = 0.5; // Для отображения линий на 0, 0.5, 1.0
      return (minY, maxY, tick);
    }
    
    // Для года: диапазон 0-31
    const minY = 0.0;
    const maxY = 31.0;
    
    // Вычисляем tick для 6-7 линий на диапазоне 0-31
    const rangeY = maxY - minY; // 31
    const targetLines = 6;
    final rawTick = rangeY / targetLines; // ~5.17

    // Округляем tick до разумного значения
    double tick;
    if (rawTick <= 5) {
      tick = 5; // Для диапазона 0-31: 0, 5, 10, 15, 20, 25, 30
    } else {
      tick = ((rawTick / 5).ceil() * 5).toDouble();
    }

    return (minY, maxY, tick);
  }

  /// Вычисляет minY, maxY и tick для графика времени активности
  (double, double, double) _getActiveTimeRange(List<double> values) {
    if (values.isEmpty || values.every((v) => v <= 0)) {
      return (0.0, 3000.0, 500.0);
    }

    final min = values.where((v) => v > 0).reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    // Добавляем отступ ~5% сверху и снизу
    final range = max - min;
    final padding = range * 0.05;
    final rawMinY = (min - padding).clamp(0.0, double.infinity);
    final rawMaxY = max + padding;

    // Округляем minY вниз, maxY вверх
    final minY = rawMinY <= 0 ? 0.0 : ((rawMinY / 50).floor() * 50).toDouble();
    final maxY = ((rawMaxY / 50).ceil() * 50).toDouble();

    // Вычисляем tick для 5-7 линий
    final rangeY = maxY - minY;
    final targetLines = 6;
    final rawTick = rangeY / targetLines;

    // Округляем tick до разумного значения
    double tick;
    if (rawTick <= 50) {
      tick = 50;
    } else if (rawTick <= 100) {
      tick = 100;
    } else if (rawTick <= 250) {
      tick = 250;
    } else if (rawTick <= 500) {
      tick = 500;
    } else {
      tick = ((rawTick / 500).ceil() * 500).toDouble();
    }

    return (minY, maxY, tick);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _statsData == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CupertinoActivityIndicator(radius: 10),
        ),
      );
    }

    if (_error != null && _statsData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Ошибка загрузки: $_error',
            style: TextStyle(color: AppColors.getTextSecondaryColor(context)),
          ),
        ),
      );
    }

    final metrics = _getMetrics();
    final distanceValues = _getDistanceChart();
    final activeDaysValues = _getActiveDaysChart();
    final activeTimeValues = _getActiveTimeChart();

    // Вычисляем диапазоны для графиков
    final (distanceMinY, distanceMaxY, distanceTick) = _getDistanceRange();

    // График дней активности
    final (activeDaysMinY, activeDaysMaxY, activeDaysTick) =
        _getActiveDaysRange(activeDaysValues);

    // График времени активности
    final (activeTimeMinY, activeTimeMaxY, activeTimeTick) =
        _getActiveTimeRange(activeTimeValues);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Верхняя строка: период + иконки спорта
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.getBorderColor(context),
                    width: 1.0,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _period,
                    isDense: true,
                    icon: Icon(
                      CupertinoIcons.chevron_down,
                      size: 14,
                      color: AppColors.getIconPrimaryColor(context),
                    ),
                    dropdownColor: AppColors.getSurfaceColor(context),
                    menuMaxHeight: 300,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null && newValue != _period) {
                        setState(() {
                          _period = newValue;
                          // Сбрасываем на текущую неделю/месяц при смене периода
                          if (newValue == 'За неделю') {
                            _currentWeekStart = _getCurrentWeekStart();
                          } else if (newValue == 'За месяц') {
                            _currentMonthStart = _getCurrentMonthStart();
                          }
                        });
                        _loadStats();
                      }
                    },
                    items: _periods.map((String period) {
                      return DropdownMenuItem<String>(
                        value: period,
                        child: Text(
                          period,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.getTextPrimaryColor(context),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Spacer(),
              _SportIcon(
                selected: _sport == 0,
                icon: Icons.directions_run_outlined,
                sportType: 0,
                onTap: () {
                  setState(() => _sport = 0);
                  _loadStats();
                },
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 1,
                icon: Icons.directions_bike_outlined,
                sportType: 1,
                onTap: () {
                  setState(() => _sport = 1);
                  _loadStats();
                },
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 2,
                icon: Icons.pool_outlined,
                sportType: 2,
                onTap: () {
                  setState(() => _sport = 2);
                  _loadStats();
                },
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 3,
                icon: Icons.downhill_skiing,
                sportType: 3,
                onTap: () {
                  setState(() => _sport = 3);
                  _loadStats();
                },
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 6,
                icon: Icons.directions_walk_outlined,
                sportType: 6,
                onTap: () {
                  setState(() => _sport = 6);
                  _loadStats();
                },
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 7,
                icon: Icons.terrain_outlined,
                sportType: 7,
                onTap: () {
                  setState(() => _sport = 7);
                  _loadStats();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Метрики
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CupertinoActivityIndicator(radius: 10)),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _MetricsList(metrics: metrics),
          ),
        const SizedBox(height: 20),

        // ── Заголовок графика
        const _SectionTitle('Расстояние, км'),
        const SizedBox(height: 10),

        // ── Карточка с графиком
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _PeriodChartCard(
            period: _period,
            currentYear: _currentYear,
            currentWeekStart: _currentWeekStart,
            currentMonthStart: _currentMonthStart,
            color: AppColors.brandPrimary,
            minY: distanceMinY,
            maxY: distanceMaxY,
            tick: distanceTick,
            height: 200,
            values: distanceValues,
            userId: widget.userId,
            periodApi: _getPeriodApi(),
            sportType: _getSportTypeApi(),
            onYearChanged: (year) => _loadStats(year: year),
            onWeekChanged: (weekStart) => _loadStats(weekStart: weekStart),
            onMonthChanged: (monthStart) => _loadStats(monthStart: monthStart),
            valueFormatter: (value) => '${value.toStringAsFixed(1)} км',
            periodInfo: _statsData?.periodInfo,
          ),
        ),
        const SizedBox(height: 20),

        // ── Заголовок графика "Дней активности"
        const _SectionTitle('Дней активности'),
        const SizedBox(height: 10),

        // ── Карточка с графиком "Дней активности"
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: _PeriodChartCard(
            period: _period,
            currentYear: _currentYear,
            currentWeekStart: _currentWeekStart,
            currentMonthStart: _currentMonthStart,
            color: AppColors.female,
            minY: activeDaysMinY,
            maxY: activeDaysMaxY,
            tick: activeDaysTick,
            height: 200,
            values: activeDaysValues,
            userId: widget.userId,
            periodApi: _getPeriodApi(),
            sportType: _getSportTypeApi(),
            onYearChanged: (year) => _loadStats(year: year),
            onWeekChanged: (weekStart) => _loadStats(weekStart: weekStart),
            onMonthChanged: (monthStart) => _loadStats(monthStart: monthStart),
            valueFormatter: (_period == 'За неделю' || _period == 'За месяц')
                ? (value) => value >= 0.5 ? '1' : '0'
                : (value) => value.toInt().toString(),
            periodInfo: _statsData?.periodInfo,
            isBinaryScale: _period == 'За неделю' || _period == 'За месяц',
          ),
        ),
        const SizedBox(height: 20),

        // ── Заголовок графика "Время активности"
        const _SectionTitle('Время активности, мин'),
        const SizedBox(height: 10),

        // ── Карточка с графиком "Время активности"
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: _PeriodChartCard(
            period: _period,
            currentYear: _currentYear,
            currentWeekStart: _currentWeekStart,
            currentMonthStart: _currentMonthStart,
            color: AppColors.accentMint,
            minY: activeTimeMinY,
            maxY: activeTimeMaxY,
            tick: activeTimeTick,
            height: 220,
            values: activeTimeValues,
            userId: widget.userId,
            periodApi: _getPeriodApi(),
            sportType: _getSportTypeApi(),
            onYearChanged: (year) => _loadStats(year: year),
            onWeekChanged: (weekStart) => _loadStats(weekStart: weekStart),
            onMonthChanged: (monthStart) => _loadStats(monthStart: monthStart),
            valueFormatter: (value) => '${value.toInt()} мин',
            periodInfo: _statsData?.periodInfo,
          ),
        ),
      ],
    );
  }
}

// ───── UI helpers

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}

class _SportIcon extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  final int? sportType; // 0 бег(включая indoor-running), 1 вело(включая indoor-cycling), 2 плавание, 3 лыжи, 6 walking, 7 hiking
  const _SportIcon({
    required this.selected,
    required this.icon,
    required this.onTap,
    this.sportType,
  });

  /// Получить цвет активной иконки в зависимости от типа спорта
  Color _getActiveColor() {
    if (sportType == null) return AppColors.brandPrimary;
    switch (sportType!) {
      case 1: // велосипед (включая indoor-cycling)
        return AppColors.female;
      case 2: // плавание
        return AppColors.accentTeal;
      case 3: // лыжи
        return AppColors.success;
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
              : AppColors.getIconPrimaryColor(context),
        ),
      ),
    );
  }
}

/// Карточка графика с поддержкой недели/месяца/года
class _PeriodChartCard extends StatefulWidget {
  final String period; // 'За неделю', 'За месяц', 'За год'
  final int currentYear;
  final DateTime currentWeekStart;
  final DateTime currentMonthStart;
  final List<double> values;
  final double minY;
  final double maxY;
  final double tick;
  final Color color;
  final double height;
  final int userId;
  final String periodApi; // 'week', 'month', 'year'
  final String? sportType;
  final Function(int) onYearChanged;
  final Function(DateTime) onWeekChanged;
  final Function(DateTime) onMonthChanged;
  final String Function(double) valueFormatter;
  final PeriodInfo? periodInfo;
  final bool isBinaryScale; // Для бинарной шкалы 0-1

  const _PeriodChartCard({
    required this.period,
    required this.currentYear,
    required this.currentWeekStart,
    required this.currentMonthStart,
    required this.values,
    required this.minY,
    required this.maxY,
    required this.tick,
    required this.color,
    required this.height,
    required this.userId,
    required this.periodApi,
    required this.sportType,
    required this.onYearChanged,
    required this.onWeekChanged,
    required this.onMonthChanged,
    required this.valueFormatter,
    this.periodInfo,
    this.isBinaryScale = false,
  });

  @override
  State<_PeriodChartCard> createState() => _PeriodChartCardState();
}

class _PeriodChartCardState extends State<_PeriodChartCard> {
  late int _year = widget.currentYear;
  late DateTime _weekStart = widget.currentWeekStart;
  late DateTime _monthStart = widget.currentMonthStart;
  bool _isLoading = false;

  @override
  void didUpdateWidget(_PeriodChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentYear != widget.currentYear) {
      _year = widget.currentYear;
    }
    if (oldWidget.currentWeekStart != widget.currentWeekStart) {
      _weekStart = widget.currentWeekStart;
    }
    if (oldWidget.currentMonthStart != widget.currentMonthStart) {
      _monthStart = widget.currentMonthStart;
    }
  }

  void _changePeriod(int delta) {
    setState(() {
      _isLoading = true;
    });

    if (widget.period == 'За неделю') {
      final newWeekStart = DateTime(
        _weekStart.year,
        _weekStart.month,
        _weekStart.day + (delta * 7),
      );
      _weekStart = newWeekStart;
      widget.onWeekChanged(newWeekStart);
    } else if (widget.period == 'За месяц') {
      final newMonthStart = DateTime(
        _monthStart.year,
        _monthStart.month + delta,
        1,
      );
      _monthStart = newMonthStart;
      widget.onMonthChanged(newMonthStart);
    } else {
      // За год
      final newYear = _year + delta;
      if (newYear >= 2020 && newYear <= DateTime.now().year + 1) {
        _year = newYear;
        widget.onYearChanged(newYear);
      } else {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    // Сброс индикатора загрузки произойдет при обновлении данных
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  String _getPeriodLabel() {
    if (widget.period == 'За неделю') {
      final weekEnd = DateTime(
        _weekStart.year,
        _weekStart.month,
        _weekStart.day + 6,
      );
      return '${_weekStart.day.toString().padLeft(2, '0')}.${_weekStart.month.toString().padLeft(2, '0')} - ${weekEnd.day.toString().padLeft(2, '0')}.${weekEnd.month.toString().padLeft(2, '0')}';
    } else if (widget.period == 'За месяц') {
      final monthNames = [
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
      return '${monthNames[_monthStart.month - 1]} ${_monthStart.year}';
    } else {
      return '$_year';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        children: [
          Row(
            children: [
              _NavIcon(
                CupertinoIcons.left_chevron,
                onTap: () => _changePeriod(-1),
              ),
              Expanded(
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CupertinoActivityIndicator(radius: 10),
                          ),
                        ),
                      )
                    : Text(
                        _getPeriodLabel(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
              ),
              _NavIcon(
                CupertinoIcons.right_chevron,
                onTap: () => _changePeriod(1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _BarsChart(
            values: widget.values,
            minY: widget.minY,
            maxY: widget.maxY,
            tick: widget.tick,
            barColor: widget.color,
            height: widget.height,
            borderColor: AppColors.getBorderColor(context),
            textSecondaryColor: AppColors.getTextSecondaryColor(context),
            valueFormatter: widget.valueFormatter,
            period: widget.period,
            weekStart: widget.period == 'За неделю' ? _weekStart : null,
            monthStart: widget.period == 'За месяц' ? _monthStart : null,
            isBinaryScale: widget.isBinaryScale,
          ),
        ],
      ),
    );
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

/// Список метрик
class _MetricsList extends StatelessWidget {
  final List<_MetricRowData> metrics;
  const _MetricsList({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 1.0,
        ),
      ),
      child: metrics.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: List.generate(metrics.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Divider(
              height: 1,
              thickness: 0.5,
              indent: 38,
              endIndent: 11,
              color: AppColors.getDividerColor(context),
            );
          }
          final r = metrics[i ~/ 2];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(r.icon, size: 16, color: AppColors.brandPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.value,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    if (r.title == 'Средний пульс') ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.favorite_outlined,
                        size: 11,
                        color: AppColors.error,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }),
            ),
    );
  }
}

class _MetricRowData {
  final IconData icon;
  final String title;
  final String value;
  const _MetricRowData(this.icon, this.title, this.value);
}

// ———— График (12 месяцев) — линия с точками, подписи под точками

class _BarsChart extends StatefulWidget {
  final List<double> values;
  final double minY;
  final double maxY;
  final double tick;
  final Color barColor;
  final double height;
  final Color borderColor;
  final Color textSecondaryColor;
  final String Function(double) valueFormatter;
  final String period; // 'За неделю', 'За месяц', 'За год'
  final DateTime? weekStart; // Для недели
  final DateTime? monthStart; // Для месяца
  final bool isBinaryScale; // Для бинарной шкалы 0-1

  const _BarsChart({
    required this.values,
    required this.minY,
    required this.maxY,
    required this.tick,
    required this.barColor,
    this.height = 170,
    required this.borderColor,
    required this.textSecondaryColor,
    required this.valueFormatter,
    required this.period,
    this.weekStart,
    this.monthStart,
    this.isBinaryScale = false,
  });

  @override
  State<_BarsChart> createState() => _BarsChartState();
}

class _BarsChartState extends State<_BarsChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: GestureDetector(
            onTapDown: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(details.globalPosition);
              final painter = _BarsPainter(
                values: widget.values,
                minY: widget.minY,
                maxY: widget.maxY,
                tick: widget.tick,
                barColor: widget.barColor,
                borderColor: widget.borderColor,
                textSecondaryColor: widget.textSecondaryColor,
                selectedIndex: _selectedIndex,
                valueFormatter: widget.valueFormatter,
                isBinaryScale: widget.isBinaryScale,
              );
              final tappedIndex = painter.getTappedIndex(
                localPosition,
                box.size,
              );
              setState(() {
                // Если кликнули по той же точке, снимаем выделение
                _selectedIndex = tappedIndex == _selectedIndex
                    ? null
                    : tappedIndex;
              });
            },
            child: CustomPaint(
              painter: _BarsPainter(
                values: widget.values,
                minY: widget.minY,
                maxY: widget.maxY,
                tick: widget.tick,
                barColor: widget.barColor,
                borderColor: widget.borderColor,
                textSecondaryColor: widget.textSecondaryColor,
                selectedIndex: _selectedIndex,
                valueFormatter: widget.valueFormatter,
                isBinaryScale: widget.isBinaryScale,
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 28, right: 8), // вровень с painter
          child: widget.period == 'За неделю'
              ? _WeekLabels(
                  weekStart: widget.weekStart!,
                  fontSize: 10,
                )
              : widget.period == 'За месяц'
                  ? _MonthDayLabels(
                      monthStart: widget.monthStart!,
                      fontSize: 10,
                      valuesCount: widget.values.length,
                    )
                  : const _MonthLabels(fontSize: 10),
        ),
      ],
    );
  }
}

class _MonthLabels extends StatelessWidget {
  final double fontSize;
  const _MonthLabels({this.fontSize = 10});

  static const _months = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(12, (i) {
        return Expanded(
          child: Center(
            child: Text(
              _months[i],
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: fontSize,
                color: AppColors.getTextSecondaryColor(context),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Подписи для дней недели
class _WeekLabels extends StatelessWidget {
  final DateTime weekStart;
  final double fontSize;
  const _WeekLabels({required this.weekStart, this.fontSize = 10});

  static const _dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final day = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + i,
        );
        return Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _dayNames[i],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: fontSize,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: fontSize - 1,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Подписи для дней месяца
class _MonthDayLabels extends StatelessWidget {
  final DateTime monthStart;
  final double fontSize;
  final int valuesCount;
  const _MonthDayLabels({
    required this.monthStart,
    this.fontSize = 10,
    required this.valuesCount,
  });

  @override
  Widget build(BuildContext context) {
    // Показываем подписи только для некоторых дней, чтобы не перегружать график
    // Показываем каждые N дней в зависимости от количества дней в месяце
    final step = valuesCount > 15 ? (valuesCount / 8).ceil() : 1;
    
    return Row(
      children: List.generate(valuesCount, (i) {
        final day = DateTime(
          monthStart.year,
          monthStart.month,
          monthStart.day + i,
        );
        final shouldShow = i % step == 0 || i == valuesCount - 1;
        
        return Expanded(
          child: Center(
            child: shouldShow
                ? Text(
                    '${day.day}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: fontSize,
                      color: AppColors.getTextSecondaryColor(context),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final double minY;
  final double maxY;
  final double tick;
  final Color barColor;
  final Color borderColor;
  final Color textSecondaryColor;
  final int? selectedIndex;
  final String Function(double) valueFormatter;
  final bool isBinaryScale; // Для бинарной шкалы 0-1

  _BarsPainter({
    required this.values,
    required this.minY,
    required this.maxY,
    required this.tick,
    required this.barColor,
    required this.borderColor,
    required this.textSecondaryColor,
    this.selectedIndex,
    required this.valueFormatter,
    this.isBinaryScale = false,
  });

  static const double leftPad = 28;
  static const double rightPad = 8;
  static const double topPad = 8;
  static const double bottomPad = 12;

  /// Определяет, какая точка была нажата по координатам
  int? getTappedIndex(Offset localPosition, Size size) {
    if (values.isEmpty) return null;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    final rangeY = maxY - minY;
    final n = values.length;
    final groupW = chartW / n;

    for (int i = 0; i < n; i++) {
      final v = values[i].clamp(minY, maxY);
      final cx = leftPad + i * groupW + groupW / 2;
      final frac = rangeY > 0 ? ((v - minY) / rangeY).clamp(0.0, 1.0) : 0.0;
      final cy = size.height - bottomPad - frac * chartH;

      final pointRadius = selectedIndex == i ? 6.0 : 4.0;
      final distanceToPoint = (localPosition - Offset(cx, cy)).distance;

      // Увеличиваем область клика для удобства
      if (distanceToPoint <= pointRadius + 10) {
        return i;
      }
    }

    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 0.7;

    // сетка и подписи по Y
    final rangeY = maxY - minY;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    // Начинаем с minY, округленного вниз до ближайшего кратного tick
    final startY = (minY / tick).floor() * tick;
    for (double y = startY; y <= maxY + 0.0001; y += tick) {
      // Вычисляем позицию относительно диапазона
      final frac = rangeY > 0 ? ((y - minY) / rangeY).clamp(0.0, 1.0) : 0.0;
      final yy = size.height - bottomPad - frac * chartH;
      canvas.drawLine(
        Offset(leftPad, yy),
        Offset(size.width - rightPad, yy),
        gridPaint,
      );

      // Форматируем значение для оси Y
      String yLabel;
      if (isBinaryScale) {
        // Для бинарной шкалы показываем 0, 0.5, 1
        if (y == 0.0) {
          yLabel = '0';
        } else if (y == 0.5) {
          yLabel = '0.5';
        } else if (y == 1.0) {
          yLabel = '1';
        } else {
          yLabel = y.toStringAsFixed(1);
        }
      } else {
        yLabel = y.toInt().toString();
      }

      tp.text = TextSpan(
        text: yLabel,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          color: textSecondaryColor,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(leftPad - 6 - tp.width, yy - tp.height / 2));
    }

    // ── Линия с точками вместо столбцов ──
    final n = values.length;
    final groupW = chartW / n;

    // Подготовка кистей для линии, заливки и точек
    final linePaint = Paint()
      ..color = barColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = barColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    // Создаем путь для линии и заливки
    final path = Path();
    final fillPath = Path();

    // Вычисляем координаты точек
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final v = values[i].clamp(minY, maxY);
      final cx = leftPad + i * groupW + groupW / 2;
      final frac = rangeY > 0 ? ((v - minY) / rangeY).clamp(0.0, 1.0) : 0.0;
      final cy = size.height - bottomPad - frac * chartH;
      points.add(Offset(cx, cy));

      if (i == 0) {
        path.moveTo(cx, cy);
        fillPath.moveTo(cx, size.height - bottomPad);
        fillPath.lineTo(cx, cy);
      } else {
        path.lineTo(cx, cy);
        fillPath.lineTo(cx, cy);
      }
    }

    // Замыкаем путь заливки
    if (n > 0) {
      final lastCx = leftPad + (n - 1) * groupW + groupW / 2;
      fillPath.lineTo(lastCx, size.height - bottomPad);
      fillPath.close();
    }

    // Рисуем заливку под линией
    canvas.drawPath(fillPath, fillPaint);

    // Рисуем линию
    canvas.drawPath(path, linePaint);

    // Рисуем точки и выделяем выбранную
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final isSelected = selectedIndex == i;
      final pointRadius = isSelected ? 6.0 : 4.0;

      // Если точка выбрана, рисуем вертикальную линию до оси X
      if (isSelected) {
        final verticalLinePaint = Paint()
          ..color = barColor
          ..strokeWidth = 1.0;
        canvas.drawLine(
          point,
          Offset(point.dx, size.height - bottomPad),
          verticalLinePaint,
        );

        // Рисуем метку со значением над точкой
        final value = values[i];
        tp.text = TextSpan(
          text: valueFormatter(value),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: barColor,
          ),
        );
        tp.layout();
        tp.paint(
          canvas,
          Offset(point.dx - tp.width / 2, point.dy - tp.height - 8),
        );
      }

      // Рисуем точку
      canvas.drawCircle(point, pointRadius, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.values != values ||
      old.minY != minY ||
      old.maxY != maxY ||
      old.tick != tick ||
      old.barColor != barColor ||
      old.borderColor != borderColor ||
      old.textSecondaryColor != textSecondaryColor ||
      old.selectedIndex != selectedIndex;
}
