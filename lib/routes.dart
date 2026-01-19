import 'package:flutter/material.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/lenta/screens/lenta_screen.dart';
import 'features/auth/screens/regstep1_screen.dart';
import 'features/auth/screens/reg_step1_screen.dart';
import 'features/auth/screens/reg_step2_screen.dart';
import 'features/auth/screens/reg_step3_screen.dart';
import 'features/auth/screens/reg_step4_screen.dart';
import 'features/auth/screens/reg_step5_screen.dart';
import 'features/auth/screens/regstep2_screen.dart';
import 'features/auth/screens/addaccsms_screen.dart';
import 'features/auth/screens/home_screen.dart';
import 'features/auth/screens/createacc_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/loginsms_screen.dart';
import 'features/auth/screens/code1_screen.dart';
import 'features/auth/screens/code2_screen.dart';
import '../../core/widgets/app_bottom_nav_shell.dart';

/// 🔹 Маршруты с нижней навигацией
const bottomNavRoutes = ['/lenta'];

/// 🔹 Маршруты экранов авторизации без анимации перехода
/// ⚠️ /home, /login, /loginsms, /code1 и /code2 не включены, так как для них нужна fade-in анимация
const homeRoutes = [
  '/createacc',
  '/regstep1',
  '/reg_step1',
  '/reg_step2',
  '/regstep2',
  '/regstep3',
  '/regstep4',
  '/regstep5',
  '/addaccsms',
];

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

    case '/reg_step1':
      screen = (args is Map && args.containsKey('userId'))
          ? RegStep1Screen(userId: args['userId'] as int)
          : const HomeScreen();
      break;

    case '/regstep1':
      screen = (args is Map && args.containsKey('userId'))
          ? Regstep1Screen(userId: args['userId'] as int)
          : const HomeScreen();
      break;

    case '/reg_step2':
      screen = (args is Map && args.containsKey('userId'))
          ? RegStep2Screen(userId: args['userId'] as int)
          : const HomeScreen();
      break;

    case '/regstep2':
      screen = (args is Map && args.containsKey('userId'))
          ? Regstep2Screen(userId: args['userId'] as int)
          : const HomeScreen();
      break;

    case '/regstep3':
      screen = (args is Map && args.containsKey('userId'))
          ? RegStep3Screen(userId: args['userId'] as int)
          : const HomeScreen();
      break;

    case '/regstep4':
      screen = (args is Map && args.containsKey('userId'))
          ? RegStep4Screen(userId: args['userId'] as int)
          : const HomeScreen();
      break;

    case '/regstep5':
      screen = (args is Map && args.containsKey('userId'))
          ? RegStep5Screen(userId: args['userId'] as int)
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

    case '/code1':
      screen = const Code1Screen();
      break;

    case '/code2':
      screen =
          (args is Map &&
              args.containsKey('firstCode') &&
              args.containsKey('userId'))
          ? Code2Screen(
              firstCode: args['firstCode'] as String,
              userId: args['userId'] as int,
            )
          : const Code1Screen(); // fallback на code1, если нет аргументов
      break;

    default:
      screen = const SplashScreen();
  }

  // 🔹 Если маршрут с нижней навигацией — оборачиваем AppBottomNavShell
  if (bottomNavRoutes.contains(settings.name)) {
    int userId = 2; // fallback
    if (args is Map && args.containsKey('userId')) {
      userId = args['userId'] as int;
    }

    // 🔹 Используем fade-in анимацию для плавного перехода
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          AppBottomNavShell(userId: userId),
      settings: settings,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 🔹 Плавное появление с fade-in эффектом
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        );
      },
    );
  } else if (settings.name == '/home' ||
      settings.name == '/login' ||
      settings.name == '/loginsms' ||
      settings.name == '/code1' ||
      settings.name == '/code2') {
    // 🔹 Для /home, /login, /loginsms, /code1 и /code2 используем fade-in анимацию
    // Это обеспечивает плавное появление экранов авторизации
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      settings: settings,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 🔹 Плавное появление с fade-in эффектом
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        );
      },
    );
  } else if (homeRoutes.contains(settings.name)) {
    // 🔹 Для всех маршрутов экранов авторизации убираем анимацию
    // Это обеспечивает мгновенные переходы между экранами home
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 🔹 Без анимации - мгновенное появление экрана
        return child;
      },
    );
  } else {
    return MaterialPageRoute(builder: (_) => screen, settings: settings);
  }
}
