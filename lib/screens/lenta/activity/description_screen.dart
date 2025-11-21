// lib/screens/lenta/widgets/activity_description_block.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui; // для ui.Path
import 'package:latlong2/latlong.dart' as ll;

import '../../../theme/app_theme.dart';
// Берём готовые виджеты (чтобы совпадал верх с ActivityBlock)
import '../widgets/activity/header/activity_header.dart';
import '../widgets/activity/stats/stats_row.dart';
import '../widgets/activity/equipment/equipment_chip.dart'
    as ab
    show EquipmentChip;
import '../../../widgets/route_card.dart' as ab show RouteCard;
// Модель — через алиас, чтобы не конфликтовало имя Equipment
import '../../../models/activity_lenta.dart' as al;
import 'combining_screen.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/transparent_route.dart';
import '../../../widgets/interactive_back_swipe.dart';

/// Страница с подробным описанием тренировки.
/// Верхний блок (аватар, дата, метрики) полностью повторяет ActivityBlock.
/// Добавлены: плашка часов, «Отрезки» на всю ширину, сегменты «Темп/Пульс/Высота»,
/// единый блок «График + сводка темпа».
class ActivityDescriptionPage extends StatefulWidget {
  final al.Activity activity;
  final int currentUserId;

  const ActivityDescriptionPage({
    super.key,
    required this.activity,
    this.currentUserId = 0,
  });

  @override
  State<ActivityDescriptionPage> createState() =>
      _ActivityDescriptionPageState();
}

class _ActivityDescriptionPageState extends State<ActivityDescriptionPage> {
  int _chartTab = 0; // 0=Темп, 1=Пульс, 2=Высота

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final stats = a.stats;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PaceAppBar(
          title: 'Тренировка',
          showBottomDivider:
              false, // чтобы не было двойной линии со следующим блоком
          actions: [
            IconButton(
              splashRadius: 22,
              icon: const Icon(
                CupertinoIcons.personalhotspot,
                size: 20,
                color: AppColors.iconPrimary,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  TransparentPageRoute(builder: (_) => const CombiningScreen()),
                );
              },
            ),
            IconButton(
              splashRadius: 22,
              icon: const Icon(
                CupertinoIcons.ellipsis,
                size: 20,
                color: AppColors.iconPrimary,
              ),
              onPressed: () {},
            ),
          ],
        ),

        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ───────── Верхний блок (как в ActivityBlock)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(width: 0.5, color: AppColors.border),
                    bottom: BorderSide(width: 0.5, color: AppColors.border),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Шапка: аватар, имя, дата, метрики (как в ActivityBlock)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ActivityHeader(
                        userId: widget.currentUserId,
                        userName: a.userName.isNotEmpty ? a.userName : 'Аноним',
                        userAvatar: a.userAvatar,
                        dateStart: a.dateStart,
                        dateTextOverride: a.postDateText,
                        bottom: StatsRow(
                          distanceMeters: stats?.distance,
                          durationSec: stats?.duration,
                          elevationGainM: stats?.cumulativeElevationGain,
                          avgPaceMinPerKm: stats?.avgPace,
                          avgHeartRate: stats?.avgHeartRate,
                        ),
                        bottomGap: 12.0,
                      ),
                    ),

                    // Плашка «обувь» (из ActivityBlock) — без кнопки меню
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ab.EquipmentChip(
                        items: a.equipments,
                        userId: a.userId,
                        activityType: a.type,
                        activityId: a.id,
                        activityDistance: (stats?.distance ?? 0.0) / 1000.0,
                        showMenuButton:
                            false, // скрываем кнопку меню на странице описания
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Плашка «часы» — по ширине как «обувь»: добавили такой же внутренний отступ 10
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: _WatchPill(
                          asset: 'assets/garmin.png',
                          title: 'Garmin Forerunner 965',
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // ───────── Карта маршрута (только если есть точки)
            if (a.points.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: ab.RouteCard(
                  points: a.points.map((c) => ll.LatLng(c.lat, c.lng)).toList(),
                  height:
                      240, // Увеличена высота карты для лучшей видимости маршрута
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],

            // ───────── «Отрезки» — таблица на всю ширину экрана
            const SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Text('Отрезки', style: AppTextStyles.h15w5),
                  ),
                  _SplitsTableFull(),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ───────── Сегменты — как в communication_prefs.dart (вынесены отдельно)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: _SegmentedPill(
                    left: 'Темп',
                    center: 'Пульс',
                    right: 'Высота',
                    value: _chartTab,
                    onChanged: (v) => setState(() => _chartTab = v),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ───────── ЕДИНЫЙ блок: график + сводка темпа
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 210,
                        width: double.infinity,
                        child: _SimpleLineChart(mode: _chartTab),
                      ),
                      const SizedBox(height: 6),
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: 4),
                      const _PaceSummary(), // подписи «Самый быстрый/Средний/Самый медленный»
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// ───────────────────────────── ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ─────────────────────

/// Плашка «часы» — визуально как плашка «обувь», НО без кнопки «…»
class _WatchPill extends StatelessWidget {
  final String asset;
  final String title;
  const _WatchPill({required this.asset, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: ShapeDecoration(
        color: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 3,
            top: 3,
            bottom: 3,
            child: Container(
              width: 50,
              height: 50,
              decoration: ShapeDecoration(
                image: DecorationImage(
                  image: AssetImage(asset),
                  fit: BoxFit.fill,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                ),
              ),
            ),
          ),
          Positioned(
            left: 60,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h13w5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Таблица «Отрезки» — на всю ширину, белый фон с тонкими линиями
class _SplitsTableFull extends StatelessWidget {
  const _SplitsTableFull();

  @override
  Widget build(BuildContext context) {
    // демо-данные (как на макете — 16 км)
    const pace = [
      355,
      333,
      350,
      330,
      334,
      334,
      313,
      319,
      334,
      323,
      332,
      313,
      316,
      298,
      302,
      314,
    ]; // сек/км
    const hr = [
      128,
      135,
      134,
      134,
      133,
      143,
      158,
      149,
      145,
      152,
      153,
      157,
      158,
      162,
      160,
      158,
    ];
    final slowest = pace.reduce((a, b) => a > b ? a : b);

    String fmtPaceSec(int sec) {
      final m = sec ~/ 60;
      final s = sec % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ───── Заголовок столбцов
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('Км', style: AppTextStyles.h12w4),
                ),
                SizedBox(
                  width: 52,
                  child: Text('Темп', style: AppTextStyles.h12w4),
                ),
                Expanded(child: SizedBox()),
                SizedBox(
                  width: 40,
                  child: Text(
                    'Пульс',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.h12w4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: AppColors.border),

          // ───── Строки данных
          ...List.generate(pace.length, (i) {
            final frac = (pace[i] / slowest).clamp(0.05, 1.0);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('${i + 1}', style: AppTextStyles.h12w4),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          fmtPaceSec(pace[i]),
                          style: AppTextStyles.h12w4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (_, c) => Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.skeletonBase,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                              ),
                              Container(
                                width: c.maxWidth * frac,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${hr[i]}',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.h12w4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != pace.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.border,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Переключатель-пилюля (3 сегмента) — стиль как в communication_prefs.dart
class _SegmentedPill extends StatelessWidget {
  final String left;
  final String center;
  final String right;
  final int value;
  final ValueChanged<int> onChanged;

  const _SegmentedPill({
    required this.left,
    required this.center,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Expanded(child: _seg(0, left)),
            Expanded(child: _seg(1, center)),
            Expanded(child: _seg(2, right)),
          ],
        ),
      ),
    );
  }

  Widget _seg(int idx, String text) {
    final selected = value == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? AppColors.surface : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Простой линейный график:
/// - Для «Темп» ось Y — ММ:СС (мин/км), данные храним в сек/км;
/// - Ось X — километры 0..16 (для 16 точек);
/// - Для «Пульс»/«Высота» — обычные числа.
/// - Единицы измерения на оси Y НЕ отображаем.
class _SimpleLineChart extends StatelessWidget {
  final int mode; // 0 pace, 1 hr, 2 elev
  const _SimpleLineChart({required this.mode});

  @override
  Widget build(BuildContext context) {
    // демо-данные (16 точек)
    final paceSec = const [
      355,
      333,
      350,
      330,
      334,
      334,
      313,
      319,
      334,
      323,
      332,
      313,
      316,
      298,
      302,
      314,
    ];
    final hr = const [
      128,
      135,
      134,
      134,
      133,
      143,
      158,
      149,
      145,
      152,
      153,
      157,
      158,
      162,
      160,
      158,
    ];
    final elev = const [
      203,
      210,
      198,
      205,
      202,
      207,
      204,
      199,
      201,
      206,
      208,
      201,
      203,
      205,
      204,
      202,
    ];

    List<double> y;
    bool isPace;

    if (mode == 0) {
      // секунд/км -> будем форматировать как мин/км
      y = paceSec.map((s) => s.toDouble()).toList();
      isPace = true;
    } else if (mode == 1) {
      y = hr.map((v) => v.toDouble()).toList();
      isPace = false;
    } else {
      y = elev.map((v) => v.toDouble()).toList();
      isPace = false;
    }

    // xMax = число километров (точек). Подписываем 0..xMax (включительно).
    final xMax = y.length;

    return CustomPaint(
      painter: _LinePainter(yValues: y, paceMode: isPace, xMax: xMax),
      willChange: false,
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> yValues; // для Темпа — секунды/км
  final bool paceMode; // true -> формат ММ:СС
  final int xMax; // количество км (точек), рисуем подписи 0..xMax

  _LinePainter({
    required this.yValues,
    required this.paceMode,
    required this.xMax,
  });

  String _fmtSecToMinSec(double sec) {
    final s = sec.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = AppColors.skeletonBase
      ..strokeWidth = 1;

    final paintLine = Paint()
      ..color = AppColors.brandPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Паддинги для осей и подписей — уменьшили left, чтобы график стал шире
    const left = 36.0; // было 48.0
    const bottom = 38.0; // место под подписи км
    const top = 8.0;
    const right = 8.0;

    final w = size.width - left - right;
    final h = size.height - top - bottom;

    if (yValues.isEmpty || w <= 0 || h <= 0) return;

    // Горизонтальные линии (Y)
    const gridY = 5;
    for (int i = 0; i <= gridY; i++) {
      final y = top + h * (i / gridY);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), paintGrid);
    }

    // Вертикальные линии + подписи X (0..xMax)
    final tpXStyle = const TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: AppColors.textSecondary,
    );
    for (int k = 0; k <= xMax; k++) {
      final x = left + w * (k / xMax);
      canvas.drawLine(Offset(x, top), Offset(x, top + h), paintGrid);

      final span = TextSpan(text: '$k', style: tpXStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, top + h + 6));
    }

    // Нормализация Y
    final minY = yValues.reduce((a, b) => a < b ? a : b);
    final maxY = yValues.reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs() < 1e-6 ? 1 : (maxY - minY);

    // Линия графика
    final dx = w / (yValues.length - 1);
    final path = ui.Path();
    for (int i = 0; i < yValues.length; i++) {
      final nx = left + dx * i;
      final ny = top + h * (1 - (yValues[i] - minY) / range);
      if (i == 0) {
        path.moveTo(nx, ny);
      } else {
        path.lineTo(nx, ny);
      }
    }
    canvas.drawPath(path, paintLine);

    // Подписи оси Y (max, mid, min) — единицу измерения НЕ рисуем
    final tpYStyle = const TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: AppColors.textSecondary,
    );
    final labels = <double>[maxY, minY + (maxY - minY) * 0.5, minY];
    for (int i = 0; i < labels.length; i++) {
      final val = labels[i];
      final ly = i == 0 ? top : (i == 1 ? top + h / 2 : top + h);
      final txt = paceMode ? _fmtSecToMinSec(val) : val.toStringAsFixed(0);
      final span = TextSpan(text: txt, style: tpYStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(left - tp.width - 6, ly - tp.height / 2));
    }

    // (удалено) Единицы измерения у оси Y — не рисуем по задаче
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.yValues != yValues || old.paceMode != paceMode || old.xMax != xMax;
}

/// Подписи к темпу — в одном блоке с графиком (значения как на макете)
class _PaceSummary extends StatelessWidget {
  final double horizontalPadding;
  const _PaceSummary({this.horizontalPadding = 12})
    : assert(horizontalPadding >= 0); // заодно тихо «используем» значение

  @override
  Widget build(BuildContext context) {
    Widget row(String name, String val) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
            ),
            Text(
              val,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          row('Самый быстрый', '4:58 /км'),
          row('Средний темп', '5:24 /км'),
          row('Самый медленный', '5:55 /км'),
        ],
      ),
    );
  }
}
