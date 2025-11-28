import "package:flutter/material.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_shell.dart';
import '../widgets/phone_input_field.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/widgets/form_error_display.dart';

/// 🔹 Обёртка для экрана создания аккаунта
/// Используется для маршрутизации и возможного расширения функционала
class CreateaccScreen extends StatelessWidget {
  const CreateaccScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Возвращаем основной экран регистрации с вводом телефона
    return const AddAccScreen();
  }
}

/// 🔹 Основной экран регистрации с вводом телефона
class AddAccScreen extends ConsumerStatefulWidget {
  const AddAccScreen({super.key});

  @override
  ConsumerState<AddAccScreen> createState() => _AddAccScreenState();
}

class _AddAccScreenState extends ConsumerState<AddAccScreen> {
  /// 🔹 Контроллер для поля ввода телефона
  final TextEditingController phoneController = TextEditingController();

  /// 🔹 Флаг валидности телефона
  bool _isPhoneValid = false;

  @override
  void dispose() {
    // 🔹 Освобождаем контроллер при уничтожении виджета
    phoneController.dispose();
    super.dispose();
  }

  /// 🔹 Обработка нажатия кнопки "Зарегистрироваться"
  void _handleRegister() {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    // 🔹 Проверяем валидность телефона
    if (!_isPhoneValid) {
      ref.read(formStateProvider.notifier).setError('Введите корректный номер телефона');
      return;
    }

    // 🔹 Переходим на экран ввода SMS-кода
    Navigator.pushReplacementNamed(
      context,
      '/addaccsms',
      arguments: {'phone': phoneController.text},
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Получаем высоту клавиатуры для адаптации контента
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // 🔹 Базовый отступ снизу, который уменьшается при появлении клавиатуры
    final bottomPadding = 65.0 - (keyboardHeight * 0.2).clamp(0.0, 40.0);

    return Scaffold(
      // 🔹 Отключаем автоматическую прокрутку Scaffold, используем свою
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AuthShell(
          contentPadding: EdgeInsets.only(
            bottom: bottomPadding,
            left: 40,
            right: 40,
          ),
          child: SingleChildScrollView(
            // 🔹 Прокручиваем контент при появлении клавиатуры
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // 🔹 Используем общий виджет для ввода телефона
              PhoneInputField(
                controller: phoneController,
                onValidationChanged: (isValid) {
                  setState(() {
                    _isPhoneValid = isValid;
                  });
                  // 🔹 Очищаем ошибку при изменении валидности
                  if (isValid) {
                    ref.read(formStateProvider.notifier).clearErrors();
                  }
                },
              ),
              // 🔹 Показываем ошибки, если есть
              Builder(
                builder: (context) {
                  final formState = ref.watch(formStateProvider);
                  if (formState.hasErrors) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FormErrorDisplay(formState: formState),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 20),
              Builder(
                builder: (context) {
                  final formState = ref.watch(formStateProvider);
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: formState.isSubmitting ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getSurfaceColor(context),
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        elevation: 0,
                      ),
                      child: formState.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.textPrimary,
                                ),
                              ),
                            )
                          : const Text(
                              "Зарегистрироваться",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 15),
              const SizedBox(
                width: 250,
                child: Text(
                  "Регистрируясь, вы принимаете Условия предоставления услуг и Политику конфиденциальности",
                  style: TextStyle(fontSize: 12, color: AppColors.surfaceMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final formState = ref.watch(formStateProvider);
                  return SizedBox(
                    width: 100,
                    height: 36,
                    child: TextButton(
                      onPressed: formState.isSubmitting
                          ? null
                          : () => Navigator.pushReplacementNamed(context, '/home'),
                      style: const ButtonStyle(
                        overlayColor: WidgetStatePropertyAll(Colors.transparent),
                        animationDuration: Duration(milliseconds: 0),
                      ),
                      child: const Text(
                        "<-- Назад",
                        style: TextStyle(
                          color: AppColors.surface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
