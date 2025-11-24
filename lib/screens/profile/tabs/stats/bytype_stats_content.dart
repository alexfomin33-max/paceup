import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Вкладка «По видам» — интерактивная:
/// • Выпадающий период (неделя/месяц/3м/6м/год)
/// • Переключение вида спорта (бег/вело/плавание)
List<Widget> buildByTypeStatsSlivers() {
  return const [
    SliverToBoxAdapter(child: _ByTypeContent()),
    SliverToBoxAdapter(child: SizedBox(height: 18)),
  ];
}

class _ByTypeContent extends StatefulWidget {
  const _ByTypeContent();
  @override
  State<_ByTypeContent> createState() => _ByTypeContentState();
}

class _ByTypeContentState extends State<_ByTypeContent> {
  // Периоды
  static const _periods = [
    'За неделю',
    'За месяц',
    'За 3 месяца',
    'За 6 месяцев',
    'За год',
  ];
  String _period = 'За год';

  // Вид спорта: 0 бег, 1 вело, 2 плавание (single-select)
  int _sport = 0;

  // Демо-данные (за год). Другие периоды считаем через scale.
  static const _run = [
    560,
    580,
    640,
    690,
    780,
    920,
    890,
    860,
    700,
    540,
    460,
    380,
  ];
  static const _bike = [
    820,
    900,
    980,
    1100,
    1200,
    1300,
    1400,
    1350,
    1200,
    1000,
    900,
    820,
  ];
  static const _swim = [
    120,
    130,
    160,
    190,
    210,
    240,
    220,
    210,
    180,
    150,
    130,
    120,
  ];

  double _scaleForPeriod(String p) {
    switch (p) {
      case 'За неделю':
        return 0.06; // ~1/16
      case 'За месяц':
        return 0.10; // ~1/10
      case 'За 3 месяца':
        return 0.28;
      case 'За 6 месяцев':
        return 0.55;
      default:
        return 1.0; // За год
    }
  }

  List<double> _valuesForSport() {
    final s = _scaleForPeriod(_period);
    final base = _sport == 0 ? _run : (_sport == 1 ? _bike : _swim);
    return base.map((v) => v * s).toList(growable: false);
  }

  List<_MetricRowData> _metricsForSport() {
    final s = _scaleForPeriod(_period);
    if (_sport == 0) {
      // Бег
      return [
        _MetricRowData(
          Icons.directions_run,
          'Забегов',
          (270 * s).toStringAsFixed(0),
        ),
        _MetricRowData(
          Icons.access_time,
          'Общее время',
          '${(301 * s).toStringAsFixed(0)} ч ${(16 * s).toStringAsFixed(0)} мин',
        ),
        _MetricRowData(
          Icons.place_outlined,
          'Расстояние',
          '${(2976 * s).toStringAsFixed(0)} км',
        ),
        const _MetricRowData(
          Icons.favorite_border,
          'Средний пульс',
          '152',
          color: AppColors.error, // красный для пульса
        ),
        const _MetricRowData(Icons.speed, 'Средний темп', '5:15 /км'),
        const _MetricRowData(
          Icons.directions_walk_outlined,
          'Средний каденс',
          '173',
        ),
        const _MetricRowData(Icons.insights, 'Относительное усилие', '50'),
        _MetricRowData(
          Icons.terrain,
          'Набор высоты',
          '${(27804 * s).toStringAsFixed(0)} м',
        ),
      ];
    } else if (_sport == 1) {
      // Вело
      return [
        _MetricRowData(
          Icons.directions_bike,
          'Заездов',
          (180 * s).toStringAsFixed(0),
        ),
        _MetricRowData(
          Icons.access_time,
          'Общее время',
          '${(420 * s).toStringAsFixed(0)} ч',
        ),
        _MetricRowData(
          Icons.place,
          'Расстояние',
          '${(6120 * s).toStringAsFixed(0)} км',
        ),
        const _MetricRowData(Icons.speed, 'Средняя скорость', '28,4 км/ч'),
        _MetricRowData(
          Icons.terrain_outlined,
          'Набор высоты',
          '${(41000 * s).toStringAsFixed(0)} м',
        ),
      ];
    } else {
      // Плавание
      return [
        _MetricRowData(Icons.pool, 'Заплывов', (120 * s).toStringAsFixed(0)),
        _MetricRowData(
          Icons.access_time,
          'Общее время',
          '${(95 * s).toStringAsFixed(0)} ч',
        ),
        _MetricRowData(
          Icons.place,
          'Расстояние',
          '${(320 * s).toStringAsFixed(0)} км',
        ),
        const _MetricRowData(Icons.speed, 'Средний темп', '1:45 /100м'),
      ];
    }
  }

  Color _barColor() => _sport == 0
      ? AppColors.male
      : _sport == 1
      ? AppColors.accentMint
      : AppColors.female;
  double _maxY() => _sport == 0
      ? 1000
      : _sport == 1
      ? 1400
      : 300;
  double _tick() => _sport == 0
      ? 100
      : _sport == 1
      ? 200
      : 50;

  @override
  Widget build(BuildContext context) {
    final values = _valuesForSport();
    final metrics = _metricsForSport();

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
                icon: Icons.directions_run,
                onTap: () => setState(() => _sport = 0),
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 1,
                icon: Icons.directions_bike,
                onTap: () => setState(() => _sport = 1),
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 2,
                icon: Icons.pool,
                onTap: () => setState(() => _sport = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Карточка с графиком
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _YearChartCard(
            initialYear: 2024,
            color: _barColor(),
            maxY: _maxY(),
            tick: _tick(),
            height: 170,
            values: values,
          ),
        ),
        const SizedBox(height: 12),

        // ── Метрики
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _MetricsList(metrics: metrics),
        ),
      ],
    );
  }
}

// ───── UI helpers

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
  final double maxY;
  final double tick;
  final Color color;
  final double height;

  const _YearChartCard({
    required this.initialYear,
    required this.values,
    required this.maxY,
    required this.tick,
    required this.color,
    required this.height,
  });

  @override
  State<_YearChartCard> createState() => _YearChartCardState();
}

class _YearChartCardState extends State<_YearChartCard> {
  late int _year = widget.initialYear;

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
                onTap: () => setState(() => _year--),
              ),
              Expanded(
                child: Text(
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
                onTap: () => setState(() => _year++),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _BarsChart(
            values: widget.values,
            maxY: widget.maxY,
            tick: widget.tick,
            barColor: widget.color,
            height: widget.height,
            borderColor: AppColors.getBorderColor(context),
            textSecondaryColor: AppColors.getTextSecondaryColor(context),
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
                Icon(
                  r.icon,
                  size: 16,
                  color: r.color ?? AppColors.brandPrimary,
                ),
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
                Text(
                  r.value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
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
  final Color? color; // для пульса — красный
  const _MetricRowData(this.icon, this.title, this.value, {this.color});
}

// ———— График (12 месяцев) — низ ровный, верх скруглён, подписи под столбцами

class _BarsChart extends StatelessWidget {
  final List<double> values; // 12
  final double maxY;
  final double tick;
  final Color barColor;
  final double height;
  final Color borderColor;
  final Color textSecondaryColor;

  const _BarsChart({
    required this.values,
    required this.maxY,
    required this.tick,
    required this.barColor,
    this.height = 170,
    required this.borderColor,
    required this.textSecondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarsPainter(
              values: values,
              maxY: maxY,
              tick: tick,
              barColor: barColor,
              borderColor: borderColor,
              textSecondaryColor: textSecondaryColor,
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
  final double maxY;
  final double tick;
  final Color barColor;
  final Color borderColor;
  final Color textSecondaryColor;

  _BarsPainter({
    required this.values,
    required this.maxY,
    required this.tick,
    required this.barColor,
    required this.borderColor,
    required this.textSecondaryColor,
  });

  static const double leftPad = 28;
  static const double rightPad = 8;
  static const double topPad = 8;
  static const double bottomPad = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 0.7;

    // сетка и подписи по Y
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (double y = 0; y <= maxY + 0.0001; y += tick) {
      final frac = (y / maxY).clamp(0.0, 1.0);
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

    // столбики
    final n = values.length;
    final groupW = chartW / n;
    final barW = groupW * 0.52;
    final barPaint = Paint()..color = barColor;

    for (int i = 0; i < n; i++) {
      final v = values[i].clamp(0, maxY);
      final h = (v / maxY) * chartH;

      final cx = leftPad + i * groupW + (groupW - barW) / 2;
      final top = size.height - bottomPad - h;
      final rect = Rect.fromLTWH(cx, top, barW, h);

      // низ ровный, верх — сильно скруглён; для маленьких колонок уменьшаем радиус
      final double topR = h <= 0 ? 0 : (h < 16 ? h / 2 : 8);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(topR),
        topRight: Radius.circular(topR),
      );
      canvas.drawRRect(rrect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.values != values ||
      old.maxY != maxY ||
      old.tick != tick ||
      old.barColor != barColor ||
      old.borderColor != borderColor ||
      old.textSecondaryColor != textSecondaryColor;
}
