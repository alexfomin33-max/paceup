import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lenta_screen.dart';
//import 'screens/login_screen.dart';
///import 'screens/profile_screen.dart';
//import 'screens/settings_screen.dart';

// Здесь регистрируем все экраны
final Map<String, WidgetBuilder> appRoutes = {
  '/splash': (context) => const SplashScreen(),
  '/home': (context) => const HomeScreen(),
  '/lenta': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    return LentaScreen(userId: args['userId']);
  },
  //'/login': (context) => const LoginScreen(),
  //'/profile': (context) => const ProfileScreen(),
  //'/settings': (context) => const SettingsScreen(),
};
