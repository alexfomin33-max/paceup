import 'package:flutter/material.dart';
// import 'createacc_screen.dart'; // Если понадобится экран создания аккаунта
import '../theme/app_theme.dart';

/// 🔹 Главный экран приложения
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Возвращаем приветственный экран
    return const WelcomeScreen();
  }
}

/// 🔹 Экран приветствия / welcome screen
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Используем Stack, чтобы накладывать элементы друг на друга
      body: Stack(
        fit: StackFit.expand, // Заставляем Stack занимать весь экран
        children: [
          // 🔹 Фоновое изображение
          Image.asset("assets/background.png", fit: BoxFit.cover),

          // 🔹 Полупрозрачный черный слой поверх фона для затемнения
          Container(color: Colors.black.withValues(alpha: 0.5)),

          // 🔹 Логотип в верхней части экрана
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top:
                    MediaQuery.of(context).size.height *
                    0.11, // Смещение сверху ~11% высоты экрана
              ),
              child: Image.asset(
                "assets/logo_icon.png",
                width: 175,
                height: 175,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 🔹 Нижняя часть экрана: кнопки "Создать аккаунт" и "Войти"
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 177, left: 40, right: 40),
              child: Column(
                mainAxisSize: MainAxisSize
                    .min, // Колонка занимает минимальное пространство по вертикали
                children: [
                  // Кнопка "Создать аккаунт"
                  _buildButton(
                    text: "Создать аккаунт",
                    onPressed: () {
                      // Переход на экран создания аккаунта через routes
                      Navigator.pushReplacementNamed(context, '/createacc');

                      /*
                      // Альтернативный вариант с MaterialPageRoute
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateaccScreen(),
                        ),
                      );
                      */
                    },
                  ),

                  const SizedBox(height: 20), // Отступ между кнопками
                  // Кнопка "Войти"
                  _buildButton(
                    text: "Войти",
                    onPressed: () {
                      // Здесь можно добавить переход на экран входа
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Универсальный метод для создания кнопки с заданным текстом и действием
  Widget _buildButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity, // Кнопка занимает всю доступную ширину
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          // Отступ внутри кнопки
          padding: WidgetStatePropertyAll(
            const EdgeInsets.symmetric(vertical: 15),
          ),
          // Рамка кнопки
          side: WidgetStatePropertyAll(
            const BorderSide(color: Colors.white, width: 1),
          ),
          // Скругление углов кнопки
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xlarge),
            ),
          ),
          // Цвет оверлея при нажатии (сделан прозрачным)
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: "Inter",
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
