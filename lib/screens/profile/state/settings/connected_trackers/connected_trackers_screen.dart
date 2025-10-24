// lib/screens/profile/settings/connected_trackers_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//  Экран «Подключенные трекеры» (лёгкий iOS-стиль)
//  • Оставлены показатели:
//      WORKOUT, STEPS, DISTANCE_DELTA, ACTIVE_ENERGY_BURNED, HEART_RATE
//  • «Богатый» статус: ключевые метрики + секции
//      – шаги по дням,
//      – тренировки по видам,
//      – что нашли по типам.
//  • Разный tint для метрик/секций, без тяжёлых теней/графиков.
//  • Прозрачности — только Color.withValues(...).
//  • Убраны «Пульс мин/макс» полностью (логика и UI).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart'; // PaceAppBar
import '../../../../../widgets/primary_button.dart';

class ConnectedTrackersScreen extends StatefulWidget {
  const ConnectedTrackersScreen({super.key});

  @override
  State<ConnectedTrackersScreen> createState() =>
      _ConnectedTrackersScreenState();
}

class _ConnectedTrackersScreenState extends State<ConnectedTrackersScreen> {
  // Плагин Health (Health Connect/HealthKit)
  final Health _health = Health();

  // ────────────────────────────────────────────────────────────────────────
  //  РОВНО ТЕ ТИПЫ, КОТОРЫЕ НУЖНЫ
  // ────────────────────────────────────────────────────────────────────────
  static const List<HealthDataType> _types = <HealthDataType>[
    // Активность / тренировки
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,

    // Пульс
    HealthDataType.HEART_RATE,
  ];

  bool _configured = false;
  bool _busy = false;

  // Краткий статус
  String _status = '';

  // ────────────────────────────────────────────────────────────────────────
  //  АГРЕГАТЫ ЗА 7 ДНЕЙ (ТОЛЬКО ДЛЯ ОСТАВЛЕННЫХ ТИПОВ)
  // ────────────────────────────────────────────────────────────────────────
  Map<HealthDataType, List<HealthDataPoint>> _byType = {};

  // Шаги
  int _stepsTotal = 0;
  Map<DateTime, int> _stepsByDay = {};

  // Пульс (только средний)
  double? _hrAvg;

  // Дистанция/ккал
  double _sumDistanceMeters = 0;
  double _sumActiveKcal = 0;

  // Тренировки
  int _workouts = 0;
  Map<String, int> _workoutsByActivity = {};

  // Период синка
  DateTime? _periodStart, _periodEnd;

  // Для SnackBar
  String? _snackBarMessage;

  @override
  void initState() {
    super.initState();
    _ensureConfigured();
  }

  // ────────────────────────────────────────────────────────────────────────
  //  УТИЛИТЫ
  // ────────────────────────────────────────────────────────────────────────
  void _showSnackBar(String message) {
    if (!mounted) return;
    setState(() => _snackBarMessage = message);
  }

  DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _typeName(HealthDataType t) {
    switch (t) {
      case HealthDataType.WORKOUT:
        return 'Тренировки';
      case HealthDataType.STEPS:
        return 'Шаги';
      case HealthDataType.DISTANCE_DELTA:
        return 'Дистанция';
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        return 'Активные ккал';
      case HealthDataType.HEART_RATE:
        return 'Пульс';
      default:
        return t.name;
    }
  }

  static String _kmText(double meters) {
    if (meters <= 0) return '0 км';
    final km = meters / 1000.0;
    return km >= 100
        ? '${km.toStringAsFixed(0)} км'
        : '${km.toStringAsFixed(1)} км';
  }

  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  static String _shortD(DateTime d) => '${d.day}.${d.month}';

  static String _weekDayShort(DateTime d) {
    const w = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final idx = d.weekday - 1;
    return w[idx.clamp(0, 6)];
  }

  static String _formatSteps(int steps) {
    if (steps >= 10000) {
      final k = steps / 1000.0;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
    }
    return steps.toString();
  }

  // ────────────────────────────────────────────────────────────────────────
  //  КОНФИГУРАЦИЯ + НАЛИЧИЕ HEALTH CONNECT
  // ────────────────────────────────────────────────────────────────────────
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

  // ────────────────────────────────────────────────────────────────────────
  //  ПРАВА ДОСТУПА
  // ────────────────────────────────────────────────────────────────────────
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
              ? 'Разрешите доступ в системном диалоге, чтобы импортировать тренировки, шаги, пульс и ккал.'
              : 'Откроется Health Connect — включите разрешения на чтение (тренировки, шаги, пульс и ккал).',
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

  // ────────────────────────────────────────────────────────────────────────
  //  СИНХРОНИЗАЦИЯ ЗА 7 ДНЕЙ + АГРЕГАТЫ (ТОЛЬКО ОСТАВЛЕННЫЕ ТИПЫ)
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _fetchLast7Days() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _status = 'Запрашиваю доступ…';

      // Сброс прежних агрегатов
      _byType = {};
      _stepsTotal = 0;
      _stepsByDay = {};
      _hrAvg = null;
      _sumDistanceMeters = 0;
      _sumActiveKcal = 0;
      _workouts = 0;
      _workoutsByActivity = {};
      _periodStart = _periodEnd = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));

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

      // Шаги
      int stepsTotal = 0;
      final stepsByDay = <DateTime, int>{};
      for (final p
          in byType[HealthDataType.STEPS] ?? const <HealthDataPoint>[]) {
        final v = p.value;
        if (v is NumericHealthValue) {
          final n = v.numericValue.toInt();
          stepsTotal += n;
          stepsByDay.update(
            _dayKey(p.dateFrom),
            (old) => old + n,
            ifAbsent: () => n,
          );
        }
      }

      // Пульс — только средний
      final hrVals = <double>[];
      for (final p
          in byType[HealthDataType.HEART_RATE] ?? const <HealthDataPoint>[]) {
        final v = p.value;
        if (v is NumericHealthValue) hrVals.add(v.numericValue.toDouble());
      }
      double? hrAvg;
      if (hrVals.isNotEmpty) {
        double sum = 0;
        for (final d in hrVals) sum += d;
        hrAvg = sum / hrVals.length;
      }

      // Дистанция
      double distanceMeters = 0;
      for (final p
          in byType[HealthDataType.DISTANCE_DELTA] ??
              const <HealthDataPoint>[]) {
        final v = p.value;
        if (v is NumericHealthValue)
          distanceMeters += v.numericValue.toDouble();
      }

      // Активные ккал
      double activeKcal = 0;
      for (final p
          in byType[HealthDataType.ACTIVE_ENERGY_BURNED] ??
              const <HealthDataPoint>[]) {
        final v = p.value;
        if (v is NumericHealthValue) activeKcal += v.numericValue.toDouble();
      }

      // Тренировки
      final workouts =
          byType[HealthDataType.WORKOUT] ?? const <HealthDataPoint>[];
      final byActivity = <String, int>{};
      for (final p in workouts) {
        final v = p.value;
        String kind = 'Тренировка';
        if (v is WorkoutHealthValue) {
          kind = v.workoutActivityType?.name ?? 'Тренировка';
        } else {
          final raw = v.toString().toLowerCase();
          if (raw.contains('running'))
            kind = 'Бег';
          else if (raw.contains('walking'))
            kind = 'Ходьба';
          else if (raw.contains('cycling'))
            kind = 'Велосипед';
          else if (raw.contains('swimming'))
            kind = 'Плавание';
        }
        byActivity.update(kind, (old) => old + 1, ifAbsent: () => 1);
      }

      setState(() {
        _byType = byType;

        _stepsTotal = stepsTotal;
        _stepsByDay = stepsByDay;

        _hrAvg = hrAvg;

        _sumDistanceMeters = distanceMeters;
        _sumActiveKcal = activeKcal;

        _workouts = workouts.length;
        _workoutsByActivity = byActivity;

        _status = 'Готово: синх за 7 дней выполнен.';
      });

      _showSnackBar(
        'Синк: тренировки $_workouts, шаги $_stepsTotal, '
        '≈${_sumDistanceMeters.toStringAsFixed(0)} м, '
        'активные ${_sumActiveKcal.toStringAsFixed(0)} ккал',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка: $e');
      _showSnackBar('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  //  UI
  // ────────────────────────────────────────────────────────────────────────
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

    // Палитра tint’ов (аккуратные системные цвета под iOS-стиль)
    const cWorkouts = CupertinoColors.systemPurple;
    const cSteps = CupertinoColors.systemGreen;
    const cDist = CupertinoColors.activeBlue;
    const cActive = CupertinoColors.systemOrange;
    const cHR = CupertinoColors.systemRed;
    const cInfo = CupertinoColors.systemTeal; // для «что нашли»

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
                Icon(
                  CupertinoIcons.waveform_path_ecg,
                  size: 28,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Platform.isIOS
                        ? 'Синхронизация с Apple Здоровьем. Разрешите доступ, чтобы импортировать тренировки, шаги, пульс и ккал.'
                        : 'Синхронизация через Health Connect. Разрешите доступ, чтобы импортировать тренировки, шаги, пульс и ккал.',
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

          // «Богатый» статус — только нужные метрики/секции
          if (_status.isNotEmpty)
            _StatusRichCard(
              title: 'Статус',
              subtitle: _periodStart != null && _periodEnd != null
                  ? 'Период: ${_dmy(_periodStart!)} — ${_dmy(_periodEnd!)}'
                  : null,
              message: _status,

              // Персональные тинты на каждую метрику
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
                  value: _stepsTotal.toString(),
                  tint: cSteps,
                ),
                _Metric(
                  icon: CupertinoIcons.location_fill,
                  label: 'Дистанция',
                  value: _kmText(_sumDistanceMeters),
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
                  label: 'Пульс ср.',
                  value: _hrAvg != null ? _hrAvg!.toStringAsFixed(0) : '—',
                  tint: cHR,
                ),
              ],

              // Динамические секции-пилюли (тоже с разными тинтами)
              sections: [
                if (_stepsByDay.isNotEmpty)
                  _StatusSection<DateTime, int>(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    title: 'Шаги по дням',
                    tint: cSteps,
                    chips: (_stepsByDay.entries.toList()
                      ..sort((a, b) => a.key.compareTo(b.key))),
                    chipLabelBuilder: (e) =>
                        '${_weekDayShort(e.key)}, ${_shortD(e.key)} — ${_formatSteps(e.value)}',
                  ),
                if (_workoutsByActivity.isNotEmpty)
                  _StatusSection<String, int>(
                    icon: CupertinoIcons.sportscourt_fill,
                    title: 'Тренировки по видам',
                    tint: cWorkouts,
                    chips: _workoutsByActivity.entries.toList(),
                    chipLabelBuilder: (e) => '${e.key} — ${e.value}',
                  ),
                if (_byType.isNotEmpty)
                  _StatusSection<String, int>(
                    icon: CupertinoIcons.info_circle_fill,
                    title: 'Что нашли (по типам)',
                    tint: cInfo,
                    chips: _byType.entries
                        .map((e) => MapEntry(_typeName(e.key), e.value.length))
                        .toList(),
                    chipLabelBuilder: (e) => '${e.key} — ${e.value}',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ╔════════════════════════════════════════════════════════════════════════╗
// ║                      КОМПОНЕНТЫ СТАТУС-КАРТОЧКИ                         ║
/*  Идеология:
    • Разные tint-цвета для разных метрик/секций.
    • Фон/бордер делаем от tint через .withValues(alpha: ...).
    • Никаких тяжёлых теней/градиентов — только бордеры/пилюли.
    • Без withOpacity — только .withValues(alpha: ...).
*/
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

/// Секция с иконкой/заголовком и списком «пилюль» (generic по ключу/значению)
class _StatusSection<K, T> {
  final IconData icon;
  final String title;
  final List<MapEntry<K, T>> chips;
  final String Function(MapEntry<K, T>) chipLabelBuilder;
  final Color tint; // акцент для бордера/фона

  const _StatusSection({
    required this.icon,
    required this.title,
    required this.chips,
    required this.chipLabelBuilder,
    required this.tint,
  });
}

/// Главная карточка «Статус»
class _StatusRichCard extends StatelessWidget {
  const _StatusRichCard({
    required this.title,
    required this.message,
    required this.topMetrics,
    this.subtitle,
    this.sections = const <_StatusSection<dynamic, dynamic>>[],
  });

  final String title;
  final String? subtitle;
  final String message;
  final List<_Metric> topMetrics;
  final List<_StatusSection<dynamic, dynamic>> sections;

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

          for (final s in sections) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(s.icon, size: 18, color: s.tint),
                const SizedBox(width: 6),
                Text(s.title, style: AppTextStyles.h13w6),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: s.chips
                  .map(
                    (e) =>
                        _ChipPill(label: s.chipLabelBuilder(e), tint: s.tint),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// «Пилюля»-чип с мягким цветным фоном/бордером
class _ChipPill extends StatelessWidget {
  const _ChipPill({required this.label, required this.tint});
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final bg = tint.withValues(alpha: 0.08);
    final br = tint.withValues(alpha: 0.24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: br, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Решётка ключевых метрик (каждая карточка со своим tint’ом)
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
