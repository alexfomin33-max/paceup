import 'package:flutter/material.dart';
import '../service/auth_service.dart';

/// 🔹 SplashScreen — стартовый экран приложения, отображается при запуске
/// Используется для проверки авторизации пользователя и перенаправления
/// на соответствующий экран (HomeScreen или HomeShell)
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
  Future<void> _checkAuth() async {
    final bool authorized = await auth.isAuthorized();

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
    // 🔹 Пока идет проверка авторизации, показываем индикатор загрузки
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
