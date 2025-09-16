import "package:flutter/material.dart";
import "package:mask_input_formatter/mask_input_formatter.dart"; // 🔹 Для форматирования ввода телефона
import '../theme/app_theme.dart';

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
      body: Stack(
        fit: StackFit.expand, // 🔹 Заполнение всего экрана
        children: [
          // 🔹 Фоновое изображение
          Image.asset("assets/background.png", fit: BoxFit.cover),

          // 🔹 Полупрозрачный черный слой поверх фона
          Container(color: Colors.black.withValues(alpha: 0.5)),

          /// 🔹 Логотип приложения сверху, как на WelcomeScreen
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.11,
              ),
              child: Image.asset(
                "assets/logo_icon.png",
                width: 175,
                height: 175,
                fit: BoxFit.contain,
              ),
            ),
          ),

          /// 🔹 Контент регистрации снизу:
          ///   поле ввода телефона, кнопка "Зарегистрироваться",
          ///   текст условий и кнопка "Назад"
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 65, left: 40, right: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔹 Поле ввода телефона
                  SizedBox(
                    width: double.infinity,
                    child: TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      inputFormatters: [
                        // 🔹 Маска для ввода телефона: +7 (999) 123-45-67
                        MaskInputFormatter(mask: '+# (###) ###-##-##'),
                      ],
                      decoration: InputDecoration(
                        hintText: "+7 (999) 123-45-67",
                        labelText: "Телефон",
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        hintStyle: const TextStyle(color: Colors.grey),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: "Inter",
                        ),
                        // 🔹 Стиль рамки поля
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(
                            width: 1.0,
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.xlarge),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            width: 1.0,
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.xlarge),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            width: 1.0,
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.xlarge),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔹 Кнопка "Войти"
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // 🔹 Переход на экран подтверждения через SMS,
                        // передаём номер телефона
                        Navigator.pushReplacementNamed(
                          context,
                          '/loginsms',
                          arguments: {'phone': phoneController.text},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // фон кнопки
                        foregroundColor: Colors.black, // текст кнопки
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xlarge),
                        ),
                        elevation: 0, // без тени
                      ),
                      child: const Text(
                        "Войти",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: "Inter",
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // 🔹 Кнопка "Назад" без рамки
                  SizedBox(
                    width: 100,
                    height: 36,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/home');
                      },
                      style: const ButtonStyle(
                        overlayColor: WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        animationDuration: Duration(milliseconds: 0),
                      ),
                      child: const Text(
                        "<-- Назад",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Inter",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
