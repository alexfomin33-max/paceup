import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../../theme/app_theme.dart';
import '../../../../../../widgets/app_bar.dart';
import '../../../../../../widgets/multi_route_card.dart';
import '../../../../../../models/route_bridge.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  ЭКРАН «ДЕТАЛИ ТРЕНИРОВОК» С ТРЕМЯ ВКЛАДКАМИ (24.10 / 25.10 / 26.10)
///  Стиль повторяет FavoritesScreen: TabBar + TabBarView + свайпы.
///  Вкладка = отдельная загрузка данных по выбранной дате.
/// ─────────────────────────────────────────────────────────────────────────
class TrainingDayTabsScreen extends StatefulWidget {
  const TrainingDayTabsScreen({super.key});

  @override
  State<TrainingDayTabsScreen> createState() => _TrainingDayTabsScreenState();
}

class _TrainingDayTabsScreenState extends State<TrainingDayTabsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Фиксированные даты по задаче
    final List<_DateTab> dates = <_DateTab>[
      _DateTab(label: '24.10', date: DateTime(2025, 10, 24)),
      _DateTab(label: '25.10', date: DateTime(2025, 10, 25)),
      _DateTab(label: '26.10', date: DateTime(2025, 10, 26)),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PaceAppBar(
        title: 'Детали тренировок',
        showBottomDivider: false,
      ),
      body: Column(
        children: [
          // ── Вкладки
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tab,
              isScrollable: false,
              labelColor: AppColors.brandPrimary,
              unselectedLabelColor: AppColors.textPrimary,
              indicatorColor: AppColors.brandPrimary,
              indicatorWeight: 1,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: dates
                  .map(
                    (e) => Tab(
                      child: _TabLabel(
                        icon: CupertinoIcons.calendar,
                        text: e.label,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          // ── Контент вкладок со свайпом
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const BouncingScrollPhysics(),
              children: dates
                  .map((e) => _TrainingTabContent(date: e.date))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TabLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(text, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Простая структура для вкладок
class _DateTab {
  final String label;
  final DateTime date;
  const _DateTab({required this.label, required this.date});
}

/// ─────────────────────────────────────────────────────────────────────────
///  КОНТЕНТ ВКЛАДКИ: грузим Workout/Distance/HR за день, считаем метрики,
///  показываем карту маршрута (Android/Health Connect).
/// ─────────────────────────────────────────────────────────────────────────
class _TrainingTabContent extends StatefulWidget {
  const _TrainingTabContent({required this.date});

  final DateTime date;

  @override
  State<_TrainingTabContent> createState() => _TrainingTabContentState();
}

class _TrainingTabContentState extends State<_TrainingTabContent> {
  final Health _health = Health();

  bool _busy = false;
  String _status = 'Загружаю данные тренировки…';

  DateTime? _wStart;
  DateTime? _wEnd;
  double _distanceMeters = 0;
  Duration _duration = Duration.zero;
  double? _hrAvg;

  List<LatLng> _route = const [];

  // ─── Форматтеры
  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  static String _hms(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _km2(double m) {
    final km = m <= 0 ? 0.0 : m / 1000.0;
    return '${km.toStringAsFixed(2)} км';
  }

  static String _pace(Duration dur, double meters) {
    if (dur <= Duration.zero || meters <= 0) return '—';
    final sec = dur.inSeconds.toDouble();
    final secPerKm = sec / (meters / 1000.0);
    final total = secPerKm.round();
    final mm = total ~/ 60, ss = total % 60;
    return '$mm:${ss.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      // 1) Разрешения
      await _health.configure();
      final types = <HealthDataType>[
        HealthDataType.WORKOUT,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.HEART_RATE,
      ];
      final ok = await _health.requestAuthorization(
        types,
        permissions: List.generate(types.length, (_) => HealthDataAccess.READ),
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _status =
              'Нет доступа к данным. Проверьте разрешения Health Connect/Здоровье.';
        });
        return;
      }

      // 2) Окно дня
      final startOfDay = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        0,
        0,
        0,
      );
      final endOfDay = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        23,
        59,
        59,
      );

      // 3) WORKOUT за день
      final workouts = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      if (!mounted) return;

      if (workouts.isEmpty) {
        setState(() {
          _status = 'За ${_dmy(widget.date)} тренировки не найдены.';
        });
        return;
      }

      workouts.sort((a, b) => a.dateTo.compareTo(b.dateTo));
      final w = workouts.last; // последняя по времени завершения
      final wStart = w.dateFrom;
      final wEnd = w.dateTo;

      // Небольшой запас для поиска маршрута
      final routeStart = wStart.subtract(const Duration(minutes: 5));
      final routeEnd = wEnd.add(const Duration(minutes: 5));

      // 4) Дистанция внутри окна тренировки
      final dists = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.DISTANCE_DELTA],
        startTime: wStart,
        endTime: wEnd,
      );
      double distance = 0;
      for (final p in dists) {
        final v = p.value;
        if (v is NumericHealthValue) distance += v.numericValue.toDouble();
      }

      // 5) Средний пульс
      final hrPoints = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: wStart,
        endTime: wEnd,
      );
      double? hrAvg;
      if (hrPoints.isNotEmpty) {
        double sum = 0;
        int n = 0;
        for (final p in hrPoints) {
          final v = p.value;
          if (v is NumericHealthValue) {
            sum += v.numericValue.toDouble();
            n++;
          }
        }
        if (n > 0) hrAvg = sum / n;
      }

      // 6) Длительность по самой сессии
      final dur = wEnd.difference(wStart);

      // 7) Маршрут (Android/Health Connect)
      List<LatLng> route = const [];
      if (Platform.isAndroid) {
        try {
          route = await RouteBridge.instance.getRoutePoints(
            start: routeStart,
            end: routeEnd,
          );
        } catch (_) {
          // Если требуется разовый консент — система сама покажет.
        }
      }

      setState(() {
        _wStart = wStart;
        _wEnd = wEnd;
        _distanceMeters = distance;
        _duration = dur;
        _hrAvg = hrAvg;
        _route = route;
        _status = 'Готово';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Ошибка загрузки: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _dmy(widget.date);

    // Подготовим карточки с РАЗНЫМИ тинтами (как в connected_trackers_screen)
    final mDate = _M(
      icon: CupertinoIcons.calendar_today,
      label: 'Дата',
      value: dateText,
      tint: CupertinoColors.systemIndigo,
    );
    final mTime = _M(
      icon: CupertinoIcons.time,
      label: 'Время',
      value: (_wStart != null && _wEnd != null)
          ? '${_hm(_wStart!)} - ${_hm(_wEnd!)}'
          : '—',
      tint: CupertinoColors.systemPurple,
    );
    final mDist = _M(
      icon: CupertinoIcons.location,
      label: 'Дистанция',
      value: _km2(_distanceMeters),
      tint: CupertinoColors.activeBlue,
    );
    final mDur = _M(
      icon: CupertinoIcons.timer,
      label: 'Длительность',
      value: _hms(_duration),
      tint: CupertinoColors.systemOrange,
    );
    final mPace = _M(
      icon: CupertinoIcons.speedometer,
      label: 'Темп',
      value: _pace(_duration, _distanceMeters),
      tint: CupertinoColors.systemGreen,
    );
    final mHr = _M(
      icon: CupertinoIcons.heart_fill,
      label: 'Средний пульс',
      value: _hrAvg != null ? _hrAvg!.toStringAsFixed(0) : '—',
      tint: CupertinoColors.systemRed,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Статус
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Тренировка $dateText', style: AppTextStyles.h14w6),
              const SizedBox(height: 6),
              Text(_status, style: AppTextStyles.h13w4),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Метрики (с разными цветами карточек)
        _MetricBlock(items: [mDate, mTime, mDist, mDur, mPace, mHr]),

        const SizedBox(height: 12),

        // ── Карта (Android)
        if (Platform.isAndroid)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Маршрут', style: AppTextStyles.h14w6),
                const SizedBox(height: 8),
                if (_route.length >= 2)
                  MultiRouteCard(polylines: [_route], height: 220)
                else
                  const Text(
                    'Маршрут не найден. Возможно, у источника нет трека, требуется разовый доступ в Health Connect, или данные ещё не пришли.',
                    style: AppTextStyles.h12w4Ter,
                  ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.all(12),
            child: const Text(
              'Карта маршрута доступна на Android (Health Connect). На iOS экран без карты.',
              style: AppTextStyles.h12w4Ter,
            ),
          ),
      ],
    );
  }
}

/// ── Сетка метрик, поддерживает индивидуальный tint у каждой карточки
class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.items});
  final List<_M> items;

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
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

class _M {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  const _M({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });
}
