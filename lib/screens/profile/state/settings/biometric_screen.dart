import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart';
import '../../../../../widgets/interactive_back_swipe.dart';
import '../../../../../widgets/primary_button.dart';

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
class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  late final LocalAuthentication _localAuth;
  bool _isLoading = false;
  bool _isEnabled = false;
  bool _isAvailable = false;
  String? _error;
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Проверяем доступность платформы
    if (!_isLocalAuthAvailable) {
      if (!mounted) return;
      setState(() {
        _isAvailable = false;
        _isLoading = false;
        _error = Platform.isMacOS 
            ? 'Биометрия недоступна на macOS. Используйте iOS или Android устройство.'
            : 'Биометрия недоступна на этой платформе.';
      });
      return;
    }

    try {
      if (!_isLocalAuthAvailable) {
        if (!mounted) return;
        setState(() {
          _isAvailable = false;
          _isLoading = false;
        });
        return;
      }
      
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!mounted) return;

      if (canCheckBiometrics && isDeviceSupported) {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        
        setState(() {
          _isAvailable = availableBiometrics.isNotEmpty;
          _availableBiometrics = availableBiometrics;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isAvailable = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Если плагин недоступен, показываем дружелюбное сообщение
      final errorMsg = e.toString();
      if (errorMsg.contains('MissingPluginException') || 
          errorMsg.contains('No implementation found')) {
        setState(() {
          _error = 'Плагин биометрии недоступен. Перезапустите приложение после установки пакетов.';
          _isAvailable = false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = errorMsg;
          _isAvailable = false;
          _isLoading = false;
        });
      }
    }
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

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Подтвердите включение биометрии для защиты приложения',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      if (authenticated) {
        setState(() {
          _isEnabled = true;
          _isLoading = false;
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
      } else {
        setState(() {
          _isEnabled = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Если плагин недоступен, показываем дружелюбное сообщение
      final errorMsg = e.toString();
      if (errorMsg.contains('MissingPluginException') || 
          errorMsg.contains('No implementation found')) {
        setState(() {
          _error = 'Плагин биометрии недоступен. Перезапустите приложение после установки пакетов.';
          _isEnabled = false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = errorMsg;
          _isEnabled = false;
          _isLoading = false;
        });
      }
    }
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
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const PaceAppBar(title: 'Код-пароль и Face ID'),
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
                            const Icon(
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
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.info,
                                    size: 20,
                                    color: AppColors.brandPrimary,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Что это?',
                                    style: AppTextStyles.h14w6,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Биометрическая защита позволяет использовать Face ID, Touch ID или код-пароль для быстрого входа в приложение. Ваши данные защищены системной аутентификацией устройства.',
                                style: AppTextStyles.h14w4.copyWith(
                                  color: AppColors.textSecondary,
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
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Доступные методы:',
                                  style: AppTextStyles.h14w6,
                                ),
                                const SizedBox(height: 12),
                                ..._availableBiometrics.map((type) => Padding(
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
                                            style: AppTextStyles.h14w4,
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Переключатель
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: AppColors.border,
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
                                      const Text(
                                        'Биометрическая защита',
                                        style: AppTextStyles.h14w6,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _isEnabled
                                            ? 'Включена'
                                            : 'Выключена',
                                        style: AppTextStyles.h13w4.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                CupertinoSwitch(
                                  value: _isEnabled,
                                  onChanged: _isLoading
                                      ? null
                                      : (value) => _toggleBiometric(value),
                                  activeTrackColor: AppColors.brandPrimary,
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

