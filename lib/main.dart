// ========================= main.dart (патч) ===============================
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/colors.dart';
import 'routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Логи ошибок: в дебаге — консоль; в релизе — не падаем.
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack: $stack');
    return true; // помечаем как обработанное
  };

  runApp(const PaceUpApp());
}

class PaceUpApp extends StatelessWidget {
  const PaceUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Базовая тема (Material 3 + Inter + iOS-лайк цвета)
    final ThemeData base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      dividerColor: AppColors.divider,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandPrimary,
        primary: AppColors.brandPrimary,
        secondary: AppColors.brandSecondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onSurface: AppColors.textPrimary,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        thickness: 0.5,
        color: AppColors.divider,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: AppColors.iconPrimary),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        // без тени-дрожа
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android:
              CupertinoPageTransitionsBuilder(), // свайп-назад
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    return MaterialApp(
      title: 'PaceUp',
      debugShowCheckedModeBanner: false,
      theme: base,

      initialRoute: '/splash',
      onGenerateRoute: onGenerateRoute,

      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Глобально «светлые» Cupertino-контролы + Inter
      builder: (context, child) => CupertinoTheme(
        data: const CupertinoThemeData(
          brightness: Brightness.light, // ← ключ к чёрному тексту в пикере
          primaryColor: AppColors.brandPrimary,
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(fontFamily: 'Inter'),
            // опционально: можно ещё явно задать стиль колеса
            // pickerTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 22),
          ),
        ),
        child: child!,
      ),
    );
  }
}
// ========================================================================== 
