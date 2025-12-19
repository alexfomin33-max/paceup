import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../providers/services/api_provider.dart';

/// Модель данных недели
class WeekData {
  final String weekStart;
  final String weekEnd;
  final String weekLabel;
  final double totalDistance;
  final int weekNumber;

  WeekData({
    required this.weekStart,
    required this.weekEnd,
    required this.weekLabel,
    required this.totalDistance,
    required this.weekNumber,
  });

  factory WeekData.fromJson(Map<String, dynamic> json) {
    return WeekData(
      weekStart: json['weekStart'] as String,
      weekEnd: json['weekEnd'] as String,
      weekLabel: json['weekLabel'] as String,
      totalDistance: (json['totalDistance'] as num).toDouble(),
      weekNumber: json['weekNumber'] as int,
    );
  }
}

/// Модель данных вида спорта за неделю
class WeekSportData {
  final String type;
  final String typeLabel;
  final double distance;
  final String distanceText;
  final int time;
  final String timeText;
  final int? elevation;
  final String? elevationText;

  WeekSportData({
    required this.type,
    required this.typeLabel,
    required this.distance,
    required this.distanceText,
    required this.time,
    required this.timeText,
    this.elevation,
    this.elevationText,
  });

  factory WeekSportData.fromJson(Map<String, dynamic> json) {
    return WeekSportData(
      type: json['type'] as String,
      typeLabel: json['typeLabel'] as String,
      distance: (json['distance'] as num).toDouble(),
      distanceText: json['distanceText'] as String,
      time: json['time'] as int,
      timeText: json['timeText'] as String,
      elevation: json['elevation'] as int?,
      elevationText: json['elevationText'] as String?,
    );
  }
}

/// Виджет графика недельной активности
class WeeklyActivityChart extends ConsumerStatefulWidget {
  final int userId;

  const WeeklyActivityChart({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<WeeklyActivityChart> createState() => _WeeklyActivityChartState();
}

class _WeeklyActivityChartState extends ConsumerState<WeeklyActivityChart> {
  List<WeekData> _weeks = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedWeekIndex;
  List<WeekSportData>? _selectedWeekSports;
  String? _selectedWeekLabel;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(WeeklyActivityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Перезагружаем данные, если userId изменился (например, открыли другой профиль)
    if (oldWidget.userId != widget.userId) {
      setState(() {
        _selectedWeekIndex = null;
        _selectedWeekSports = null;
        _selectedWeekLabel = null;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/get_weekly_activity_stats.php',
        body: {'userId': widget.userId.toString()},
      );

      if (response['success'] == true) {
        final weeksJson = response['weeks'] as List<dynamic>;
        setState(() {
          _weeks = weeksJson.map((w) => WeekData.fromJson(w as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message']?.toString() ?? 'Ошибка загрузки данных';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWeekDetails(int weekIndex) async {
    if (weekIndex < 0 || weekIndex >= _weeks.length) return;

    final week = _weeks[weekIndex];
    
    // Если уже выбрана эта неделя, снимаем выделение
    if (_selectedWeekIndex == weekIndex) {
      setState(() {
        _selectedWeekIndex = null;
        _selectedWeekSports = null;
        _selectedWeekLabel = null;
      });
      return;
    }

    setState(() {
      _selectedWeekIndex = weekIndex;
      _selectedWeekLabel = week.weekLabel;
    });

    // Загружаем детали недели
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/get_week_activity_details.php',
        body: {
          'userId': widget.userId.toString(),
          'weekStart': week.weekStart,
        },
      );

      if (response['success'] == true && mounted) {
        final sportsJson = response['sports'] as List<dynamic>;
        final sports = sportsJson
            .map((s) => WeekSportData.fromJson(s as Map<String, dynamic>))
            .toList();

        setState(() {
          _selectedWeekSports = sports;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedWeekIndex = null;
          _selectedWeekSports = null;
          _selectedWeekLabel = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _error!,
          style: TextStyle(
            color: AppColors.getTextSecondaryColor(context),
            fontFamily: 'Inter',
            fontSize: 14,
          ),
        ),
      );
    }

    if (_weeks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Нет данных для отображения',
          style: TextStyle(
            color: AppColors.getTextSecondaryColor(context),
            fontFamily: 'Inter',
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // График
        SizedBox(
          height: 200,
          child: _ActivityLineChart(
            weeks: _weeks,
            selectedWeekIndex: _selectedWeekIndex,
            onPointTap: _loadWeekDetails,
            textSecondaryColor: AppColors.getTextSecondaryColor(context),
            borderColor: AppColors.getBorderColor(context),
          ),
        ),
        
        // Детали выбранной недели
        if (_selectedWeekIndex != null && _selectedWeekSports != null && _selectedWeekLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: WeekActivityDetails(
              weekLabel: _selectedWeekLabel!,
              sports: _selectedWeekSports!,
            ),
          ),
      ],
    );
  }
}

/// Виджет линейного графика активности
class _ActivityLineChart extends StatelessWidget {
  final List<WeekData> weeks;
  final int? selectedWeekIndex;
  final Function(int) onPointTap;
  final Color textSecondaryColor;
  final Color borderColor;

  const _ActivityLineChart({
    required this.weeks,
    this.selectedWeekIndex,
    required this.onPointTap,
    required this.textSecondaryColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    if (weeks.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _LineChartPainter(
        weeks: weeks,
        selectedWeekIndex: selectedWeekIndex,
        onPointTap: onPointTap,
        textSecondaryColor: textSecondaryColor,
        borderColor: borderColor,
      ),
      child: GestureDetector(
        onTapDown: (details) {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final painter = _LineChartPainter(
            weeks: weeks,
            selectedWeekIndex: selectedWeekIndex,
            onPointTap: onPointTap,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
          );
          final tappedIndex = painter.getTappedIndex(localPosition, box.size);
          if (tappedIndex != null) {
            onPointTap(tappedIndex);
          }
        },
      ),
    );
  }
}

/// Painter для линейного графика
class _LineChartPainter extends CustomPainter {
  final List<WeekData> weeks;
  final int? selectedWeekIndex;
  final Function(int) onPointTap;
  final Color textSecondaryColor;
  final Color borderColor;

  _LineChartPainter({
    required this.weeks,
    this.selectedWeekIndex,
    required this.onPointTap,
    required this.textSecondaryColor,
    required this.borderColor,
  });

  int? getTappedIndex(Offset localPosition, Size size) {
    if (weeks.isEmpty) return null;

    final leftPad = 40.0;
    final rightPad = 20.0;
    final topPad = 30.0;
    final bottomPad = 40.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    final maxDistance = weeks.map((w) => w.totalDistance).reduce((a, b) => a > b ? a : b);
    final maxY = maxDistance > 0 ? ((maxDistance / 40).ceil() * 40.0) : 80.0;

    final n = weeks.length;
    final groupW = chartW / n;

    for (int i = 0; i < n; i++) {
      final cx = leftPad + i * groupW + groupW / 2;
      final distance = weeks[i].totalDistance;
      final frac = (distance / maxY).clamp(0.0, 1.0);
      final cy = size.height - bottomPad - frac * chartH;

      final pointRadius = selectedWeekIndex == i ? 8.0 : 5.0;
      final distanceToPoint = (localPosition - Offset(cx, cy)).distance;

      if (distanceToPoint <= pointRadius + 10) {
        return i;
      }
    }

    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty) return;

    final leftPad = 40.0;
    final rightPad = 20.0;
    final topPad = 30.0;
    final bottomPad = 40.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    // Вычисляем максимальное значение для оси Y
    final maxDistance = weeks.map((w) => w.totalDistance).reduce((a, b) => a > b ? a : b);
    final maxY = maxDistance > 0 ? ((maxDistance / 40).ceil() * 40.0) : 80.0;
    final tick = maxY / 2; // Делим на 2 интервала (0, 40, 80)

    // Цвета
    const lineColor = Color(0xFFFF9500); // Оранжевый
    final gridPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 0.5;

    // Рисуем сетку и подписи по Y
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (double y = 0; y <= maxY + 0.0001; y += tick) {
      final frac = (y / maxY).clamp(0.0, 1.0);
      final yy = size.height - bottomPad - frac * chartH;
      
      // Горизонтальная линия сетки
      canvas.drawLine(
        Offset(leftPad, yy),
        Offset(size.width - rightPad, yy),
        gridPaint,
      );

      // Подпись значения
      tp.text = TextSpan(
        text: y.toInt().toString() + ' км',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          color: textSecondaryColor,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(leftPad - 6 - tp.width, yy - tp.height / 2));
    }

    // Рисуем линию графика и точки
    final n = weeks.length;
    final groupW = chartW / n;
    
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = lineColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final selectedPointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    // Создаем путь для линии и заливки
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < n; i++) {
      final cx = leftPad + i * groupW + groupW / 2;
      final distance = weeks[i].totalDistance;
      final frac = (distance / maxY).clamp(0.0, 1.0);
      final cy = size.height - bottomPad - frac * chartH;

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

    // Рисуем заливку
    canvas.drawPath(fillPath, fillPaint);

    // Рисуем линию
    canvas.drawPath(path, linePaint);

    // Рисуем точки
    for (int i = 0; i < n; i++) {
      final cx = leftPad + i * groupW + groupW / 2;
      final distance = weeks[i].totalDistance;
      final frac = (distance / maxY).clamp(0.0, 1.0);
      final cy = size.height - bottomPad - frac * chartH;

      final isSelected = selectedWeekIndex == i;
      final pointRadius = isSelected ? 8.0 : 5.0;
      final paint = isSelected ? selectedPointPaint : pointPaint;

      // Рисуем точку
      canvas.drawCircle(Offset(cx, cy), pointRadius, paint);

      // Если точка выбрана, рисуем вертикальную линию и метку
      if (isSelected) {
        // Вертикальная линия до оси X
        final verticalLinePaint = Paint()
          ..color = lineColor
          ..strokeWidth = 1.0;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx, size.height - bottomPad),
          verticalLinePaint,
        );

        // Метка над точкой
        tp.text = TextSpan(
          text: distance.toStringAsFixed(0) + ' км',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: lineColor,
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height - 6));
      }
    }

    // Подписи по оси X (месяцы)
    // Группируем недели по месяцам для подписей
    final monthLabels = <String, int>{};
    for (int i = 0; i < n; i++) {
      final weekStart = DateTime.parse(weeks[i].weekStart);
      final monthKey = '${weekStart.year}-${weekStart.month}';
      if (!monthLabels.containsKey(monthKey)) {
        monthLabels[monthKey] = i;
      }
    }

    final monthNames = [
      'ЯНВ.',
      'ФЕВ.',
      'МАР.',
      'АПР.',
      'МАЙ',
      'ИЮН.',
      'ИЮЛ.',
      'АВГ.',
      'СЕН.',
      'ОКТ.',
      'НОЯБ.',
      'ДЕК.'
    ];

    for (final entry in monthLabels.entries) {
      final i = entry.value;
      final weekStart = DateTime.parse(weeks[i].weekStart);
      final monthName = monthNames[weekStart.month - 1];
      final cx = leftPad + i * groupW + groupW / 2;

      tp.text = TextSpan(
        text: monthName,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          color: textSecondaryColor,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - bottomPad + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.weeks != weeks ||
        oldDelegate.selectedWeekIndex != selectedWeekIndex;
  }
}

/// Виджет деталей активности за неделю
class WeekActivityDetails extends StatelessWidget {
  final String weekLabel;
  final List<WeekSportData> sports;

  const WeekActivityDetails({
    super.key,
    required this.weekLabel,
    required this.sports,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок недели
          Text(
            'Неделя $weekLabel',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 16),
          
          // Список видов спорта
          if (sports.isEmpty)
            Text(
              'Нет активностей за эту неделю',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.getTextSecondaryColor(context),
              ),
            )
          else
            ...sports.map((sport) => _SportRow(sport: sport)),
        ],
      ),
    );
  }
}

/// Строка вида спорта
class _SportRow extends StatelessWidget {
  final WeekSportData sport;

  const _SportRow({required this.sport});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Название вида спорта
          Text(
            sport.typeLabel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          
          // Метрики
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _MetricItem(
                  label: 'Дистанция',
                  value: sport.distanceText,
                ),
              ),
              Expanded(
                child: _MetricItem(
                  label: 'Время',
                  value: sport.timeText,
                ),
              ),
              Expanded(
                child: sport.elevationText != null
                    ? _MetricItem(
                        label: 'Высота',
                        value: sport.elevationText!,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Элемент метрики
class _MetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetricItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ],
    );
  }
}
