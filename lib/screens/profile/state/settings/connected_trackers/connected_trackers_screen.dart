import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart'; // PaceAppBar
import '../../../../../widgets/primary_button.dart';

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

// Мост к нативу (Android Health Connect route) — пока остаётся, но на этом
// экране маршруты больше не показываем.
import '../../../../../models/route_bridge.dart';

class ConnectedTrackersScreen extends StatefulWidget {
  const ConnectedTrackersScreen({super.key});

  @override
  State<ConnectedTrackersScreen> createState() =>
      _ConnectedTrackersScreenState();
}

class _ConnectedTrackersScreenState extends State<ConnectedTrackersScreen> {
  // Плагин Health (Health Connect/HealthKit)
  final Health _health = Health();

  // Ровно те типы, которые используем
  static const List<HealthDataType> _types = <HealthDataType>[
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  bool _configured = false;
  bool _busy = false;

  // Краткий статус
  String _status = '';

  // Агрегаты за 7 дней
  Map<HealthDataType, List<HealthDataPoint>> _byType = {};

  // Суммы за период
  int _stepsTotal = 0; // << вернули шаги
  double _sumDistanceMeters = 0;
  double _sumActiveKcal = 0;

  // «Средний пульс» за период
  double? _hrAvg;

  // Разбивки по дням
  final Map<DateTime, double> _distanceByDayMeters = {}; // метры на дату
  final Map<DateTime, Duration> _distanceTimeByDay =
      {}; // длительность из DISTANCE_DELTA по дню
  final Map<DateTime, double> _hrAvgByDay = {}; // ср. пульс на дату

  // Тренировки (счётчик)
  int _workouts = 0;

  // Для потенциальной будущей загрузки маршрутов — окна тренировок и мета
  final List<DateTimeRange> _workoutWindows = [];
  final List<_WorkoutInfo> _workoutInfos = [];

  // Период синка
  DateTime? _periodStart, _periodEnd;

  // Для SnackBar
  String? _snackBarMessage;

  @override
  void initState() {
    super.initState();
    _ensureConfigured();
  }

  // ───────── Утилиты форматирования ─────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    setState(() => _snackBarMessage = message);
  }

  DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String _kmText2(double meters) {
    final km = meters <= 0 ? 0.0 : meters / 1000.0;
    return '${km.toStringAsFixed(2)} км';
  }

  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // HH:MM:SS (всегда)
  static String _fmtHMS(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:' // часы
        '${m.toString().padLeft(2, '0')}:' // минуты
        '${s.toString().padLeft(2, '0')}'; // секунды
  }

  // Ср. темп: M:SS (без "/км")
  static String _fmtPace(Duration dur, double meters) {
    if (dur <= Duration.zero || meters <= 0) return '—';
    final sec = dur.inSeconds.toDouble();
    final secPerKm = sec / (meters / 1000.0);
    final total = secPerKm.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ───────── Конфигурация Health / Health Connect ─────────

  Future<void> _ensureConfigured() async {
    try {
      await _health.configure();
      if (!mounted) return;
      _configured = true;

      if (Platform.isAndroid) {
        final hasHC = await _health.isHealthConnectAvailable();
        if (!mounted) return;

        if (hasHC == false) {
          await _health.installHealthConnect();
          if (!mounted) return;
          setState(() {
            _status =
                'Health Connect не был установлен. Установите его и вернитесь.';
          });
        } else {
          setState(() => _status = 'Health Connect найден.');
        }
      } else {
        setState(() => _status = 'Готово к синхронизации с Apple Здоровьем.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка инициализации: $e');
    }
  }

  // ───────── Разрешения ─────────

  Future<bool> _requestPermissions() async {
    if (!_configured) {
      await _ensureConfigured();
      if (!mounted) return false;
    }

    final has = await _health.hasPermissions(
      _types,
      permissions: List.generate(_types.length, (_) => HealthDataAccess.READ),
    );
    if (has == true) return true;

    final granted = await _health.requestAuthorization(
      _types,
      permissions: List.generate(_types.length, (_) => HealthDataAccess.READ),
    );
    if (!mounted) return false;
    if (granted) return true;

    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text('Нужен доступ к данным'),
        content: Text(
          Platform.isIOS
              ? 'Разрешите доступ в системном диалоге, чтобы импортировать тренировки, пульс и ккал.'
              : 'Откроется Health Connect — включите разрешения на чтение (тренировки, дистанция, пульс и активные калории — если доступны источником).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );

    if (!mounted || retry != true) return false;

    final ok2 = await _health.requestAuthorization(
      _types,
      permissions: List.generate(_types.length, (_) => HealthDataAccess.READ),
    );
    if (!mounted) return false;

    if (!ok2) {
      final hint = Platform.isIOS
          ? 'Настройки → Здоровье → Доступ к данным → PaceUp.'
          : 'Приложение «Health Connect» → Права доступа → PaceUp.';
      _showSnackBar('Доступ не выдан. Проверьте $hint');
    }
    return ok2;
  }

  // ───────── Синхронизация за 7 дней ─────────

  Future<void> _fetchLast7Days() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _status = 'Запрашиваю доступ…';

      _byType = {};
      _stepsTotal = 0;
      _sumDistanceMeters = 0;
      _sumActiveKcal = 0;
      _hrAvg = null;

      _distanceByDayMeters.clear();
      _distanceTimeByDay.clear();
      _hrAvgByDay.clear();

      _workouts = 0;

      _workoutWindows.clear();
      _workoutInfos.clear();

      _periodStart = _periodEnd = null;
    });

    try {
      final ok = await _requestPermissions();
      if (!mounted) return;
      if (!ok) {
        setState(() => _status = 'Доступ к данным не выдан.');
        return;
      }

      setState(() => _status = 'Синхронизация за 7 дней…');
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      _periodStart = weekAgo;
      _periodEnd = now;

      final points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: weekAgo,
        endTime: now,
      );
      if (!mounted) return;

      points.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      // Разложим по типам
      final byType = <HealthDataType, List<HealthDataPoint>>{};
      for (final p in points) {
        byType.putIfAbsent(p.type, () => <HealthDataPoint>[]).add(p);
      }

      // Пульс — средний по периоду + средний по дням
      final hrVals = <double>[];
      final hrSumByDay = <DateTime, double>{};
      final hrCountByDay = <DateTime, int>{};
      for (final p
          in byType[HealthDataType.HEART_RATE] ?? const <HealthDataPoint>[]) {
        final v = p.value;
        if (v is NumericHealthValue) {
          final d = v.numericValue.toDouble();
          hrVals.add(d);
          final key = _dayKey(p.dateFrom);
          hrSumByDay.update(key, (old) => old + d, ifAbsent: () => d);
          hrCountByDay.update(key, (old) => old + 1, ifAbsent: () => 1);
        }
      }
      double? hrAvg;
      if (hrVals.isNotEmpty) {
        double sum = 0;
        for (final d in hrVals) sum += d;
        hrAvg = sum / hrVals.length;
      }
      hrSumByDay.forEach((k, sum) {
        final c = hrCountByDay[k] ?? 1;
        _hrAvgByDay[k] = sum / c;
      });

      // Шаги — сумма
      int stepsTotal = 0;
      for (final p
          in byType[HealthDataType.STEPS] ?? const <HealthDataPoint>[]) {
        final v = p.value;
        if (v is NumericHealthValue) {
          stepsTotal += v.numericValue.toInt();
        }
      }

      // Дистанция и «время» — ТОЛЬКО по DISTANCE_DELTA
      double distanceMeters = 0;
      final distancePoints =
          byType[HealthDataType.DISTANCE_DELTA] ?? const <HealthDataPoint>[];
      for (final p in distancePoints) {
        final v = p.value;
        if (v is NumericHealthValue) {
          final m = v.numericValue.toDouble();
          distanceMeters += m;
          final day = _dayKey(p.dateFrom);
          _distanceByDayMeters.update(day, (old) => old + m, ifAbsent: () => m);

          // вклад во «время» из окна записи DISTANCE_DELTA
          final dur = p.dateTo.difference(p.dateFrom);
          if (dur > Duration.zero) {
            _distanceTimeByDay.update(
              day,
              (old) => old + dur,
              ifAbsent: () => dur,
            );
          }
        }
      }

      // Активные ккал: сумма
      double activeKcal = 0;
      for (final p
          in byType[HealthDataType.ACTIVE_ENERGY_BURNED] ??
              const <HealthDataPoint>[]) {
        final v = p.value;
        if (v is NumericHealthValue) activeKcal += v.numericValue.toDouble();
      }

      // Тренировки — только считаем и сохраняем окна (карты уже не показываем)
      final workouts =
          byType[HealthDataType.WORKOUT] ?? const <HealthDataPoint>[];
      _workoutWindows.clear();
      _workoutInfos.clear();
      for (final p in workouts) {
        final v = p.value;
        String kind = 'Тренировка';
        if (v is WorkoutHealthValue) {
          kind = v.workoutActivityType?.name ?? 'Тренировка';
        } else {
          final raw = v.toString().toLowerCase();
          if (raw.contains('running')) {
            kind = 'Бег';
          } else if (raw.contains('walking')) {
            kind = 'Ходьба';
          } else if (raw.contains('cycling')) {
            kind = 'Велосипед';
          } else if (raw.contains('swimming')) {
            kind = 'Плавание';
          }
        }

        final origStart = p.dateFrom;
        final origEnd = p.dateTo;
        final start = origStart.subtract(const Duration(minutes: 5));
        final end = origEnd.add(const Duration(minutes: 5));
        _workoutWindows.add(DateTimeRange(start: start, end: end));
        _workoutInfos.add(
          _WorkoutInfo(start: origStart, end: origEnd, kind: kind),
        );
      }

      setState(() {
        _byType = byType;

        _stepsTotal = stepsTotal; // << вернули шаги
        _sumDistanceMeters = distanceMeters;
        _sumActiveKcal = activeKcal;
        _hrAvg = hrAvg;

        _workouts = workouts.length;

        _status = 'Готово: синх за 7 дней выполнен.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка: $e');
      _showSnackBar('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    // Ленивая демонстрация SnackBar
    if (_snackBarMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_snackBarMessage!)));
        setState(() => _snackBarMessage = null);
      });
    }

    // Палитра tint’ов (iOS-системные)
    const cWorkouts = CupertinoColors.systemPurple;
    const cSteps = CupertinoColors.systemGreen;
    const cDist = CupertinoColors.activeBlue;
    const cActive = CupertinoColors.systemOrange;
    const cHR = CupertinoColors.systemRed;
    const cInfo = CupertinoColors.systemGreen;

    return Scaffold(
      backgroundColor: AppColors.background,
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
            child: Row(
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
          ),

          const SizedBox(height: 16),

          // Кнопка синка
          Center(
            child: PrimaryButton(
              text: _busy
                  ? 'Синхронизация…'
                  : (Platform.isIOS
                        ? 'Синк из Apple Здоровья'
                        : 'Синк из Health Connect'),
              onPressed: _busy ? null : _fetchLast7Days,
              width: 260,
              height: 44,
              isLoading: _busy,
            ),
          ),

          const SizedBox(height: 16),

          // Статус и метрики
          if (_status.isNotEmpty)
            _StatusRichCard(
              title: 'Статус',
              subtitle: _periodStart != null && _periodEnd != null
                  ? 'Период: ${_dmy(_periodStart!)} — ${_dmy(_periodEnd!)}'
                  : null,
              message: _status,
              topMetrics: [
                _Metric(
                  icon: CupertinoIcons.flag_circle_fill,
                  label: 'Тренировки',
                  value: _workouts.toString(),
                  tint: cWorkouts,
                ),
                _Metric(
                  icon: CupertinoIcons.chart_bar_alt_fill,
                  label: 'Шаги',
                  value: _stepsTotal.toString(), // << вернули
                  tint: cSteps,
                ),
                _Metric(
                  icon: CupertinoIcons.location_fill,
                  label: 'Дистанция',
                  value: _kmText2(_sumDistanceMeters),
                  tint: cDist,
                ),
                _Metric(
                  icon: CupertinoIcons.flame_fill,
                  label: 'Активные ккал',
                  value: _sumActiveKcal.toStringAsFixed(0),
                  tint: cActive,
                ),
                _Metric(
                  icon: CupertinoIcons.heart_fill,
                  label: 'Средний пульс',
                  value: _hrAvg != null ? _hrAvg!.toStringAsFixed(0) : '—',
                  tint: cHR,
                ),
              ],
              sections: [
                // Таблица «Активность по дням»
                if (_distanceByDayMeters.isNotEmpty ||
                    _distanceTimeByDay.isNotEmpty ||
                    _hrAvgByDay.isNotEmpty)
                  _ActivityTable(
                    distanceByDayMeters: _distanceByDayMeters,
                    distanceTimeByDay: _distanceTimeByDay,
                    hrAvgByDay: _hrAvgByDay,
                    tint: cInfo,
                    maxRows: 7,
                  ),
              ],
            ),

          // ───────────────────────────────────────────────────────────────
          //  ОДНА PRIMARY-КНОПКА «ДЕТАЛИ ТРЕНИРОВОК»
          //  Открывает экран со вкладками 24.10 / 25.10 / 26.10
          // ───────────────────────────────────────────────────────────────
          const SizedBox(height: 20),
          Center(
            child: PrimaryButton(
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
          ),
        ],
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

class _WorkoutInfo {
  final DateTime start;
  final DateTime end;
  final String kind;
  const _WorkoutInfo({
    required this.start,
    required this.end,
    required this.kind,
  });
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
