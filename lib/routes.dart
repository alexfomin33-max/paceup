import 'package:flutter/material.dart';

// 🔹 Импорт экранов приложения
import 'screens/createacc_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lenta_screen.dart';
import 'screens/regstep1_screen.dart';
import 'screens/regstep2_screen.dart';
import 'screens/createacccode_screen.dart';
// import 'screens/addaccsms_screen.dart'; // пока не используем
// import 'screens/login_screen.dart';
// import 'screens/profile_screen.dart';
// import 'screens/settings_screen.dart';

/// 🔹 Словарь маршрутов приложения (routes)
/// Каждая строка — путь к экрану
/// Используется в MaterialApp(routes: appRoutes)
final Map<String, WidgetBuilder> appRoutes = {
  // 🔹 Экран сплэша — первый экран при запуске
  '/splash': (context) => const SplashScreen(),

  // 🔹 Главный экран (домашний)
  '/home': (context) => const HomeScreen(),

  // 🔹 Экран создания аккаунта
  '/createacc': (context) => const CreateaccScreen(),

  // 🔹 Экран ленты / просмотра активности пользователя
  // Принимает аргумент userId
  '/lenta': (context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    // Проверяем, что передан userId
    if (args is Map && args.containsKey('userId')) {
      return LentaScreen(userId: args['userId'] as int);
    }

    // Если аргументы не переданы — возвращаем home
    return const HomeScreen();
  },

  // 🔹 Регистрация — шаг 1, требует userId
  '/regstep1': (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey('userId')) {
      return Regstep1Screen(userId: args['userId'] as int);
    }
    return const HomeScreen(); // fallback
  },

  // 🔹 Регистрация — шаг 2, требует userId
  '/regstep2': (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey('userId')) {
      return Regstep2Screen(userId: args['userId'] as int);
    }
    return const HomeScreen(); // fallback
  },

  // 🔹 Экран подтверждения номера через SMS
  // Принимает аргумент phone
  '/addaccsms': (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey('phone')) {
      return AddAccSmsScreen(phone: args['phone'] as String);
    }
    return const HomeScreen(); // fallback
  },

  // 🔹 Экран ввода кода подтверждения (пока закомментирован)
  // '/createacccode': (context) => const CreateAccCodeScreen(),

  // 🔹 Примеры экранов для будущего использования:
  // '/login': (context) => const LoginScreen(),
  // '/profile': (context) => const ProfileScreen(),
  // '/settings': (context) => const SettingsScreen(),
};
