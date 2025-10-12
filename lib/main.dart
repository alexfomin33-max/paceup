// lib/main.dart
//
// ┌───────────────────────────────────────────────────────────────────────────┐
// │                         ВХОД В ПРИЛОЖЕНИЕ (main)                          │
// │  • Глобальная обработка ошибок                                            │
// │  • Тема из токенов AppColors.* (iOS-лайк)                                 │
// │  • Дефолтный цвет текста = AppColors.textPrimary                          │
// │  • Локализация ru/en                                                      │
// │  • Централизованный роутинг через routes.dart                             │
// └───────────────────────────────────────────────────────────────────────────┘

import 'dart:ui' as ui; // для ui.PlatformDispatcher.instance.onError
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/app_theme.dart'; // оставляем, если где-то экспортируешь баррель
import 'theme/colors.dart'; // токены AppColors.*
import 'routes.dart'; // onGenerateRoute + '/splash'

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack: $stack');
    return true; // «обработано», не валим приложение
  };

  runApp(const PaceUpApp());
}

class PaceUpApp extends StatelessWidget {
  const PaceUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────────────────────────────────────────
    //       ТЕМА ПРИЛОЖЕНИЯ ЧЕРЕЗ ТОКЕНЫ AppColors.* (iOS-лайк)
    // ----------------------------------------------------------------------
    // ВАЖНО: здесь мы задаём ДЕФОЛТНЫЙ цвет текста для всего проекта:
    // textTheme.apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary)
    // ──────────────────────────────────────────────────────────────────────
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light, // системная тёмная тема не фиксируется
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      // Инпуты/меню — тоже Inter
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(fontFamily: 'Inter'),
        labelStyle: TextStyle(fontFamily: 'Inter'),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(fontFamily: 'Inter'),
      ),

      // Разделители по умолчанию (например для ListTile.divideTiles и т.п.)
      dividerColor: AppColors.divider,
    );

    // Применяем единый ДЕФОЛТНЫЙ цвет текста ко всем стилям
    final TextTheme textThemed = base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    final ThemeData theme = base.copyWith(
      textTheme: textThemed,
      primaryTextTheme: textThemed,
      // Страховка для некоторых старых Material-частей, читающих typography:
      // ignore: deprecated_member_use
      typography: base.typography.copyWith(
        black: base.typography.black.apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        white: base.typography.white.apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
      ),
      // Цвета-акценты, бордеры и т.п. через токены (минимальный набор)
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.brandPrimary,
        secondary: AppColors.brandSecondary,
        surface: AppColors.surface,
        error: AppColors.error,
        outline: AppColors.border,
        onSurface: AppColors.textPrimary, // чтобы виджеты не темнели
      ),
    );

    return MaterialApp(
      title: 'PaceUp',
      debugShowCheckedModeBanner: false,

      // Тема из токенов
      theme: theme,
      // themeMode НЕ фиксируем → система сама выберет (светлая/тёмная)

      // Роутинг
      initialRoute: '/splash',
      onGenerateRoute: onGenerateRoute,

      // Локализация
      supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
