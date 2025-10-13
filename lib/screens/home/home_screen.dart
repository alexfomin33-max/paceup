import 'package:flutter/material.dart';
// import 'createacc_screen.dart'; // 🔹 Можно раскомментировать, если понадобится экран создания аккаунта
import '../../theme/app_theme.dart';
// ✅ ДОБАВЛЕНО: утилита безопасной предзагрузки изображений (1 раз на путь)
import 'auth_shell.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthShell(
        contentPadding: const EdgeInsets.only(bottom: 177, left: 40, right: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildButton(
              text: "Создать аккаунт",
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/createacc'),
            ),
            const SizedBox(height: 20),
            _buildButton(
              text: "Войти",
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
            ),
          ],
        ),
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
            BorderSide(color: AppColors.surface, width: 1),
          ),
          // 🔹 Скругление углов кнопки
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
          ),
          // 🔹 Цвет overlay при нажатии (сделан прозрачным)
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.surface, // 🔹 Цвет текста
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
