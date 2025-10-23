import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart'; // PaceAppBar
import '../../../../../widgets/interactive_back_swipe.dart'; // фуллскрин-свайп

import 'dart:io';
import 'dart:math' as math;
import 'package:health/health.dart';

/*class ConnectedTrackersScreen extends StatelessWidget {
  const ConnectedTrackersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PaceAppBar(title: 'Подключенные трекеры'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.waveform_path_ecg,
                  size: 56,
                  color: AppColors.brandPrimary,
                ),
                SizedBox(height: 16),
                Text(
                  'Подключенные трекеры (в разработке)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Здесь будут подключения Garmin, Polar, Suunto и др.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}*/

class ConnectedTrackersScreen extends StatefulWidget {
  const ConnectedTrackersScreen({super.key});

  @override
  State<ConnectedTrackersScreen> createState() => _ConnectedTrackersScreenState();
}

class _ConnectedTrackersScreenState extends State<ConnectedTrackersScreen> {
  // ✅ Новый API: используем Health, а не HealthFactory
  final Health _health = Health();

  // Набор типов, которые читаем для MVP
  static const List<HealthDataType> _types = <HealthDataType>[
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  @override
  void initState() {
    super.initState();
    _initHealth();
  }

  // Инициализация плагина (обязательна в v13+)
  Future<void> _initHealth() async {
    await _health.configure(); // требование нового API
    // На Android проверим доступность Health Connect (и при желании предложим установить)
    if (Platform.isAndroid) {
      final available = await _health.isHealthConnectAvailable();
      if (available == false) {
        debugPrint('[PaceUp/Health] Health Connect не установлен — открою установку.');
        await _health.installHealthConnect();
      }
    }
  }

  void _log(String msg) => debugPrint('[PaceUp/Health] $msg');

  // Печать одной тренировки (WORKOUT) с разборами новых типов значений
  void _printWorkout(HealthDataPoint dp, int index, int total) {
    final from = dp.dateFrom.toIso8601String();
    final to = dp.dateTo.toIso8601String();
    final src = '${dp.sourceName} (${dp.sourceId})';

    // В новом API значение — не динамическая Map, а типизированный HealthValue.
    // Для тренировок это WorkoutHealthValue: есть totalDistance/totalEnergyBurned и их юниты.
    // Документация по свойствам: workoutActivityType, totalDistance, totalEnergyBurned и пр. :contentReference[oaicite:2]{index=2}
    WorkoutHealthValue? w;
    if (dp.value is WorkoutHealthValue) {
      w = dp.value as WorkoutHealthValue;
    }

    final typeStr = w?.workoutActivityType.name ?? 'unknown';
    final dist = w?.totalDistance;                   // int? (как правило, метры)
    final distUnit = w?.totalDistanceUnit?.name;     // имя юнита (например, METER)
    final kcal = w?.totalEnergyBurned;               // int? (как правило, ккал)
    final kcalUnit = w?.totalEnergyBurnedUnit?.name; // имя юнита

    _log('─ WORKOUT ${index + 1}/$total ───────────────────────────────');
    _log('  Источник : $src');
    _log('  Период   : $from → $to');
    _log('  Тип      : $typeStr');
    _log('  Дистанция: ${dist != null ? '$dist ${distUnit ?? 'm'}' : '—'}');
    _log('  Калории  : ${kcal != null ? '$kcal ${kcalUnit ?? 'kcal'}' : '—'}');
  }

  Future<void> _fetchLast7Days() async {
    // 1) Разрешения
    final granted = await _health.requestAuthorization(
      _types,
      permissions: _types.map((_) => HealthDataAccess.READ).toList(),
    );
    if (!granted) {
      _log('Пользователь не выдал разрешения.');
      return;
    }

    // 2) Чтение
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    _log('Читаю: ${weekAgo.toIso8601String()} → ${now.toIso8601String()}');

    List<HealthDataPoint> points = [];
    try {
      // ✅ Новый API: именованные параметры (types/startTime/endTime)
      points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: weekAgo,
        endTime: now,
      ); // сигнатура здесь: см. docs. :contentReference[oaicite:3]{index=3}
    } catch (e) {
      _log('Ошибка чтения: $e');
      return;
    }

    // 3) Сводка
    points.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    _log('Всего точек: ${points.length}');

    final workouts = points.where((e) => e.type == HealthDataType.WORKOUT).toList();
    _log('Найдено тренировок (WORKOUT): ${workouts.length}');

    final toPrint = math.min(workouts.length, 30);
    for (var i = 0; i < toPrint; i++) {
      _printWorkout(workouts[i], i, workouts.length);
    }
    if (workouts.length > toPrint) {
      _log('…и ещё ${workouts.length - toPrint} тренировок скрыто (чтобы не спамить).');
    }

    // 4) Быстрые агрегаты за 7 дней (через NumericHealthValue)
    // HealthDataPoint.value теперь типизирован (NumericHealthValue для числовых типов). :contentReference[oaicite:4]{index=4}
    final distanceMeters = points
        .where((e) => e.type == HealthDataType.DISTANCE_DELTA && e.value is NumericHealthValue)
        .map((e) => (e.value as NumericHealthValue).numericValue.toDouble())
        .fold<double>(0.0, (a, b) => a + b);

    final activeKcal = points
        .where((e) => e.type == HealthDataType.ACTIVE_ENERGY_BURNED && e.value is NumericHealthValue)
        .map((e) => (e.value as NumericHealthValue).numericValue.toDouble())
        .fold<double>(0.0, (a, b) => a + b);

    _log('Сумма за 7 дней: дистанция ≈ ${distanceMeters.toStringAsFixed(0)} м, активные калории ≈ ${activeKcal.toStringAsFixed(0)} ккал');
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _fetchLast7Days,
      child: Text(Platform.isIOS ? 'Синк из Apple Здоровья' : 'Синк из Health Connect'),
    );
  }
}
