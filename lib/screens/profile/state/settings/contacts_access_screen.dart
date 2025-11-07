import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart';
import '../../../../../widgets/interactive_back_swipe.dart';

/// Экран доступа к контактам
class ContactsAccessScreen extends StatefulWidget {
  const ContactsAccessScreen({super.key});

  @override
  State<ContactsAccessScreen> createState() => _ContactsAccessScreenState();
}

class _ContactsAccessScreenState extends State<ContactsAccessScreen> {
  bool _isLoading = false;
  bool _hasAccess = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  /// Проверка текущего статуса разрешения
  Future<void> _checkPermission() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final status = await ph.Permission.contacts.status;
      
      if (!mounted) return;
      
      setState(() {
        _hasAccess = status.isGranted;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Если плагин недоступен, показываем дружелюбное сообщение
      final errorMsg = e.toString();
      if (errorMsg.contains('MissingPluginException') || 
          errorMsg.contains('No implementation found')) {
        setState(() {
          _error = 'Плагин разрешений недоступен. Перезапустите приложение.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  /// Запрос разрешения на доступ к контактам
  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final status = await ph.Permission.contacts.request();
      
      if (!mounted) return;
      
      setState(() {
        _hasAccess = status.isGranted;
        _isLoading = false;
      });

      if (!status.isGranted) {
        // Показываем диалог с инструкциями
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Нужен доступ к контактам'),
              content: Text(
                Platform.isIOS
                    ? 'Разрешите доступ к контактам в настройках iPhone:\n\nНастройки → Конфиденциальность → Контакты → PaceUp'
                    : 'Разрешите доступ к контактам в настройках Android:\n\nНастройки → Приложения → PaceUp → Разрешения → Контакты',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Понятно'),
                ),
                if (status.isPermanentlyDenied)
                  TextButton(
                    onPressed: () {
                      ph.openAppSettings();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Открыть настройки'),
                  ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      // Если плагин недоступен, показываем дружелюбное сообщение
      final errorMsg = e.toString();
      if (errorMsg.contains('MissingPluginException') || 
          errorMsg.contains('No implementation found')) {
        setState(() {
          _error = 'Плагин разрешений недоступен. Перезапустите приложение после установки пакетов.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const PaceAppBar(title: 'Контакты'),
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
                            ElevatedButton(
                              onPressed: _checkPermission,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Повторить'),
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
                                'Разрешение на доступ к контактам позволяет приложению искать друзей по номеру телефона из вашей телефонной книги. Мы не сохраняем и не передаём ваши контакты третьим лицам.',
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _requestPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                            child: Text(
                              _hasAccess
                                  ? 'Обновить разрешения'
                                  : 'Запросить доступ',
                              style: AppTextStyles.h16w6,
                            ),
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
                              const Text(
                                'Как предоставить доступ:',
                                style: AppTextStyles.h14w6,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                Platform.isIOS
                                    ? '1. Нажмите "Запросить доступ"\n2. В системном диалоге разрешите доступ к контактам\n3. Приложение сможет искать друзей по номерам из вашей телефонной книги'
                                    : '1. Нажмите "Запросить доступ"\n2. В системном диалоге разрешите доступ к контактам\n3. Приложение сможет искать друзей по номерам из вашей телефонной книги',
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

