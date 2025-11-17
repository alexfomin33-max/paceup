import "package:flutter/material.dart";
import "package:mask_input_formatter/mask_input_formatter.dart"; // 🔹 Для форматирования ввода телефона
import '../../theme/app_theme.dart';
import 'auth_shell.dart';

/// 🔹 Обёртка для экрана создания аккаунта
/// Используется для маршрутизации и возможного расширения функционала
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Возвращаем основной экран регистрации с вводом телефона
    return EnterAccScreen();
  }
}

/// 🔹 Основной экран регистрации с вводом телефона
class EnterAccScreen extends StatelessWidget {
  EnterAccScreen({super.key});

  /// 🔹 Контроллер для поля ввода телефона
  final TextEditingController phoneController = TextEditingController();

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
                  SizedBox(
                    width: double.infinity,
                    child: TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppColors.surface),
                      inputFormatters: [
                        MaskInputFormatter(mask: '+# (###) ###-##-##'),
                      ],
                      decoration: InputDecoration(
                        hintText: "+7 (999) 123-45-67",
                        labelText: "Телефон",
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        hintStyle: const TextStyle(
                          color: AppColors.textPlaceholder,
                        ),
                        labelStyle: const TextStyle(
                          color: AppColors.surface,
                          fontSize: 16,
                        ),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(
                            width: 1.0,
                            color: AppColors.surface,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            width: 1.0,
                            color: AppColors.surface,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            width: 1.0,
                            color: AppColors.surface,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (phoneController.text.length >= 11) {
                          Navigator.pushReplacementNamed(
                            context,
                            '/loginsms',
                            arguments: {'phone': phoneController.text},
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
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
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/home'),
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
