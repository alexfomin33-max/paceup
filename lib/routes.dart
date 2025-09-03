import 'package:flutter/material.dart';
import 'package:paceip/screens/createacc_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lenta_screen.dart';
import 'screens/regstep1_screen.dart';
import 'screens/regstep2_screen.dart';
//import 'screens/login_screen.dart';
///import 'screens/profile_screen.dart';
//import 'screens/settings_screen.dart';

// Здесь регистрируем все экраны
final Map<String, WidgetBuilder> appRoutes = {
  '/splash': (context) => const SplashScreen(),
  '/home': (context) => const HomeScreen(),
  '/createacc': (context) => const CreateaccScreen(),
  '/lenta': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    return LentaScreen(userId: args['userId'] as int);
  },
  '/regstep1': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    return Regstep1Screen(userId: args['userId'] as int);
  },
  '/regstep2': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    return Regstep2Screen(userId: args['userId'] as int);
  },
  //'/login': (context) => const LoginScreen(),
  //'/profile': (context) => const ProfileScreen(),
  //'/settings': (context) => const SettingsScreen(),
};
