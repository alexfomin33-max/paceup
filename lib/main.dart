import 'package:flutter/material.dart';
import 'routes.dart';
// import 'screens/splash_screen.dart';
// import 'screens/home_shell.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaceUp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Inter', // глобально для всего текста
        // чтобы label/hint в полях тоже были Inter
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(fontFamily: 'Inter'),
          labelStyle: TextStyle(fontFamily: 'Inter'),
        ),

        // чтобы сам Dropdown и его пункты были Inter
        dropdownMenuTheme: const DropdownMenuThemeData(
          textStyle: TextStyle(fontFamily: 'Inter'),
          // можно добавить ещё menuStyle, если нужно
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white.withValues(alpha: 0.6),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter', // на всякий случай
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
      ),
      initialRoute: '/splash',
      onGenerateRoute: onGenerateRoute,
    );
  }
}
