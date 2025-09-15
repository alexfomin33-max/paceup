import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
// import 'screens/home_shell.dart';
import 'screens/lenta_screen.dart';
import 'screens/regstep1_screen.dart';
import 'screens/regstep2_screen.dart';
import 'screens/addaccsms_screen.dart';
import 'screens/home_screen.dart';
import 'screens/createacc_screen.dart';
import 'widgets/app_bottom_nav_shell.dart';

const bottomNavRoutes = ['/lenta']; // только для экранов с bottom nav

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
      // экран с нижней навигацией
      if (args is Map && args.containsKey('userId')) {
        screen = LentaScreen(userId: args['userId'] as int);
      } else {
        screen = LentaScreen(userId: 123);
      }
      break;

    case '/regstep1':
      if (args is Map && args.containsKey('userId')) {
        screen = Regstep1Screen(userId: args['userId'] as int);
      } else {
        screen = const HomeScreen();
      }
      break;

    case '/regstep2':
      if (args is Map && args.containsKey('userId')) {
        screen = Regstep2Screen(userId: args['userId'] as int);
      } else {
        screen = const HomeScreen();
      }
      break;

    case '/addaccsms':
      if (args is Map && args.containsKey('phone')) {
        screen = AddAccSmsScreen(phone: args['phone'] as String);
      } else {
        screen = const HomeScreen();
      }
      break;

    case '/createacc':
      screen = const CreateaccScreen();
      break;

    default:
      screen = const SplashScreen(); // fallback
  }

  // ✅ Только оборачиваем в AppBottomNavShell, если маршрут есть в bottomNavRoutes
  if (bottomNavRoutes.contains(settings.name)) {
    return MaterialPageRoute(
      builder: (_) => AppBottomNavShell(screens: [screen]),
      settings: settings,
    );
  } else {
    return MaterialPageRoute(builder: (_) => screen, settings: settings);
  }
}
