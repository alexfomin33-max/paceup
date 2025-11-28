import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart'; // PaceAppBar
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../providers/trackers/connected_trackers_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ЭКРАН «ПОДКЛЮЧЕННЫЕ ТРЕКЕРЫ»
//  Изменения по задаче:
//   • Удалена секция «Тренировки по видам».
//   • Удалён вывод карт маршрутов внутри этого экрана.
//   • Добавлена ОДНА кнопка «Детали тренировок» (PrimaryButton), которая
//     открывает экран с тремя вкладками 24.10 / 25.10 / 26.10.
//   • Вся остальная логика синка/метрик/таблицы по дням — без изменений.
// ─────────────────────────────────────────────────────────────────────────────

import 'trackers/training_day_screen.dart'; // новый экран с вкладками

class ConnectedTrackersScreen extends ConsumerStatefulWidget {
  const ConnectedTrackersScreen({super.key});

  @override
  ConsumerState<ConnectedTrackersScreen> createState() =>
      _ConnectedTrackersScreenState();
}

class _ConnectedTrackersScreenState
    extends ConsumerState<ConnectedTrackersScreen> {
  // Плагин Health (Health Connect/HealthKit)
  final Health _health = Health();

  @override
  void initState() {
    super.initState();
    // Инициализация Health при старте
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(connectedTrackersProvider.notifier)
          .ensureConfigured(_health);
    });
  }

  // ───────── Утилиты форматирования ─────────

  static String _kmText2(double meters) {
    final km = meters <= 0 ? 0.0 : meters / 1000.0;
    return '${km.toStringAsFixed(2)} км';
  }

  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  // ───────── Синхронизация за 7 дней ─────────
  Future<void> _fetchLast7Days() async {
    await ref
        .read(connectedTrackersProvider.notifier)
        .fetchLast7Days(_health, context, ref);
  }

  // ───────── Импорт всех найденных тренировок ─────────
  Future<void> _importAllWorkouts() async {
    await ref
        .read(connectedTrackersProvider.notifier)
        .importAllWorkouts(_health, context, ref);
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectedTrackersProvider);

    // Ленивая демонстрация SnackBar
    if (state.snackBarMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.snackBarMessage!)),
        );
        ref.read(connectedTrackersProvider.notifier).clearSnackBar();
      });
    }

    // Палитра tint'ов (iOS-системные)
    const cWorkouts = CupertinoColors.systemPurple;
    const cSteps = CupertinoColors.systemGreen;
    const cDist = CupertinoColors.activeBlue;
    const cActive = CupertinoColors.systemOrange;
    const cHR = CupertinoColors.systemRed;
    const cInfo = CupertinoColors.systemGreen;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Подключенные трекеры'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Инфоблок
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.waveform_path_ecg,
                        size: 28,
                        color: AppColors.brandPrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          Platform.isIOS
                              ? 'Синхронизация с Apple Здоровьем. Разрешите доступ, чтобы импортировать тренировки, пульс и ккал.'
                              : 'Синхронизация через Health Connect. Разрешите доступ, чтобы импортировать тренировки, дистанцию, пульс и активные калории (если доступны источником).',
                          style: AppTextStyles.h13w4,
                        ),
                      ),
                    ],
                  ),
                  // ───────────────────────────────────────────────────────────────
                  //  ИНСТРУКЦИИ ПО НАСТРОЙКЕ GARMIN CONNECT
                  // ───────────────────────────────────────────────────────────────
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.brandPrimary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.info_circle_fill,
                                size: 18,
                                color: AppColors.brandPrimary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Настройка Garmin Connect',
                                style: AppTextStyles.h13w6,
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Чтобы выгружать тренировки из Garmin Connect:\n\n'
                            '1. Откройте приложение Garmin Connect\n'
                            '2. Перейдите в Настройки → Подключения\n'
                            '3. Найдите "Health Connect" и подключите\n'
                            '4. Включите синхронизацию тренировок\n'
                            '5. Вернитесь сюда и нажмите "Синк из Health Connect"',
                            style: AppTextStyles.h12w4Ter,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Кнопка синка
            Center(
              child: PrimaryButton(
                text: state.busy
                    ? 'Синхронизация…'
                    : (Platform.isIOS
                          ? 'Синк из Apple Здоровья'
                          : 'Синк из Health Connect'),
                onPressed: state.busy ? () {} : () => _fetchLast7Days(),
                width: 260,
                height: 44,
                isLoading: state.busy,
              ),
            ),

            const SizedBox(height: 16),

            // Статус и метрики
            if (state.status.isNotEmpty)
              _StatusRichCard(
                title: 'Статус',
                subtitle: state.periodStart != null && state.periodEnd != null
                    ? 'Период: ${_dmy(state.periodStart!)} — ${_dmy(state.periodEnd!)}'
                    : null,
                message: state.status,
                topMetrics: [
                  _Metric(
                    icon: CupertinoIcons.flag_circle_fill,
                    label: 'Тренировки',
                    value: state.workouts.toString(),
                    tint: cWorkouts,
                  ),
                  _Metric(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    label: 'Шаги',
                    value: state.stepsTotal.toString(),
                    tint: cSteps,
                  ),
                  _Metric(
                    icon: CupertinoIcons.location_fill,
                    label: 'Дистанция',
                    value: _kmText2(state.sumDistanceMeters),
                    tint: cDist,
                  ),
                  _Metric(
                    icon: CupertinoIcons.flame_fill,
                    label: 'Активные ккал',
                    value: state.sumActiveKcal.toStringAsFixed(0),
                    tint: cActive,
                  ),
                  _Metric(
                    icon: CupertinoIcons.heart_fill,
                    label: 'Средний пульс',
                    value: state.hrAvg != null ? state.hrAvg!.toStringAsFixed(0) : '—',
                    tint: cHR,
                  ),
                ],
                sections: [
                  // Таблица «Активность по дням»
                  if (state.distanceByDayMeters.isNotEmpty ||
                      state.distanceTimeByDay.isNotEmpty ||
                      state.hrAvgByDay.isNotEmpty)
                    _ActivityTable(
                      distanceByDayMeters: state.distanceByDayMeters,
                      distanceTimeByDay: state.distanceTimeByDay,
                      hrAvgByDay: state.hrAvgByDay,
                      tint: cInfo,
                      maxRows: 7,
                    ),
                ],
              ),

            // ───────────────────────────────────────────────────────────────
            //  КНОПКИ: ДЕТАЛИ ТРЕНИРОВОК И ИМПОРТ
            // ───────────────────────────────────────────────────────────────
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  PrimaryButton(
                    text: 'Детали тренировок',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TrainingDayTabsScreen(),
                        ),
                      );
                    },
                    width: 260,
                    height: 44,
                  ),
                  if (state.workouts > 0) ...[
                    const SizedBox(height: 12),
                    PrimaryButton(
                      text: state.importing
                          ? 'Импорт…'
                          : 'Импортировать все тренировки',
                      onPressed: state.importing ? () {} : _importAllWorkouts,
                      width: 260,
                      height: 44,
                      isLoading: state.importing,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ╔════════════════════════════════════════════════════════════════════════╗
// ║                      КОМПОНЕНТЫ СТАТУС-КАРТОЧКИ                         ║
// ╚════════════════════════════════════════════════════════════════════════╝

class _Metric {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });
}

/// Таблица «Активность по дням»
class _ActivityTable extends StatelessWidget {
  const _ActivityTable({
    required this.distanceByDayMeters,
    required this.distanceTimeByDay,
    required this.hrAvgByDay,
    required this.tint,
    this.maxRows = 7,
  });

  final Map<DateTime, double> distanceByDayMeters; // м
  final Map<DateTime, Duration>
  distanceTimeByDay; // суммарная длит. DISTANCE_DELTA
  final Map<DateTime, double> hrAvgByDay;
  final Color tint;
  final int maxRows;

  static String _weekDayShort(DateTime d) {
    const w = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final idx = d.weekday - 1;
    return w[idx.clamp(0, 6)];
  }

  static String _shortD(DateTime d) => '${d.day}.${d.month}';

  static String _kmText2(double meters) {
    final km = meters <= 0 ? 0.0 : meters / 1000.0;
    return '${km.toStringAsFixed(2)} км';
  }

  static String _fmtHMS(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  static String _fmtPace(Duration dur, double meters) {
    if (dur <= Duration.zero || meters <= 0) return '—';
    final sec = dur.inSeconds.toDouble();
    final secPerKm = sec / (meters / 1000.0);
    final total = secPerKm.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Объединяем все дни, которые фигурируют где-либо
    final allDays = <DateTime>{
      ...distanceByDayMeters.keys,
      ...distanceTimeByDay.keys,
      ...hrAvgByDay.keys,
    }.toList()..sort((a, b) => a.compareTo(b));

    // Последние maxRows
    final int start = (allDays.length - maxRows) < 0
        ? 0
        : (allDays.length - maxRows);
    final days = allDays.sublist(start);

    final bg = tint.withValues(alpha: 0.04);
    final br = tint.withValues(alpha: 0.20);
    final headerBg = tint.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: br, width: 1),
      ),
      child: Column(
        children: [
          // Заголовок
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.sm),
              ),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.chart_bar_alt_fill, size: 16, color: tint),
                const SizedBox(width: 6),
                const Text(
                  'Активность по дням',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Шапка таблицы
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'День',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Дистанция',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Время',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Темп',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Пульс',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Ряды
          ...days.map((d) {
            final dist = distanceByDayMeters[d]; // м
            final dur = distanceTimeByDay[d]; // длительность DISTANCE_DELTA
            final hr = hrAvgByDay[d];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${_weekDayShort(d)}, ${_shortD(d)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      dist != null ? _kmText2(dist) : '—',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      dur != null ? _fmtHMS(dur) : '—',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      (dur != null && dist != null) ? _fmtPace(dur, dist) : '—',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      hr != null ? hr.toStringAsFixed(0) : '—',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Карточка «Статус»
class _StatusRichCard extends StatelessWidget {
  const _StatusRichCard({
    required this.title,
    required this.message,
    required this.topMetrics,
    this.subtitle,
    this.sections = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final String message;
  final List<_Metric> topMetrics;
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h14w6),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTextStyles.h12w4Ter),
          ],
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.h13w4),

          if (topMetrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MetricGrid(items: topMetrics),
          ],

          for (final w in sections) ...[const SizedBox(height: 14), w],
        ],
      ),
    );
  }
}

/// Решётка метрик
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final itemWidth = width >= 420
        ? (width - 16 * 2 - 8 * 2) / 3
        : (width >= 360 ? (width - 16 * 2 - 8) / 2 : width - 16 * 2);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((m) {
        final bg = m.tint.withValues(alpha: 0.06);
        final br = m.tint.withValues(alpha: 0.22);
        return SizedBox(
          width: itemWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: br, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(m.icon, size: 18, color: m.tint),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.label,
                        style: AppTextStyles.h12w4Ter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
