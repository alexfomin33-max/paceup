import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../core/utils/error_handler.dart';
import '../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../core/widgets/primary_button.dart';
import '../../../../../../../core/services/health_sync_service.dart';
import '../utils/workout_importer.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ЭКРАН «HEALTH CONNECT»
// ─────────────────────────────────────────────────────────────────────────────

class HealthConnectScreen extends ConsumerStatefulWidget {
  const HealthConnectScreen({super.key});

  @override
  ConsumerState<HealthConnectScreen> createState() =>
      _HealthConnectScreenState();
}

class _HealthConnectScreenState extends ConsumerState<HealthConnectScreen> {
  // Плагин Health (Health Connect/HealthKit)
  final Health _health = Health();

  // Ровно те типы, которые используем
  static List<HealthDataType> get _types => <HealthDataType>[
        HealthDataType.WORKOUT,
        HealthDataType.STEPS,
        if (Platform.isAndroid) HealthDataType.DISTANCE_DELTA,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        if (Platform.isAndroid) HealthDataType.TOTAL_CALORIES_BURNED,
      ];

  bool _configured = false;
  bool _busy = false;

  // Краткий статус
  String _status = '';

  // Тренировки (счётчик)
  int _workouts = 0;

  // Для потенциальной будущей загрузки маршрутов — окна тренировок и мета
  final List<DateTimeRange> _workoutWindows = [];
  final List<_WorkoutInfo> _workoutInfos = [];

  // Для SnackBar
  String? _snackBarMessage;

  // Для импорта тренировок
  bool _importing = false;
  int _importedCount = 0;
  int _failedCount = 0;

  // Для запроса разрешений и автоматической синхронизации
  bool _requestingPermissions = false;

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
          if (mounted) {
            setState(() => _status = 'Health Connect найден.');
          }
        }
      } else {
        if (mounted) {
          setState(() => _status = 'Готово к синхронизации с Apple Здоровьем.');
        }
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Нужен доступ к данным'),
        content: Text(
          Platform.isIOS
              ? 'Разрешите доступ в системном диалоге, чтобы импортировать тренировки, пульс и ккал.'
              : 'Откроется Health Connect — включите разрешения на чтение (тренировки, дистанция, пульс, активные калории и маршруты). Для маршрутов может потребоваться одноразовое согласие при первой загрузке.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
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

  /// Запрашивает разрешения и автоматически запускает синхронизацию новых тренировок
  Future<void> _requestPermissionsAndSync() async {
    if (_requestingPermissions) return;

    setState(() {
      _requestingPermissions = true;
      _status = 'Запрашиваю разрешения…';
    });

    try {
      final granted = await _requestPermissions();
      if (!mounted) return;

      if (!granted) {
        if (mounted) {
          setState(() {
            _status = 'Разрешения не выданы.';
            _requestingPermissions = false;
          });
        }
        return;
      }

      // ✅ Разрешения выданы — запускаем автоматическую синхронизацию
      if (mounted) {
        setState(() {
          _status = 'Разрешения выданы. Проверяю новые тренировки…';
        });
      }

      final syncService = ref.read(healthSyncServiceProvider);
      final result = await syncService.syncNewWorkouts(ref);

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _status = result.importedCount > 0
              ? 'Импортировано новых тренировок: ${result.importedCount}'
              : 'Новых тренировок не найдено';
          _requestingPermissions = false;
        });
        _showSnackBar(
          result.importedCount > 0
              ? 'Импортировано тренировок: ${result.importedCount}'
              : 'Новых тренировок не найдено',
        );
      } else {
        setState(() {
          _status = 'Ошибка синхронизации: ${result.message}';
          _requestingPermissions = false;
        });
        _showSnackBar('Ошибка: ${result.message}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Ошибка: $e';
        _requestingPermissions = false;
      });
      _showSnackBar(ErrorHandler.format(e));
    }
  }

  // ───────── Синхронизация за 7 дней ─────────

  Future<void> _fetchLast7Days() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _status = 'Запрашиваю доступ…';

      _workouts = 0;

      _workoutWindows.clear();
      _workoutInfos.clear();
    });

    try {
      final ok = await _requestPermissions();
      if (!mounted) return;
      if (!ok) {
        if (mounted) {
          setState(() => _status = 'Доступ к данным не выдан.');
        }
        return;
      }

      if (mounted) {
        setState(() => _status = 'Синхронизация за 7 дней…');
      }
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

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

      // ─────────────────────────────────────────────────────────────────────
      //  ТРЕНИРОВКИ: извлекаем данные из каждой тренировки
      // ─────────────────────────────────────────────────────────────────────
      final workouts =
          byType[HealthDataType.WORKOUT] ?? const <HealthDataPoint>[];
      _workoutWindows.clear();
      _workoutInfos.clear();

      // Для каждой тренировки получаем её данные
      for (final workout in workouts) {
        final wStart = workout.dateFrom;
        final wEnd = workout.dateTo;

        // Определяем вид тренировки
        final v = workout.value;
        String kind = 'Тренировка';
        if (v is WorkoutHealthValue) {
          kind = v.workoutActivityType.name;
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
          } else if (raw.contains('skiing') || raw.contains('ski')) {
            kind = 'Лыжи';
          }
        }

        // Сохраняем информацию о тренировке
        final start = wStart.subtract(const Duration(minutes: 5));
        final end = wEnd.add(const Duration(minutes: 5));
        _workoutWindows.add(DateTimeRange(start: start, end: end));
        _workoutInfos.add(_WorkoutInfo(start: wStart, end: wEnd, kind: kind));
      }

      setState(() {
        _workouts = workouts.length;

        _status =
            'Готово: синх за 7 дней выполнен. Найдено тренировок: ${workouts.length}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка: $e');
      _showSnackBar(ErrorHandler.format(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ───────── Импорт всех найденных тренировок ─────────

  Future<void> _importAllWorkouts() async {
    if (_importing) return;

    setState(() {
      _importing = true;
      _importedCount = 0;
      _failedCount = 0;
      _status = 'Импорт тренировок…';
    });

    try {
      final ok = await _requestPermissions();
      if (!mounted) return;
      if (!ok) {
        if (mounted) {
          setState(() {
            _status = 'Доступ к данным не выдан.';
            _importing = false;
          });
        }
        return;
      }

      // Получаем все тренировки за период
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final workouts = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT],
        startTime: weekAgo,
        endTime: now,
      );

      if (workouts.isEmpty) {
        setState(() {
          _status = 'Тренировки не найдены.';
          _importing = false;
        });
        return;
      }

      // Сортируем по дате начала (старые первыми)
      workouts.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      // Импортируем каждую тренировку
      for (int i = 0; i < workouts.length; i++) {
        if (!mounted) return;
        final workout = workouts[i];
        setState(() {
          _status = 'Импорт тренировки ${i + 1} из ${workouts.length}…';
        });

        final result = await importWorkout(workout, _health, ref);

        if (result.success) {
          _importedCount++;
        } else {
          _failedCount++;
        }

        // Небольшая задержка между импортами, чтобы не перегружать сервер
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!mounted) return;

      setState(() {
        _status =
            'Импорт завершён: успешно $_importedCount, ошибок $_failedCount';
        _importing = false;
      });

      _showSnackBar(
        'Импортировано тренировок: $_importedCount${_failedCount > 0 ? ', ошибок: $_failedCount' : ''}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Ошибка импорта: $e';
        _importing = false;
      });
      _showSnackBar(
        ErrorHandler.formatWithContext(e, context: 'импорте тренировок'),
      );
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

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(
          title: 'Health Connect',
          backgroundColor: AppColors.twinBg,
          showBottomDivider: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                              : 'Синхронизация через Health Connect. Разрешите доступ, чтобы импортировать тренировки, дистанцию, пульс, активные калории и маршруты (бег, велосипед, лыжи, ходьба).',
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

            // Кнопка запроса разрешений
            Center(
              child: PrimaryButton(
                text: _requestingPermissions
                    ? 'Запрос разрешений…'
                    : 'Запрос разрешений',
                onPressed: _requestingPermissions
                    ? () {}
                    : () => _requestPermissionsAndSync(),
                width: 260,
                height: 44,
                isLoading: _requestingPermissions,
              ),
            ),

            const SizedBox(height: 12),

            // Кнопка синка
            Center(
              child: PrimaryButton(
                text: _busy
                    ? 'Синхронизация…'
                    : (Platform.isIOS
                          ? 'Синк из Apple Здоровья'
                          : 'Синк из Health Connect'),
                onPressed: _busy ? () {} : () => _fetchLast7Days(),
                width: 260,
                height: 44,
                isLoading: _busy,
              ),
            ),

            const SizedBox(height: 16),

            // Статус
            if (_status.isNotEmpty)
              _StatusRichCard(
                title: 'Статус',
                message: _status,
              ),
          ],
        ),
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
  });

  final String title;
  final String message;

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
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.h13w4),
        ],
      ),
    );
  }
}
