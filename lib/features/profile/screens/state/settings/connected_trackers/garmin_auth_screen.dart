import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/widgets/primary_button.dart';
import '../../../../../../core/utils/error_handler.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../core/services/garmin_sync_service.dart';

/// 🔹 Экран авторизации Garmin Connect
/// Позволяет пользователю ввести email и пароль для подключения Garmin аккаунта
class GarminAuthScreen extends ConsumerStatefulWidget {
  const GarminAuthScreen({super.key});

  @override
  ConsumerState<GarminAuthScreen> createState() => _GarminAuthScreenState();
}

class _GarminAuthScreenState extends ConsumerState<GarminAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 🔹 Выполнение авторизации
  Future<void> _authorize() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final garminService = ref.read(garminSyncServiceProvider);
      final response = await garminService.authorize(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        if (response['success'] == true) {
          // Успешная авторизация
          Navigator.of(context).pop(true); // Возвращаем true для обновления статуса
        } else {
          // Ошибка авторизации
          final message = response['message'] ?? 'Ошибка авторизации';
          _showError(message);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(ErrorHandler.format(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 🔹 Показ ошибки
  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Ошибка авторизации'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Подключение Garmin'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─────────── Информационный блок ───────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.info_circle_fill,
                              color: AppColors.brandPrimary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Авторизация Garmin Connect',
                              style: AppTextStyles.h14w6,
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Введите email и пароль от вашего аккаунта Garmin Connect. '
                          'Данные используются только для синхронизации тренировок и не сохраняются на сервере.',
                          style: AppTextStyles.h13w4,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─────────── Поле Email ───────────
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'example@mail.com',
                      prefixIcon: const Icon(CupertinoIcons.mail),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите email';
                      }
                      if (!value.contains('@')) {
                        return 'Введите корректный email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // ─────────── Поле Пароль ───────────
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    enabled: !_isLoading,
                    onFieldSubmitted: (_) => _authorize(),
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      hintText: 'Введите пароль',
                      prefixIcon: const Icon(CupertinoIcons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? CupertinoIcons.eye_slash
                              : CupertinoIcons.eye,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите пароль';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // ─────────── Кнопка авторизации ───────────
                  PrimaryButton(
                    text: _isLoading ? 'Авторизация…' : 'Подключить',
                    onPressed: () {
                      if (!_isLoading) {
                        _authorize();
                      }
                    },
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
