import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/utils/error_handler.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/widgets/primary_button.dart';
import '../../../../../../core/providers/form_state_provider.dart';
import '../../../../../../core/widgets/form_error_display.dart';

import 'package:local_auth/local_auth.dart';

// Проверка доступности local_auth на платформе
bool get _isLocalAuthAvailable {
  try {
    return !Platform.isMacOS && !Platform.isWindows && !Platform.isLinux;
  } catch (_) {
    return false;
  }
}

/// Экран настройки биометрии (Face ID / Touch ID / код-пароль)
class BiometricScreen extends ConsumerStatefulWidget {
  const BiometricScreen({super.key});

  @override
  ConsumerState<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends ConsumerState<BiometricScreen> {
  late final LocalAuthentication _localAuth;
  bool _isEnabled = false;
  bool _isAvailable = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    if (_isLocalAuthAvailable) {
      _localAuth = LocalAuthentication();
    }
    _checkAvailability();
    _loadSettings();
  }

  /// Проверка доступности биометрии
  Future<void> _checkAvailability() async {
    final formNotifier = ref.read(formStateProvider.notifier);

    await formNotifier.submitWithLoading(
      () async {
        // Проверяем доступность платформы
        if (!_isLocalAuthAvailable) {
          throw Exception(
            Platform.isMacOS
                ? 'Биометрия недоступна на macOS. Используйте iOS или Android устройство.'
                : 'Биометрия недоступна на этой платформе.',
          );
        }

        final canCheckBiometrics = await _localAuth.canCheckBiometrics;
        final isDeviceSupported = await _localAuth.isDeviceSupported();

        if (canCheckBiometrics && isDeviceSupported) {
          final availableBiometrics = await _localAuth.getAvailableBiometrics();

          if (!mounted) return;
          setState(() {
            _isAvailable = availableBiometrics.isNotEmpty;
            _availableBiometrics = availableBiometrics;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _isAvailable = false;
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        final errorMsg = formState.error ?? ErrorHandler.format(error);
        if (errorMsg.contains('MissingPluginException') ||
            errorMsg.contains('No implementation found')) {
          ref.read(formStateProvider.notifier).setError(
                'Плагин биометрии недоступен. Перезапустите приложение после установки пакетов.',
              );
        }
        setState(() {
          _isAvailable = false;
        });
      },
    );
  }

  /// Загрузка сохранённых настроек
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('biometric_enabled') ?? false;

      if (!mounted) return;

      setState(() {
        _isEnabled = enabled;
      });
    } catch (e) {
      // Игнорируем ошибки загрузки
    }
  }

  /// Сохранение настроек
  Future<void> _saveSettings(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', enabled);
    } catch (e) {
      // Игнорируем ошибки сохранения
    }
  }

  /// Включение/выключение биометрии
  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Включаем биометрию - нужно пройти аутентификацию
      await _authenticateAndEnable();
    } else {
      // Выключаем биометрию
      setState(() {
        _isEnabled = false;
      });
      await _saveSettings(false);
    }
  }

  /// Аутентификация и включение биометрии
  Future<void> _authenticateAndEnable() async {
    if (!_isAvailable || !_isLocalAuthAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Биометрия недоступна на этом устройстве'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final formNotifier = ref.read(formStateProvider.notifier);

    await formNotifier.submit(
      () async {
        final authenticated = await _localAuth.authenticate(
          localizedReason:
              'Подтвердите включение биометрии для защиты приложения',
          /*options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),*/
        );

        if (!authenticated) {
          throw Exception('Аутентификация не пройдена');
        }
      },
      onSuccess: () async {
        if (!mounted) return;
        setState(() {
          _isEnabled = true;
        });
        await _saveSettings(true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Биометрия включена'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        final errorMsg = formState.error ?? ErrorHandler.format(error);
        if (errorMsg.contains('MissingPluginException') ||
            errorMsg.contains('No implementation found')) {
          ref.read(formStateProvider.notifier).setError(
                'Плагин биометрии недоступен. Перезапустите приложение после установки пакетов.',
              );
        }
        setState(() {
          _isEnabled = false;
        });
      },
    );
  }

  /// Получение названия типа биометрии
  String _getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return Platform.isIOS ? 'Touch ID' : 'Отпечаток пальца';
      case BiometricType.iris:
        return 'Радужная оболочка';
      case BiometricType.strong:
        return 'Сильная биометрия';
      case BiometricType.weak:
        return 'Слабая биометрия';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(formStateProvider);
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Код-пароль и Face ID'),
        body: SafeArea(
          child: formState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                )
              : formState.hasErrors && !_isAvailable
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
                          onPressed: _checkAvailability,
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
                        border: Border.all(
                          color: AppColors.getBorderColor(context),
                          width: 1,
                        ),
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
                            'Биометрическая защита позволяет использовать Face ID, Touch ID или код-пароль для быстрого входа в приложение. Ваши данные защищены системной аутентификацией устройства.',
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Статус доступности
                    if (!_isAvailable)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.warning,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.info,
                              size: 24,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Биометрия недоступна на этом устройстве',
                                style: AppTextStyles.h14w5.copyWith(
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_isAvailable) ...[
                      const SizedBox(height: 24),

                      // Доступные типы биометрии
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Доступные методы:',
                              style: AppTextStyles.h14w6.copyWith(
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._availableBiometrics.map(
                              (type) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      type == BiometricType.face
                                          ? CupertinoIcons.person_fill
                                          : CupertinoIcons.lock_fill,
                                      size: 20,
                                      color: AppColors.brandPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getBiometricTypeName(type),
                                      style: AppTextStyles.h14w4.copyWith(
                                        color: AppColors.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Переключатель
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Биометрическая защита',
                                    style: AppTextStyles.h14w6.copyWith(
                                      color: AppColors.getTextPrimaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isEnabled ? 'Включена' : 'Выключена',
                                    style: AppTextStyles.h13w4.copyWith(
                                      color: AppColors.getTextSecondaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final formState = ref.watch(formStateProvider);
                                return CupertinoSwitch(
                                  value: _isEnabled,
                                  onChanged: formState.isSubmitting
                                      ? null
                                      : (value) => _toggleBiometric(value),
                                  activeTrackColor: AppColors.brandPrimary,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
