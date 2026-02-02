import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'createacc_screen.dart'; // 🔹 Можно раскомментировать, если понадобится экран создания аккаунта
import '../../../core/theme/app_theme.dart';

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
// ⬇ изменено: был StatelessWidget → стал ConsumerStatefulWidget,
// чтобы корректно предзагружать фон через didChangeDependencies()
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.darkSurface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = MediaQuery.of(context).size;
            return Stack(
              fit: StackFit.expand,
              children: [
                // ─────────── Фоновая картинка (заполняет весь экран включая системные области) ───────────
                Positioned.fill(
                  child: Opacity(
                    opacity: 1.0,
                    child: Image.asset(
                      'assets/back.jpg',
                      width: screenSize.width,
                      height: screenSize.height,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                ),
                // ─────────── Темный градиент поверх фоновой картинки ───────────
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(
                            alpha: 0.6,
                          ), // Сверху менее прозрачный (темнее)
                          Colors.black.withValues(
                            alpha: 0.2,
                          ), // Снизу более прозрачный (светлее)
                        ],
                      ),
                    ),
                  ),
                ),
                // ─────────── Контент ───────────
                Stack(
                  fit: StackFit.expand,
                  children: [
                    // ─────────── Логотип на 1/3 от высоты экрана ───────────
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).size.height * 0.085,
                        ),
                        child: Opacity(
                          opacity: 0.9,
                          child: Image.asset(
                            'assets/white_logo.png',
                            width: 180,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                    // ─────────── Кнопки внизу ───────────
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).size.height * 0.1,
                          left: MediaQuery.of(context).size.width * 0.1,
                          right: MediaQuery.of(context).size.width * 0.1,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // _buildButton(
                            //   text: "Создать аккаунт",
                            //   onPressed: () => Navigator.pushReplacementNamed(
                            //     context,
                            //     '/createacc',
                            //   ),
                            // ),
                            // const SizedBox(height: 20),
                            _buildButton(
                              text: "Создать аккаунт / Войти",
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                '/login',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 🔹 Универсальный метод для создания кнопки
  /// Позволяет использовать одинаковый стиль для всех кнопок
  Widget _buildButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity, // 🔹 Кнопка занимает всю доступную ширину
      child: Opacity(
        opacity: 1.0,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ButtonStyle(
            // 🔹 Фон кнопки цвета surface
            backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
            // 🔹 Отступы внутри кнопки
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 15),
            ),
            // 🔹 Скругление углов кнопки
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
            ),
            // 🔹 Убираем тень
            elevation: const WidgetStatePropertyAll(0),
            // 🔹 Цвет overlay при нажатии (сделан прозрачным)
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black, // 🔹 Цвет текста (черный на светлом фоне)
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
