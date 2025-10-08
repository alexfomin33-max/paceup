// lib/main.dart
//
// Это "вход" в приложение. Здесь включаем обработку ошибок,
// настраиваем тему (шрифты/цвета), локализацию (ru/en),
// и подключаем систему роутинга из routes.dart.

import 'dart:ui'
    as ui; // для ui.PlatformDispatcher.instance.onError (глобальный обработчик ошибок)
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes.dart'; // здесь должен быть onGenerateRoute и, как минимум, маршрут '/splash'

void main() {
  // Если планируете что-то инициализировать ДО runApp (например, SharedPreferences),
  // лучше вызывать ensureInitialized. На работу сейчас не влияет, но это безопасная привычка.
  WidgetsFlutterBinding.ensureInitialized();

  // Обработка ошибок Flutter в debug/release (виджеты/рендеринг и т.п.)
  // В debug это и так печатается в консоль, но пусть будет явно.
  FlutterError.onError = (FlutterErrorDetails details) {
    // Выводим ошибку в консоль разработчика.
    FlutterError.dumpErrorToConsole(details);
    // При желании можно отправлять логи на сервер аналитики.
  };

  // Глобальный перехватчик ошибок "не из Flutter-мира" (например, из изоляций)
  // В release-сборках полезно: не даём приложению падать молча.
  ui.PlatformDispatcher.instance.onError = (error, stack) {
   
    debugPrint('Uncaught error: $error');
    debugPrint('Stack: $stack');
    return true; // true = "ошибка обработана", не валим приложение
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Заголовок окна (на Android почти не виден, на Web — да)
      title: 'PaceUp',

      // Убираем красную ленту "debug" в углу
      debugShowCheckedModeBanner: false,

      // ТЕМА ПРИЛОЖЕНИЯ (цвета/шрифты/вид полей)
      theme: ThemeData(
        // Включать Material 3 — на ваше усмотрение. Можно оставить закомментированным.
        // useMaterial3: true,

        // Фон всех экранов Scaffold по умолчанию — белый
        scaffoldBackgroundColor: Colors.white,

        // ГЛОБАЛЬНЫЙ ШРИФТ (везде будет Inter — и текст, и кнопки, и т.д.)
        fontFamily: 'Inter',

        // Для TextField / Dropdown и др. — задаём тоже Inter, чтобы всё одинаково выглядело
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(fontFamily: 'Inter'),
          labelStyle: TextStyle(fontFamily: 'Inter'),
        ),

        // Для выпадающих списков (DropdownButton, DropdownMenu)
        dropdownMenuTheme: const DropdownMenuThemeData(
          textStyle: TextStyle(fontFamily: 'Inter'),
          // Если понадобится стилизовать само меню, можно добавить menuStyle
        ),

        // Стили для AppBar (верхняя панель)
        appBarTheme: AppBarTheme(
          // Вы просили использовать .withValues вместо .withOpacity — так и делаем
          backgroundColor: Colors.white.withValues(alpha: 0.6),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter', // на всякий случай явно
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
      ),

      // КАКОЙ ЭКРАН ПОКАЗЫВАЕМ ПЕРВЫМ
      // Важно: в routes.dart должен существовать маршрут '/splash'.
      // Если сплэш не нужен — замените на ваш стартовый, например '/'.
      initialRoute: '/splash',

      // Централизованный роутер: всю навигацию настраиваем в routes.dart
      onGenerateRoute: onGenerateRoute,

      // ЛОКАЛИЗАЦИЯ
      // Зачем:
      //  - чтобы встроенные виджеты (календарь/дата/кнопки) показывались на русском/английском
      //  - чтобы были правильные форматы дат, названий месяцев и т.д.
      supportedLocales: const [
        Locale('ru'), // русский
        Locale('en'), // английский
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate, // тексты для Material-компонентов
        GlobalWidgetsLocalizations.delegate, // базовые виджеты
        GlobalCupertinoLocalizations
            .delegate, // тексты для Cupertino-компонентов
      ],

      // Не обязательно, но можно зафиксировать стартовый язык:
      // locale: const Locale('ru'),
      //
      // Или выбрать язык в зависимости от системы (по умолчанию так и работает),
      // а если язык системы не ru/en — принудительно откатиться на ru:
      // localeResolutionCallback: (locale, supported) {
      //   if (locale == null) return const Locale('ru');
      //   for (final l in supported) {
      //     if (l.languageCode == locale.languageCode) return l;
      //   }
      //   return const Locale('ru');
      // },
    );
  }
}
