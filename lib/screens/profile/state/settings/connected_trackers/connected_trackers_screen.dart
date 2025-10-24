// lib/screens/profile/settings/connected_trackers_screen.dart
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
  // Новый API плагина
  final Health _health = Health();

  // Что читаем для MVP
  static const List<HealthDataType> _types = <HealthDataType>[
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  bool _configured = false;
  bool _busy = false;
  String _status = '';

  // Простая «сводка» по последней синхронизации
  int _workouts = 0;
  double _sumDistanceMeters = 0;
  double _sumActiveKcal = 0;

  // Для безопасного показа сообщений
  String? _snackBarMessage;

  @override
  void initState() {
    super.initState();
    _ensureConfigured(); // Подготовим плагин фоном
  }

  // Безопасный способ показать сообщение
  void _showSnackBar(String message) {
    if (mounted) {
      setState(() {
        _snackBarMessage = message;
      });
    }
  }

  // Конфигурация плагина (обязательна для v13+)
  Future<void> _ensureConfigured() async {
    try {
      await _health.configure();
      if (!mounted) return;
      _configured = true;

      if (Platform.isAndroid) {
        final hasHC = await _health.isHealthConnectAvailable();
        if (!mounted) return;

        if (hasHC == false) {
          // Откроем плей-маркет с установкой Health Connect
          await _health.installHealthConnect();
          if (!mounted) return;
          setState(() {
            _status =
                'Health Connect не был установлен. Установите его и вернитесь.';
          });
        } else {
          setState(() {
            _status = 'Health Connect найден.';
          });
        }
      } else {
        setState(() {
          _status = 'Готово к синхронизации с Apple Здоровьем.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка инициализации: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    // На всякий случай убедимся, что конфиг был
    if (!_configured) {
      await _ensureConfigured();
      if (!mounted) return false;
    }

    final granted = await _health.requestAuthorization(
      _types,
      permissions: _types.map((_) => HealthDataAccess.READ).toList(),
    );
    if (!mounted) return false;

    if (granted) return true;

    // Пользователь отказал — мягко попросим повторить
    if (!mounted) return false;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text('Нужен доступ к данным'),
        content: Text(
          Platform.isIOS
              ? 'Разрешите доступ в системном диалоге, чтобы импортировать тренировки и шаги из Apple Здоровья.'
              : 'Откроется Health Connect — включите разрешения на чтение (тренировки, шаги, пульс и др.).',
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

    // Повторный запрос
    final ok2 = await _health.requestAuthorization(
      _types,
      permissions: _types.map((_) => HealthDataAccess.READ).toList(),
    );
    if (!mounted) return false;

    if (!ok2) {
      // Подскажем, куда смотреть
      if (!mounted) return false;
      final hint = Platform.isIOS
          ? 'Настройки → Здоровье → Доступ к данным → PaceUp.'
          : 'Приложение «Health Connect» → Права доступа → PaceUp.';
      _showSnackBar('Доступ не выдан. Проверьте $hint');
    }
    return ok2;
  }

  Future<void> _fetchLast7Days() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _status = 'Запрашиваю доступ…';
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

      final points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: weekAgo,
        endTime: now,
      );
      if (!mounted) return;

      points.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      final workouts = points
          .where((e) => e.type == HealthDataType.WORKOUT)
          .toList();

      // агрегаты
      final distanceMeters = points
          .where(
            (e) =>
                e.type == HealthDataType.DISTANCE_DELTA &&
                e.value is NumericHealthValue,
          )
          .map((e) => (e.value as NumericHealthValue).numericValue.toDouble())
          .fold<double>(0.0, (a, b) => a + b);

      final activeKcal = points
          .where(
            (e) =>
                e.type == HealthDataType.ACTIVE_ENERGY_BURNED &&
                e.value is NumericHealthValue,
          )
          .map((e) => (e.value as NumericHealthValue).numericValue.toDouble())
          .fold<double>(0.0, (a, b) => a + b);

      setState(() {
        _workouts = workouts.length;
        _sumDistanceMeters = distanceMeters;
        _sumActiveKcal = activeKcal;
        _status =
            'Готово: тренировок ${_workouts}, дистанция ~${_sumDistanceMeters.toStringAsFixed(0)} м, '
            'активные калории ~${_sumActiveKcal.toStringAsFixed(0)} ккал.';
      });

      _showSnackBar(
        'Синк завершён: тренировок $_workouts, '
        '≈${_sumDistanceMeters.toStringAsFixed(0)} м, '
        '≈${_sumActiveKcal.toStringAsFixed(0)} ккал',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка: $e');
      _showSnackBar('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Показываем snack bar если есть сообщение
    if (_snackBarMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_snackBarMessage!)));
          setState(() {
            _snackBarMessage = null;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: const PaceAppBar(title: 'Подключенные трекеры'),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Информационный блок в стиле настройки
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
                        ? 'Синхронизация с Apple Здоровьем. Разрешите доступ, чтобы импортировать тренировки, шаги и пульс.'
                        : 'Синхронизация через Health Connect. Разрешите доступ, чтобы импортировать тренировки, шаги и пульс.',
                    style: AppTextStyles.h13w4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Кнопка синка — ваш глобальный PrimaryButton
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

          if (_status.isNotEmpty)
            _StatusCard(title: 'Статус', message: _status),

          if (_workouts > 0) ...[
            const SizedBox(height: 12),
            _SummaryCard(
              workouts: _workouts,
              meters: _sumDistanceMeters,
              kcal: _sumActiveKcal,
            ),
          ],
        ],
      ),
    );
  }
}

// —————————————————— Мелкие карточки для статуса/сводки ——————————————————

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.message});
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.workouts,
    required this.meters,
    required this.kcal,
  });

  final int workouts;
  final double meters;
  final double kcal;

  @override
  Widget build(BuildContext context) {
    String kmText() {
      if (meters <= 0) return '0 км';
      final km = meters / 1000.0;
      return km >= 100
          ? '${km.toStringAsFixed(0)} км'
          : '${km.toStringAsFixed(1)} км';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          _metric('Тренировки', '$workouts'),
          const SizedBox(width: 16),
          _metric('Дистанция', kmText()),
          const SizedBox(width: 16),
          _metric('Активные ккал', kcal.toStringAsFixed(0)),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.h12w4Ter),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
