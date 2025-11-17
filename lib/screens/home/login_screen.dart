import "package:flutter/material.dart";
import '../../theme/app_theme.dart';
import 'auth_shell.dart';
import '../../widgets/auth/phone_input_field.dart';

/// 🔹 Обёртка для экрана входа
/// Используется для маршрутизации и возможного расширения функционала
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Возвращаем основной экран входа с вводом телефона
    return const EnterAccScreen();
  }
}

/// 🔹 Основной экран входа с вводом телефона
class EnterAccScreen extends StatefulWidget {
  const EnterAccScreen({super.key});

  @override
  State<EnterAccScreen> createState() => _EnterAccScreenState();
}

class _EnterAccScreenState extends State<EnterAccScreen> {
  /// 🔹 Контроллер для поля ввода телефона
  final TextEditingController phoneController = TextEditingController();

  /// 🔹 Флаг валидности телефона
  bool _isPhoneValid = false;

  /// 🔹 Флаг загрузки (блокирует повторные нажатия)
  bool _isLoading = false;

  /// 🔹 Сообщение об ошибке (если есть)
  String? _errorMessage;

  @override
  void dispose() {
    // 🔹 Освобождаем контроллер при уничтожении виджета
    phoneController.dispose();
    super.dispose();
  }

  /// 🔹 Обработка нажатия кнопки "Войти"
  void _handleLogin() {
    // 🔹 Проверяем валидность телефона
    if (!_isPhoneValid) {
      setState(() {
        _errorMessage = 'Введите корректный номер телефона';
      });
      return;
    }

    // 🔹 Блокируем повторные нажатия
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 🔹 Переходим на экран ввода SMS-кода
    Navigator.pushReplacementNamed(
      context,
      '/loginsms',
      arguments: {'phone': phoneController.text},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // 🔹 Основной контент: поле ввода и кнопка "Войти"
            AuthShell(
              contentPadding: const EdgeInsets.only(
                bottom: 177,
                left: 40,
                right: 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔹 Используем общий виджет для ввода телефона
                  PhoneInputField(
                    controller: phoneController,
                    onValidationChanged: (isValid) {
                      setState(() {
                        _isPhoneValid = isValid;
                        // 🔹 Очищаем ошибку при изменении валидности
                        if (isValid) _errorMessage = null;
                      });
                    },
                  ),
                  // 🔹 Показываем ошибку, если есть
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    SelectableText.rich(
                      TextSpan(
                        text: _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
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
                              "Войти",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            // 🔹 Кнопка "Назад" позиционируется в том же месте, что и в createacc_screen.dart
            // В createacc_screen.dart: contentPadding bottom = 65, кнопка внизу Column, центрирована
            // Кнопка находится на высоте contentPadding (65px) от нижнего края и центрирована по горизонтали
            Positioned(
              bottom: 65, // такой же bottom как contentPadding в createacc_screen
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 100,
                  height: 36,
                  child: TextButton(
                    onPressed: _isLoading
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
