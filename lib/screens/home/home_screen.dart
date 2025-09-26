import 'package:flutter/material.dart';
// import 'createacc_screen.dart'; // 🔹 Можно раскомментировать, если понадобится экран создания аккаунта
import '../../theme/app_theme.dart';
// ✅ ДОБАВЛЕНО: утилита безопасной предзагрузки изображений (1 раз на путь)
import '../../utils/image_precache.dart';

/// 🔹 Главный экран приложения
/// Этот экран выступает контейнером для WelcomeScreen, который пользователь видит при запуске
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Возвращаем приветственный экран
    return const WelcomeScreen();
  }
}

/// 🔹 Экран приветствия / Welcome Screen
/// Показывается при первом запуске приложения с логотипом и кнопками входа/регистрации
// ⬇ изменено: был StatelessWidget → стал StatefulWidget,
// чтобы корректно предзагружать фон через didChangeDependencies()
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ ДОБАВЛЕНО: предзагружаем фон один раз (если уже предзагружен — повтор не делает ничего)
    ImagePrecache.precacheOnce(context, 'assets/background.webp');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔹 Используем Stack, чтобы накладывать элементы друг на друга
      body: Stack(
        fit: StackFit.expand, // 🔹 Stack занимает весь экран
        children: [
          // 🔹 Фоновое изображение приложения
          Image.asset(
            "assets/background.webp",
            fit: BoxFit.cover,
            // ✅ Рекомендовано: дешевле для графики при масштабировании
            filterQuality: FilterQuality.low,
          ),

          // 🔹 Полупрозрачный черный слой для затемнения фона
          Container(color: Colors.black.withValues(alpha: 0.5)),

          // 🔹 Логотип приложения сверху
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

          // 🔹 Нижняя часть экрана с кнопками "Создать аккаунт" и "Войти"
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 177,
                left: 40,
                right: 40,
              ), // Отступ снизу и по бокам
              child: Column(
                mainAxisSize: MainAxisSize
                    .min, // 🔹 Колонка занимает минимум по вертикали
                children: [
                  // 🔹 Кнопка "Создать аккаунт"
                  _buildButton(
                    text: "Создать аккаунт",
                    onPressed: () {
                      // 🔹 Переход на экран создания аккаунта через именованные маршруты
                      Navigator.pushReplacementNamed(context, '/createacc');

                      /*
                      // 🔹 Альтернативный вариант с MaterialPageRoute
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateaccScreen(),
                        ),
                      );
                      */
                    },
                  ),

                  const SizedBox(height: 20), // 🔹 Отступ между кнопками
                  // 🔹 Кнопка "Войти"
                  _buildButton(
                    text: "Войти",
                    onPressed: () {
                      // 🔹 Переход на экран входа
                      Navigator.pushReplacementNamed(context, '/login');
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

  /// 🔹 Универсальный метод для создания кнопки
  /// Позволяет использовать одинаковый стиль для всех кнопок
  Widget _buildButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity, // 🔹 Кнопка занимает всю доступную ширину
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          // 🔹 Отступы внутри кнопки
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 15),
          ),
          // 🔹 Рамка кнопки
          side: const WidgetStatePropertyAll(
            BorderSide(color: Colors.white, width: 1),
          ),
          // 🔹 Скругление углов кнопки
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xlarge),
            ),
          ),
          // 🔹 Цвет overlay при нажатии (сделан прозрачным)
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white, // 🔹 Цвет текста
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
