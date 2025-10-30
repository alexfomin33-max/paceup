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
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

/// 🔹 State для SplashScreen
/// Содержит логику проверки авторизации и навигации
class SplashScreenState extends State<SplashScreen> {
  // 🔹 Сервис для работы с авторизацией (проверка токена, получение userId)
  final AuthService auth = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth(); // 🔹 Проверяем авторизацию сразу после инициализации экрана
  }

  /// 🔹 Метод проверки авторизации
  /// 1. Проверяет, есть ли валидный токен
  /// 2. Если авторизован, получает userId
  /// 3. Перенаправляет на соответствующий экран
  ///
  /// ⚡ ОПТИМИЗАЦИЯ:
  /// - Увеличена задержка до 600ms для плавной загрузки данных
  /// - Параллельная проверка авторизации и минимального времени показа
  /// - Предотвращает визуальный микролаг между splash и загруженной лентой
  Future<void> _checkAuth() async {
    // Запускаем проверку авторизации и минимальное время показа параллельно
    final results = await Future.wait([
      auth.isAuthorized(),
      Future.delayed(
        const Duration(milliseconds: 600),
      ), // увеличенная задержка для загрузки первых данных
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
    // 🔹 Пока идет проверка авторизации, показываем минималистичный splash
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
