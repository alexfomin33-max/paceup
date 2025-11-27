import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/providers/form_state_provider.dart';
import '../../../../../core/widgets/form_error_display.dart';

/// Экран доступа к данным о здоровье
class HealthDataAccessScreen extends ConsumerStatefulWidget {
  const HealthDataAccessScreen({super.key});

  @override
  ConsumerState<HealthDataAccessScreen> createState() => _HealthDataAccessScreenState();
}

class _HealthDataAccessScreenState extends ConsumerState<HealthDataAccessScreen> {
  bool _hasAccess = false;
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
    final formNotifier = ref.read(formStateProvider.notifier);

    await formNotifier.submitWithLoading(
      () async {
        _health = Health();

        // Проверяем доступность Health на платформе
        bool? available = await _health!.hasPermissions(_types);

        if (!mounted) return;
        setState(() {
          _hasAccess = available ?? false;
        });
      },
    );
  }

  /// Запрос разрешений
  Future<void> _requestPermissions() async {
    if (_health == null) {
      await _initializeHealth();
      if (_health == null) return;
    }

    final formNotifier = ref.read(formStateProvider.notifier);

    await formNotifier.submit(
      () async {
        // Проверяем текущий статус
        bool? hasPermissions = await _health!.hasPermissions(_types);

        if (hasPermissions == true) {
          if (!mounted) return;
          setState(() {
            _hasAccess = true;
          });
          return;
        }

        // Запрашиваем разрешения
        final bool granted = await _health!.requestAuthorization(_types);

        if (!mounted) return;
        setState(() {
          _hasAccess = granted;
        });

        if (!granted) {
          // Показываем диалог с инструкциями
          if (mounted) {
            await showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Нужен доступ к данным'),
                content: Text(
                  Platform.isIOS
                      ? 'Разрешите доступ к данным о здоровье в настройках iPhone:\n\nНастройки → Конфиденциальность → Здоровье → PaceUp'
                      : 'Откройте Health Connect и предоставьте разрешения на чтение данных о тренировках, шагах, пульсе и калориях.',
                ),
                actions: [
                  PrimaryButton(
                    text: 'Понятно',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(formStateProvider);
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Доступ к данным'),
        body: SafeArea(
          child: formState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                )
              : formState.hasErrors
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        FormErrorDisplay(formState: formState),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: 'Повторить',
                          onPressed: () => _initializeHealth(),
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
                        color: AppColors.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.info,
                                size: 20,
                                color: AppColors.brandPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Что это?',
                                style: AppTextStyles.h14w6.copyWith(
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Разрешение на доступ к данным о здоровье позволяет приложению импортировать ваши тренировки, шаги, пульс и калории из системных приложений Health (iOS) или Health Connect (Android).',
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
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
                    Builder(
                      builder: (context) {
                        final formState = ref.watch(formStateProvider);
                        return Center(
                          child: PrimaryButton(
                            text: _hasAccess
                                ? 'Обновить разрешения'
                                : 'Запросить доступ',
                            onPressed: () => _requestPermissions(),
                            isLoading: formState.isSubmitting,
                            enabled: !formState.isSubmitting,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Инструкции
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceMutedColor(context),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Как предоставить доступ:',
                            style: AppTextStyles.h14w6.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Platform.isIOS
                                ? '1. Нажмите "Запросить доступ"\n2. В системном диалоге выберите типы данных\n3. Разрешите доступ к выбранным данным'
                                : '1. Нажмите "Запросить доступ"\n2. Откроется Health Connect\n3. Выберите типы данных и разрешите доступ',
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
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
