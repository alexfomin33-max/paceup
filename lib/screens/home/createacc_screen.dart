import "package:flutter/material.dart";
import "package:mask_input_formatter/mask_input_formatter.dart"; // 🔹 Для форматирования ввода телефона
import '../../theme/app_theme.dart';
import 'auth_shell.dart';

/// 🔹 Обёртка для экрана создания аккаунта
/// Используется для маршрутизации и возможного расширения функционала
class CreateaccScreen extends StatelessWidget {
  const CreateaccScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Возвращаем основной экран регистрации с вводом телефона
    return AddAccScreen();
  }
}

/// 🔹 Основной экран регистрации с вводом телефона
class AddAccScreen extends StatelessWidget {
  AddAccScreen({super.key});

  /// 🔹 Контроллер для поля ввода телефона
  final TextEditingController phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AuthShell(
          contentPadding: const EdgeInsets.only(
            bottom: 65,
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
                    Navigator.pushReplacementNamed(
                      context,
                      '/addaccsms',
                      arguments: {'phone': phoneController.text},
                    );
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
                    "Зарегистрироваться",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
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
              SizedBox(
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
            ],
          ),
        ),
      ),
    );
  }
}
