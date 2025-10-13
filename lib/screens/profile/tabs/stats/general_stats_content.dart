import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Возвращает список сливеров для вкладки «Общая»
List<Widget> buildGeneralStatsSlivers() {
  return [
    const SliverToBoxAdapter(child: _SectionTitle('Дней активности')),
    const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: _YearChartCard(
          initialYear: 2024,
          color: Color(0xFF3DA8FF),
          // ⬇️ вернули прежние "вертикальные поля" графика: шкала 0..30 с шагом 5
          maxY: 30,
          tick: 5,
          height: 170,
          values: [6, 10, 14, 19, 22, 28, 30, 25, 24, 22, 18, 12],
        ),
      ),
    ),

    const SliverToBoxAdapter(child: SizedBox(height: 16)),

    const SliverToBoxAdapter(child: _SectionTitle('Время активности, мин')),
    const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: _YearChartCard(
          initialYear: 2024,
          color: Color(0xFFE85D9C),
          maxY: 3000,
          tick: 500,
          height: 190,
          values: [
            1500,
            1450,
            1400,
            2200,
            2900,
            2400,
            1700,
            2500,
            3000,
            2700,
            2500,
            1700,
          ],
        ),
      ),
    ),
  ];
}

// ===== UI маленькие штуки

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// Карточка графика с переключением года внутри
class _YearChartCard extends StatefulWidget {
  final int initialYear;
  final List<double> values; // 12 значений
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAEAEA), width: 0.7),
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
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: AppColors.text),
      ),
    );
  }
}

// ── Столбчатый график (12 месяцев), без зависимостей

class _BarsChart extends StatelessWidget {
  final List<double> values; // 12
  final double maxY;
  final double tick;
  final Color barColor;
  final double height;

  const _BarsChart({
    required this.values,
    required this.maxY,
    required this.tick,
    required this.barColor,
    this.height = 170,
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
            ),
          ),
        ),

        const Padding(
          padding: EdgeInsets.only(
            left: 28,
            right: 8,
          ), // синхронизировано с painter
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
                color: AppColors.greytext,
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

  _BarsPainter({
    required this.values,
    required this.maxY,
    required this.tick,
    required this.barColor,
  });

  // поля графика (как было раньше)
  static const double leftPad = 28;
  static const double rightPad = 8;
  static const double topPad = 8;
  static const double bottomPad = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = const Color(0xFFEAEAEA)
      ..strokeWidth = 0.7;

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
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          color: AppColors.greytext,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(leftPad - 6 - tp.width, yy - tp.height / 2));
    }

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

      // низ ровный, верх мягко скруглён
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
      old.barColor != barColor;
}
