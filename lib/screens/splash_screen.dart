import 'package:flutter/material.dart';
import '../service/auth_service.dart';
import '../theme/colors.dart';

/// 🔹 SplashScreen — стартовый экран приложения, отображается при запуске
/// Используется для проверки авторизации пользователя и перенаправления
/// на соответствующий экран (HomeScreen или HomeShell)
///
/// ⚡ ОПТИМИЗАЦИЯ:
/// - Минимальное время показа splash screen (минимум 200ms для плавности)
/// - Немедленный переход без дополнительных задержек
/// - Предзагрузка данных происходит в самих экранах (offline-first подход)
/// - Плавная fade-in анимация логотипа (800ms) для профессионального вида
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

/// 🔹 State для SplashScreen
/// Содержит логику проверки авторизации и навигации
/// SingleTickerProviderStateMixin — для анимации fade-in логотипа
class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 🔹 Сервис для работы с авторизацией (проверка токена, получение userId)
  final AuthService auth = AuthService();

  // ────────────────────────── Анимация ──────────────────────────
  /// 🔹 Контроллер анимации для fade-in эффекта логотипа
  late AnimationController _animationController;

  /// 🔹 Анимация прозрачности (от 0.0 до 1.0)
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // ────────────────────────── Инициализация анимации ──────────────────────────
    // 🔹 Создаем контроллер анимации с длительностью 800ms
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 🔹 Создаем плавную анимацию прозрачности с ease-in кривой
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // 🔹 Запускаем анимацию fade-in
    _animationController.forward();

    // ────────────────────────── Проверка авторизации ──────────────────────────
    _checkAuth(); // 🔹 Проверяем авторизацию сразу после инициализации экрана
  }

  @override
  void dispose() {
    // 🔹 Очищаем ресурсы контроллера анимации
    _animationController.dispose();
    super.dispose();
  }

  /// 🔹 Метод проверки авторизации
  /// 1. Проверяет, есть ли валидный токен
  /// 2. Если авторизован, получает userId
  /// 3. Перенаправляет на соответствующий экран
  ///
  /// ⚡ ОПТИМИЗАЦИЯ:
  /// - Задержка 1000ms для комфортной загрузки данных и плавной анимации
  /// - Параллельная проверка авторизации и минимального времени показа
  /// - Предотвращает визуальный микролаг между splash и загруженной лентой
  Future<void> _checkAuth() async {
    // Запускаем проверку авторизации и минимальное время показа параллельно
    final results = await Future.wait([
      auth.isAuthorized(),
      Future.delayed(
        const Duration(milliseconds: 1000),
      ), // задержка для завершения анимации и комфортного показа логотипа
    ]);

    final bool authorized = results[0] as bool;

    // 🔹 Проверка, что виджет еще монтирован, чтобы избежать ошибок
    if (!mounted) return;

    if (authorized) {
      // 🔹 Пользователь авторизован
      final int? userId = await auth.getUserId();
      if (!mounted) return;

      if (userId != null) {
        // 🔹 Если получили userId → переходим на основной экран с данными пользователя
        Navigator.pushReplacementNamed(
          context,
          '/lenta', // Можно заменить на HomeShell для bottom nav
          arguments: {'userId': userId},
        );
      } else {
        // 🔹 fallback: userId не найден, переходим на общий HomeScreen
        Navigator.pushReplacementNamed(context, '/lenta');
      }
    } else {
      // 🔹 Пользователь не авторизован → показываем экран приветствия / HomeScreen
      Navigator.pushReplacementNamed(context, '/lenta');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Пока идет проверка авторизации, показываем логотип с fade-in анимацией
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/logo.png',
            width: 150,
            height: 150,
            // 🔹 Сохраняем качество логотипа при масштабировании
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
