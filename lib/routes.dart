import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
// import 'screens/home_shell.dart';
import 'screens/lenta_screen.dart';
import 'screens/regstep1_screen.dart';
import 'screens/regstep2_screen.dart';
import 'screens/addaccsms_screen.dart';
import 'screens/home_screen.dart';
import 'screens/createacc_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/app_bottom_nav_shell.dart';

/// 🔹 Список маршрутов, которые должны открываться внутри нижней навигации
const bottomNavRoutes = ['/lenta'];

/// 🔹 Основной метод генерации маршрутов для Navigator
/// Позволяет динамически создавать экраны и передавать им аргументы
Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final args = settings.arguments; // Аргументы, переданные при навигации
  Widget screen; // Экран, который будем отображать

  switch (settings.name) {
    case '/splash':
      // 🔹 Стартовый экран приложения
      screen = const SplashScreen();
      break;

    case '/home':
      // 🔹 Главный экран без нижней навигации
      screen = const HomeScreen();
      break;

    case '/lenta':
      // 🔹 Экран ленты — пример использования bottom nav
      if (args is Map && args.containsKey('userId')) {
        screen = LentaScreen(userId: args['userId'] as int);
      } else {
        // Если userId не передан, используем заглушку
        screen = LentaScreen(userId: 123);
      }
      break;

    case '/regstep1':
      // 🔹 Первый шаг регистрации
      if (args is Map && args.containsKey('userId')) {
        screen = Regstep1Screen(userId: args['userId'] as int);
      } else {
        // Если userId отсутствует — fallback на главный экран
        screen = const HomeScreen();
      }
      break;

    case '/regstep2':
      // 🔹 Второй шаг регистрации
      if (args is Map && args.containsKey('userId')) {
        screen = Regstep2Screen(userId: args['userId'] as int);
      } else {
        screen = const HomeScreen();
      }
      break;

    case '/addaccsms':
      // 🔹 Экран подтверждения номера через SMS
      if (args is Map && args.containsKey('phone')) {
        screen = AddAccSmsScreen(phone: args['phone'] as String);
      } else {
        screen = const HomeScreen();
      }
      break;

    case '/createacc':
      // 🔹 Экран создания аккаунта
      screen = const CreateaccScreen();
      break;

    case '/login':
      // 🔹 Экран входа (авторизация)
      screen = const LoginScreen();
      break;

    default:
      // 🔹 Любой неизвестный маршрут перенаправляется на SplashScreen
      screen = const SplashScreen();
  }

  // 🔹 Если маршрут входит в список bottomNavRoutes — оборачиваем экран в AppBottomNavShell
  if (bottomNavRoutes.contains(settings.name)) {
    return MaterialPageRoute(
      builder: (_) => AppBottomNavShell(
        screens: [screen], // Передаем экран внутрь оболочки bottom nav
      ),
      settings: settings,
    );
  } else {
    // 🔹 Обычная генерация маршрута без нижней навигации
    return MaterialPageRoute(builder: (_) => screen, settings: settings);
  }
}
