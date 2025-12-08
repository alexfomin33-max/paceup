// lib/screens/lenta/widgets/activity_description_block.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui; // для ui.Path
import 'package:latlong2/latlong.dart' as ll;

import '../../../../core/theme/app_theme.dart';
// Берём готовые виджеты (чтобы совпадал верх с ActivityBlock)
import '../widgets/activity/header/activity_header.dart';
import '../widgets/activity/stats/stats_row.dart';
import '../widgets/activity/equipment/equipment_chip.dart'
    as ab
    show EquipmentChip;
// Карусель маршрута с фотографиями
import '../../widgets/activity_route_carousel.dart';
// Модель — через алиас, чтобы не конфликтовало имя Equipment
import '../../../../domain/models/activity_lenta.dart' as al;
import 'combining_screen.dart';
import 'fullscreen_route_map_screen.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';

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
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: PaceAppBar(
          title: 'Тренировка',
          showBottomDivider:
              false, // чтобы не было двойной линии со следующим блоком
          actions: [
            IconButton(
              splashRadius: 22,
              icon: Icon(
                CupertinoIcons.personalhotspot,
                size: 20,
                color: AppColors.getIconPrimaryColor(context),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  TransparentPageRoute(builder: (_) => const CombiningScreen()),
                );
              },
            ),
            IconButton(
              splashRadius: 22,
              icon: Icon(
                CupertinoIcons.ellipsis,
                size: 20,
                color: AppColors.getIconPrimaryColor(context),
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
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceColor(context),
                  border: Border(
                    top: BorderSide(
                      width: 0.5,
                      color: AppColors.getBorderColor(context),
                    ),
                    bottom: BorderSide(
                      width: 0.5,
                      color: AppColors.getBorderColor(context),
                    ),
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
                          avgCadence: stats?.avgCadence,
                          calories: stats?.calories,
                          totalSteps: stats?.totalSteps,
                          // ────────────────────────────────────────────────────────────────
                          // Тренировка добавлена вручную только если нет GPS-трека
                          // И нет данных о пульсе/каденсе (значит действительно вручную)
                          // ────────────────────────────────────────────────────────────────
                          isManuallyAdded:
                              a.points.isEmpty &&
                              (stats?.avgHeartRate == null &&
                                  stats?.avgCadence == null),
                          // ────────────────────────────────────────────────────────────────
                          // Показываем третью строку (Калории | Шаги | Скорость) на экране описания
                          // ────────────────────────────────────────────────────────────────
                          showExtendedStats: true,
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

            // ───────── Карта маршрута с фотографиями (как в ActivityBlock)
            // Показываем только если есть точки маршрута или есть изображения
            // Соотношение сторон 1.3:1 (как в постах и тренировках)
            if (a.points.isNotEmpty || a.mediaImages.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Вычисляем высоту для соотношения сторон 1.3:1
                    final width = constraints.maxWidth;
                    final height = width / 1.3;
                    return ActivityRouteCarousel(
                      points: a.points
                          .map((c) => ll.LatLng(c.lat, c.lng))
                          .toList(),
                      imageUrls: a.mediaImages,
                      height: height,
                      // ────────────────────────────────────────────────────────────────
                      // 🔹 ОТКРЫТИЕ ПОЛНОЭКРАННОЙ КАРТЫ: при клике на слайд с картой
                      // ────────────────────────────────────────────────────────────────
                      onMapTap: a.points.isNotEmpty
                          ? () {
                              Navigator.of(context).push(
                                TransparentPageRoute(
                                  builder: (context) =>
                                      FullscreenRouteMapScreen(
                                        points: a.points
                                            .map((c) => ll.LatLng(c.lat, c.lng))
                                            .toList(),
                                      ),
                                ),
                              );
                            }
                          : null,
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],

            // ───────── «Отрезки» — таблица на всю ширину экрана
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Text(
                      'Отрезки',
                      style: AppTextStyles.h15w5.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                  _SplitsTableFull(stats: stats),
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
                    color: AppColors.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.getBorderColor(context),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 210,
                        width: double.infinity,
                        child: _SimpleLineChart(mode: _chartTab),
                      ),
                      const SizedBox(height: 6),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: AppColors.getBorderColor(context),
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
        // ────────────────────────────────────────────────────────────────
        // 🌓 ТЕМНАЯ ТЕМА: фон плашки часов такой же, как у плашки кроссовок
        // ────────────────────────────────────────────────────────────────
        // В темной теме используем darkSurfaceMuted (как у плашки кроссовок)
        // В светлой теме оставляем getBackgroundColor (не трогаем)
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceMuted
            : AppColors.getBackgroundColor(context),
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
                style: AppTextStyles.h13w5.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Таблица «Отрезки» — на всю ширину, белый фон с тонкими линиями
/// Использует реальные данные из Garmin Connect (pacePerKm и heartRatePerKm)
///
/// Как проверить наличие данных о сегментах:
/// 1. В логах (developer.log) будет видно количество сегментов
/// 2. Используйте stats?.hasSplitsData() для проверки наличия данных
/// 3. Используйте stats?.splitsCount для получения количества сегментов
/// 4. Данные приходят из API в формате Map<String, double>:
///    - pacePerKm: {"1": 355.0, "2": 333.0, ...} (секунды на километр)
///    - heartRatePerKm: {"1": 128.0, "2": 135.0, ...} (пульс в bpm)
class _SplitsTableFull extends StatelessWidget {
  final al.ActivityStats? stats;

  const _SplitsTableFull({this.stats});

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // Извлекаем данные о сегментах из stats
    // pacePerKm и heartRatePerKm — это Map<String, double>
    // где ключи — номера километров ("1", "2", "3" и т.д.)
    // ────────────────────────────────────────────────────────────────
    final pacePerKm = stats?.pacePerKm ?? <String, double>{};
    final heartRatePerKm = stats?.heartRatePerKm ?? <String, double>{};

    // ────────────────────────────────────────────────────────────────
    // Если данных нет, показываем пустую таблицу с заголовками
    // ────────────────────────────────────────────────────────────────
    if (pacePerKm.isEmpty && heartRatePerKm.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          border: Border(
            top: BorderSide(color: AppColors.getBorderColor(context), width: 1),
            bottom: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      'Км',
                      style: AppTextStyles.h12w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      'Темп',
                      style: AppTextStyles.h12w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  SizedBox(
                    width: 40,
                    child: Text(
                      'Пульс',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.h12w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: AppColors.getBorderColor(context),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Нет данных о сегментах',
                    style: AppTextStyles.h13w4.copyWith(
                      color: AppColors.getTextSecondaryColor(context),
                    ),
                  ),
                  if (stats == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Статистика тренировки недоступна',
                        style: AppTextStyles.h12w4.copyWith(
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Garmin Connect не передал данные о сегментах',
                        style: AppTextStyles.h12w4.copyWith(
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // Собираем все ключи (номера километров) и сортируем их
    // ────────────────────────────────────────────────────────────────
    final allKeys = <String>{...pacePerKm.keys, ...heartRatePerKm.keys};
    final sortedKeys = allKeys.toList()
      ..sort((a, b) {
        // Сортируем по числовому значению ключа
        final aNum = int.tryParse(a) ?? 0;
        final bNum = int.tryParse(b) ?? 0;
        return aNum.compareTo(bNum);
      });

    if (sortedKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    // ────────────────────────────────────────────────────────────────
    // Находим самый медленный темп для нормализации визуальных полос
    // ────────────────────────────────────────────────────────────────
    final paceValues = sortedKeys
        .map((k) => pacePerKm[k] ?? 0.0)
        .where((v) => v > 0)
        .toList();
    final slowestPace = paceValues.isEmpty
        ? 1.0
        : paceValues.reduce((a, b) => a > b ? a : b);

    // ────────────────────────────────────────────────────────────────
    // Форматирование темпа из секунд в ММ:СС
    // ────────────────────────────────────────────────────────────────
    String fmtPaceSec(double sec) {
      if (sec <= 0) return '-';
      final s = sec.round();
      final m = s ~/ 60;
      final r = s % 60;
      return '$m:${r.toString().padLeft(2, '0')}';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border(
          top: BorderSide(color: AppColors.getBorderColor(context), width: 1),
          bottom: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // ───── Заголовок столбцов
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    'Км',
                    style: AppTextStyles.h12w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    'Темп',
                    style: AppTextStyles.h12w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
                SizedBox(
                  width: 40,
                  child: Text(
                    'Пульс',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.h12w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.getBorderColor(context),
          ),

          // ───── Строки данных из реальных данных Garmin Connect
          ...List.generate(sortedKeys.length, (i) {
            final kmKey = sortedKeys[i];
            final paceSec = pacePerKm[kmKey] ?? 0.0;
            final hr = heartRatePerKm[kmKey] ?? 0.0;

            // ────────────────────────────────────────────────────────────────
            // Вычисляем долю для визуальной полосы темпа
            // Чем быстрее темп (меньше секунд), тем длиннее полоса
            // Используем обратную пропорцию: slowestPace / paceSec
            // ────────────────────────────────────────────────────────────────
            final visualFrac = paceSec > 0 && slowestPace > 0
                ? (slowestPace / paceSec).clamp(0.05, 1.0)
                : 0.05;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          kmKey,
                          style: AppTextStyles.h12w4.copyWith(
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          fmtPaceSec(paceSec),
                          style: AppTextStyles.h12w4.copyWith(
                            color: AppColors.getTextPrimaryColor(context),
                          ),
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
                                width: c.maxWidth * visualFrac,
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
                          hr > 0 ? hr.round().toString() : '-',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.h12w4.copyWith(
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != sortedKeys.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.getBorderColor(context),
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
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
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
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => onChanged(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.getTextPrimaryColor(context)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected
                    ? AppColors.getSurfaceColor(context)
                    : AppColors.getTextPrimaryColor(context),
              ),
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
      painter: _LinePainter(
        yValues: y,
        paceMode: isPace,
        xMax: xMax,
        textSecondaryColor: AppColors.getTextSecondaryColor(context),
      ),
      willChange: false,
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> yValues; // для Темпа — секунды/км
  final bool paceMode; // true -> формат ММ:СС
  final int xMax; // количество км (точек), рисуем подписи 0..xMax
  final Color textSecondaryColor; // цвет текста для подписей осей

  _LinePainter({
    required this.yValues,
    required this.paceMode,
    required this.xMax,
    required this.textSecondaryColor,
  });

  String _fmtSecToMinSec(double sec) {
    final s = sec.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Используем статические цвета для графика (brandPrimary и skeletonBase не зависят от темы)
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
    final tpXStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: textSecondaryColor,
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
    final tpYStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: textSecondaryColor,
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
      old.yValues != yValues ||
      old.paceMode != paceMode ||
      old.xMax != xMax ||
      old.textSecondaryColor != textSecondaryColor;
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
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
            Text(
              val,
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
