import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/lenta/lenta_screen.dart';
import 'screens/home/regstep1_screen.dart';
import 'screens/home/regstep2_screen.dart';
import 'screens/home/addaccsms_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/createacc_screen.dart';
import 'screens/home/login_screen.dart';
import 'screens/home/loginsms_screen.dart';
import 'widgets/app_bottom_nav_shell.dart';

/// 🔹 Маршруты с нижней навигацией
const bottomNavRoutes = ['/lenta'];

/// 🔹 Генератор маршрутов
Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final args = settings.arguments;
  Widget screen;

  switch (settings.name) {
    case '/splash':
      screen = const SplashScreen();
      break;

    case '/home':
      screen = const HomeScreen();
      break;

    case '/lenta':
      screen = (args is Map && args.containsKey('userId'))
          ? LentaScreen(userId: args['userId'] as int)
          : const LentaScreen(userId: 123);
      break;

    case '/regstep1':
      screen = (args is Map && args.containsKey('userId'))
          ? Regstep1Screen(userId: args['userId'] as int)
          : const HomeScreen();
      break;

    case '/regstep2':
      screen = (args is Map && args.containsKey('userId'))
          ? Regstep2Screen(userId: args['userId'] as int)
          : const HomeScreen();
      break;

    case '/addaccsms':
      screen = (args is Map && args.containsKey('phone'))
          ? AddAccSmsScreen(phone: args['phone'] as String)
          : const HomeScreen();
      break;

    case '/createacc':
      screen = const CreateaccScreen();
      break;

    case '/login':
      screen = const LoginScreen();
      break;

    case '/loginsms':
      screen = (args is Map && args.containsKey('phone'))
          ? LoginSmsScreen(phone: args['phone'] as String)
          : const HomeScreen();
      break;

    default:
      screen = const SplashScreen();
  }

  // 🔹 Если маршрут с нижней навигацией — оборачиваем AppBottomNavShell
  if (bottomNavRoutes.contains(settings.name)) {
    int userId = 1; // fallback
    if (args is Map && args.containsKey('userId')) {
      userId = args['userId'] as int;
    }

    return MaterialPageRoute(
      builder: (_) => AppBottomNavShell(userId: userId),
      settings: settings,
    );
  } else {
    return MaterialPageRoute(builder: (_) => screen, settings: settings);
  }
}
