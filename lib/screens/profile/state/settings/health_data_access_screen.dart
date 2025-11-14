import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart';
import '../../../../../widgets/interactive_back_swipe.dart';
import '../../../../../widgets/primary_button.dart';

/// Экран доступа к данным о здоровье
class HealthDataAccessScreen extends StatefulWidget {
  const HealthDataAccessScreen({super.key});

  @override
  State<HealthDataAccessScreen> createState() => _HealthDataAccessScreenState();
}

class _HealthDataAccessScreenState extends State<HealthDataAccessScreen> {
  bool _isLoading = false;
  bool _hasAccess = false;
  String? _error;
  Health? _health;

  // Типы данных для запроса
  final List<HealthDataType> _types = [
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  @override
  void initState() {
    super.initState();
    _initializeHealth();
  }

  /// Инициализация Health
  Future<void> _initializeHealth() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _health = Health();

      // Проверяем доступность Health на платформе
      bool? available = await _health!.hasPermissions(_types);

      if (!mounted) return;

      setState(() {
        _hasAccess = available ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Запрос разрешений
  Future<void> _requestPermissions() async {
    if (_health == null) {
      await _initializeHealth();
      if (_health == null) return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Проверяем текущий статус
      bool? hasPermissions = await _health!.hasPermissions(_types);

      if (hasPermissions == true) {
        if (!mounted) return;
        setState(() {
          _hasAccess = true;
          _isLoading = false;
        });
        return;
      }

      // Запрашиваем разрешения
      final bool? granted = await _health!.requestAuthorization(_types);

      if (!mounted) return;

      final bool isGranted = granted ?? false;
      setState(() {
        _hasAccess = isGranted;
        _isLoading = false;
      });

      if (!isGranted) {
        // Показываем диалог с инструкциями
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Нужен доступ к данным'),
              content: Text(
                Platform.isIOS
                    ? 'Разрешите доступ к данным о здоровье в настройках iPhone:\n\nНастройки → Конфиденциальность → Здоровье → PaceUp'
                    : 'Откройте Health Connect и предоставьте разрешения на чтение данных о тренировках, шагах, пульсе и калориях.',
              ),
              actions: [
                PrimaryButton(
                  text: 'Понятно',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const PaceAppBar(title: 'Доступ к данным'),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                )
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h14w4.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: 'Повторить',
                          onPressed: _initializeHealth,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    // Информационная карточка
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.info,
                                size: 20,
                                color: AppColors.brandPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text('Что это?', style: AppTextStyles.h14w6),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Разрешение на доступ к данным о здоровье позволяет приложению импортировать ваши тренировки, шаги, пульс и калории из системных приложений Health (iOS) или Health Connect (Android).',
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Статус доступа
                    Container(
                      decoration: BoxDecoration(
                        color: _hasAccess
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: _hasAccess
                              ? AppColors.success
                              : AppColors.warning,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _hasAccess
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.xmark_circle_fill,
                            size: 24,
                            color: _hasAccess
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _hasAccess
                                  ? 'Доступ предоставлен'
                                  : 'Доступ не предоставлен',
                              style: AppTextStyles.h14w5.copyWith(
                                color: _hasAccess
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Кнопка запроса разрешений
                    Center(
                      child: PrimaryButton(
                        text: _hasAccess
                            ? 'Обновить разрешения'
                            : 'Запросить доступ',
                        onPressed: _requestPermissions,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Инструкции
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Как предоставить доступ:',
                            style: AppTextStyles.h14w6,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Platform.isIOS
                                ? '1. Нажмите "Запросить доступ"\n2. В системном диалоге выберите типы данных\n3. Разрешите доступ к выбранным данным'
                                : '1. Нажмите "Запросить доступ"\n2. Откроется Health Connect\n3. Выберите типы данных и разрешите доступ',
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
