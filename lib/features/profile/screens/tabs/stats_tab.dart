import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/stats_service.dart';

/// Вкладка «По видам» — интерактивная:
/// • Выпадающий период (неделя/месяц/год)
/// • Переключение вида спорта (бег/вело/плавание)
List<Widget> buildByTypeStatsSlivers(int userId) {
  return [
    SliverToBoxAdapter(child: _ByTypeContent(userId: userId)),
    const SliverToBoxAdapter(child: SizedBox(height: 18)),
  ];
}

class StatsTab extends StatefulWidget {
  final int? userId;
  const StatsTab({super.key, this.userId});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userId = widget.userId;
    if (userId == null) {
      return const Center(child: Text('Ошибка: не указан userId'));
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ...buildByTypeStatsSlivers(userId),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
      ],
    );
  }
}

class _ByTypeContent extends StatefulWidget {
  final int userId;
  const _ByTypeContent({required this.userId});
  @override
  State<_ByTypeContent> createState() => _ByTypeContentState();
}

class _ByTypeContentState extends State<_ByTypeContent> {
  final StatsService _statsService = StatsService();

  // Периоды
  static const _periods = ['За неделю', 'За месяц', 'За год'];
  String _period = 'За год';

  // Вид спорта: 0 бег, 1 вело, 2 плавание (single-select)
  int _sport = 0;

  // Состояние загрузки
  bool _isLoading = true;
  StatsData? _statsData;
  String? _error;

  // Текущий год для графиков
  int _currentYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Загружает статистику с текущими фильтрами
  Future<void> _loadStats({int? year}) async {
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

      final sportTypeMap = {0: 'run', 1: 'bike', 2: 'swim'};

      final period = periodMap[_period] ?? 'year';
      final sportType = sportTypeMap[_sport];
      final yearForRequest = year ?? _currentYear;

      final data = await _statsService.getStats(
        userId: widget.userId,
        period: period,
        sportType: sportType,
        year: yearForRequest,
      );

      if (mounted) {
        setState(() {
          _statsData = data;
          _isLoading = false;
          if (year != null) {
            _currentYear = year;
          }
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
        return 'run';
      case 1:
        return 'bike';
      case 2:
        return 'swim';
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
    if (elevationGain == null || elevationGain.isEmpty || elevationGain == '—') {
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
          metrics.avgCadence ?? '—',
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
  (double, double, double) _getActiveDaysRange(List<double> values) {
    if (values.isEmpty || values.every((v) => v <= 0)) {
      return (0.0, 30.0, 5.0);
    }

    final min = values.where((v) => v > 0).reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    // Добавляем отступ ~5% сверху и снизу
    final range = max - min;
    final padding = range * 0.05;
    final rawMinY = (min - padding).clamp(0.0, double.infinity);
    final rawMaxY = max + padding;

    // Округляем minY вниз, maxY вверх
    final minY = rawMinY <= 0 ? 0.0 : ((rawMinY / 1).floor() * 1).toDouble();
    final maxY = ((rawMaxY / 1).ceil() * 1).toDouble();

    // Вычисляем tick для 5-7 линий
    final rangeY = maxY - minY;
    final targetLines = 6;
    final rawTick = rangeY / targetLines;

    // Округляем tick до разумного значения
    double tick;
    if (rawTick <= 1) {
      tick = 1;
    } else if (rawTick <= 2) {
      tick = 2;
    } else if (rawTick <= 5) {
      tick = 5;
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
                    width: 0.7,
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
                        setState(() => _period = newValue);
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
                onTap: () {
                  setState(() => _sport = 0);
                  _loadStats();
                },
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 1,
                icon: Icons.directions_bike_outlined,
                onTap: () {
                  setState(() => _sport = 1);
                  _loadStats();
                },
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 2,
                icon: Icons.pool_outlined,
                onTap: () {
                  setState(() => _sport = 2);
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
          child: _YearChartCard(
            initialYear: _currentYear,
            color: AppColors.brandPrimary,
            minY: distanceMinY,
            maxY: distanceMaxY,
            tick: distanceTick,
            height: 200,
            values: distanceValues,
            userId: widget.userId,
            period: _getPeriodApi(),
            sportType: _getSportTypeApi(),
            onYearChanged: (year) => _loadStats(year: year),
            valueFormatter: (value) => '${value.toStringAsFixed(1)} км',
          ),
        ),
        const SizedBox(height: 20),

        // ── Заголовок графика "Дней активности"
        const _SectionTitle('Дней активности'),
        const SizedBox(height: 10),

        // ── Карточка с графиком "Дней активности"
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: _YearChartCard(
            initialYear: _currentYear,
            color: AppColors.female,
            minY: activeDaysMinY,
            maxY: activeDaysMaxY,
            tick: activeDaysTick,
            height: 200,
            values: activeDaysValues,
            userId: widget.userId,
            period: _getPeriodApi(),
            sportType: _getSportTypeApi(),
            onYearChanged: (year) => _loadStats(year: year),
            valueFormatter: (value) => value.toInt().toString(),
          ),
        ),
        const SizedBox(height: 20),

        // ── Заголовок графика "Время активности"
        const _SectionTitle('Время активности, мин'),
        const SizedBox(height: 10),

        // ── Карточка с графиком "Время активности"
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: _YearChartCard(
            initialYear: _currentYear,
            color: AppColors.accentMint,
            minY: activeTimeMinY,
            maxY: activeTimeMaxY,
            tick: activeTimeTick,
            height: 220,
            values: activeTimeValues,
            userId: widget.userId,
            period: _getPeriodApi(),
            sportType: _getSportTypeApi(),
            onYearChanged: (year) => _loadStats(year: year),
            valueFormatter: (value) => '${value.toInt()} мин',
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
              : AppColors.getIconPrimaryColor(context),
        ),
      ),
    );
  }
}

/// Карточка графика «по виду спорта» (переключение года)
class _YearChartCard extends StatefulWidget {
  final int initialYear;
  final List<double> values; // 12
  final double minY;
  final double maxY;
  final double tick;
  final Color color;
  final double height;
  final int userId;
  final String period;
  final String? sportType;
  final Function(int) onYearChanged;
  final String Function(double) valueFormatter; // Форматирование значения

  const _YearChartCard({
    required this.initialYear,
    required this.values,
    required this.minY,
    required this.maxY,
    required this.tick,
    required this.color,
    required this.height,
    required this.userId,
    required this.period,
    required this.sportType,
    required this.onYearChanged,
    required this.valueFormatter,
  });

  @override
  State<_YearChartCard> createState() => _YearChartCardState();
}

class _YearChartCardState extends State<_YearChartCard> {
  late int _year = widget.initialYear;
  bool _isLoading = false;

  @override
  void didUpdateWidget(_YearChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialYear != widget.initialYear) {
      _year = widget.initialYear;
    }
  }

  void _changeYear(int delta) {
    final newYear = _year + delta;
    // Ограничиваем год разумными пределами
    if (newYear >= 2020 && newYear <= DateTime.now().year + 1) {
      setState(() {
        _year = newYear;
        _isLoading = true;
      });
      widget.onYearChanged(newYear);
      // Сброс индикатора загрузки произойдет при обновлении данных
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        children: [
          Row(
            children: [
              _NavIcon(
                CupertinoIcons.left_chevron,
                onTap: () => _changeYear(-1),
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
                        '$_year',
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
                onTap: () => _changeYear(1),
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
      child: Column(
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
  final List<double> values; // 12
  final double minY;
  final double maxY;
  final double tick;
  final Color barColor;
  final double height;
  final Color borderColor;
  final Color textSecondaryColor;
  final String Function(double)
  valueFormatter; // Форматирование значения для отображения

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
              ),
            ),
          ),
        ),

        const Padding(
          padding: EdgeInsets.only(left: 28, right: 8), // вровень с painter
          child: _MonthLabels(fontSize: 10),
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

      tp.text = TextSpan(
        text: y.toInt().toString(),
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
