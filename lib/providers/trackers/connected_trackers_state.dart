// ────────────────────────────────────────────────────────────────────────────
//  CONNECTED TRACKERS STATE
//
//  Модель состояния для экрана подключенных трекеров
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Состояние экрана подключенных трекеров
@immutable
class ConnectedTrackersState {
  /// Конфигурация Health завершена
  final bool configured;

  /// Идет синхронизация
  final bool busy;

  /// Статус операции
  final String status;

  /// Суммы за период
  final int stepsTotal;
  final double sumDistanceMeters;
  final double sumActiveKcal;

  /// Средний пульс за период
  final double? hrAvg;

  /// Разбивки по дням
  final Map<DateTime, double> distanceByDayMeters;
  final Map<DateTime, Duration> distanceTimeByDay;
  final Map<DateTime, double> hrAvgByDay;

  /// Количество тренировок
  final int workouts;

  /// Окна тренировок и метаданные
  final List<DateTimeRange> workoutWindows;
  final List<WorkoutInfo> workoutInfos;

  /// Период синка
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// Сообщение для SnackBar
  final String? snackBarMessage;

  /// Состояние импорта
  final bool importing;
  final int importedCount;
  final int failedCount;

  const ConnectedTrackersState({
    this.configured = false,
    this.busy = false,
    this.status = '',
    this.stepsTotal = 0,
    this.sumDistanceMeters = 0.0,
    this.sumActiveKcal = 0.0,
    this.hrAvg,
    this.distanceByDayMeters = const {},
    this.distanceTimeByDay = const {},
    this.hrAvgByDay = const {},
    this.workouts = 0,
    this.workoutWindows = const [],
    this.workoutInfos = const [],
    this.periodStart,
    this.periodEnd,
    this.snackBarMessage,
    this.importing = false,
    this.importedCount = 0,
    this.failedCount = 0,
  });

  /// Начальное состояние
  static ConnectedTrackersState initial() => const ConnectedTrackersState();

  /// Копирование состояния с обновлением полей
  ConnectedTrackersState copyWith({
    bool? configured,
    bool? busy,
    String? status,
    int? stepsTotal,
    double? sumDistanceMeters,
    double? sumActiveKcal,
    double? hrAvg,
    Map<DateTime, double>? distanceByDayMeters,
    Map<DateTime, Duration>? distanceTimeByDay,
    Map<DateTime, double>? hrAvgByDay,
    int? workouts,
    List<DateTimeRange>? workoutWindows,
    List<WorkoutInfo>? workoutInfos,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? snackBarMessage,
    bool? importing,
    int? importedCount,
    int? failedCount,
    bool clearStatus = false,
    bool clearSnackBar = false,
    bool clearMetrics = false,
  }) {
    return ConnectedTrackersState(
      configured: configured ?? this.configured,
      busy: busy ?? this.busy,
      status: clearStatus ? '' : (status ?? this.status),
      stepsTotal: clearMetrics ? 0 : (stepsTotal ?? this.stepsTotal),
      sumDistanceMeters:
          clearMetrics ? 0.0 : (sumDistanceMeters ?? this.sumDistanceMeters),
      sumActiveKcal:
          clearMetrics ? 0.0 : (sumActiveKcal ?? this.sumActiveKcal),
      hrAvg: clearMetrics ? null : (hrAvg ?? this.hrAvg),
      distanceByDayMeters:
          clearMetrics ? {} : (distanceByDayMeters ?? this.distanceByDayMeters),
      distanceTimeByDay:
          clearMetrics ? {} : (distanceTimeByDay ?? this.distanceTimeByDay),
      hrAvgByDay: clearMetrics ? {} : (hrAvgByDay ?? this.hrAvgByDay),
      workouts: clearMetrics ? 0 : (workouts ?? this.workouts),
      workoutWindows:
          clearMetrics ? [] : (workoutWindows ?? this.workoutWindows),
      workoutInfos: clearMetrics ? [] : (workoutInfos ?? this.workoutInfos),
      periodStart: clearMetrics ? null : (periodStart ?? this.periodStart),
      periodEnd: clearMetrics ? null : (periodEnd ?? this.periodEnd),
      snackBarMessage:
          clearSnackBar ? null : (snackBarMessage ?? this.snackBarMessage),
      importing: importing ?? this.importing,
      importedCount: importedCount ?? this.importedCount,
      failedCount: failedCount ?? this.failedCount,
    );
  }
}

/// Информация о тренировке
@immutable
class WorkoutInfo {
  final DateTime start;
  final DateTime end;
  final String kind;

  const WorkoutInfo({
    required this.start,
    required this.end,
    required this.kind,
  });
}

