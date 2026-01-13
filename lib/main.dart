// ========================= main.dart (патч) ===============================
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart';

import '../../core/theme/app_theme.dart';
import 'routes.dart';
import 'core/config/app_config.dart';
import 'providers/services/cache_provider.dart';
import 'providers/services/auth_provider.dart';
import 'providers/services/fcm_provider.dart';
import 'providers/theme_provider.dart';
import '../../core/utils/db_optimizer.dart';
import '../../core/utils/image_cache_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ────────────────────────── Firebase инициализация ──────────────────────────
  // ВАЖНО: Перед запуском выполните: flutter pub get
  // Ошибки компиляции исчезнут после установки пакетов firebase_core и firebase_messaging
  // На macOS Firebase не инициализируем (FCM не поддерживается)
  bool firebaseInitialized = false;
  if (!Platform.isMacOS) {
    try {
      await Firebase.initializeApp();
      firebaseInitialized = true;
      if (kDebugMode) {
        debugPrint('✅ Firebase инициализирован');
      }
    } catch (e, stackTrace) {
      // Игнорируем ошибки инициализации Firebase
      // Это нормально, если пакеты еще не установлены (flutter pub get)
      if (kDebugMode) {
        debugPrint('⚠️ Firebase не инициализирован: $e');
        debugPrint('⚠️ Stack trace: $stackTrace');
        debugPrint('   Выполните: flutter pub get');
      }
    }
  } else {
    if (kDebugMode) {
      debugPrint('⚠️ Firebase пропущен на macOS (FCM не поддерживается)');
    }
  }

  // ────────────────────────── MapBox инициализация ──────────────────────────
  // Mapbox не поддерживает macOS, поэтому инициализируем только для поддерживаемых платформ
  if (!Platform.isMacOS) {
    try {
      MapboxOptions.setAccessToken(AppConfig.mapboxAccessToken);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Ошибка инициализации Mapbox: $e');
      }
    }
  } else {
    if (kDebugMode) {
      debugPrint('⚠️ Mapbox не поддерживается на macOS');
    }
  }

  // Логи ошибок: в дебаге — консоль; в релизе — не падаем.
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Uncaught error: $error');
      debugPrint('Stack: $stack');
    }
    return true; // помечаем как обработанное
  };

  // ────────────────────────── Drift Offline-First Cache ──────────────────────────
  // Инициализируем базу данных перед запуском приложения
  // Это гарантирует, что кэш готов к использованию с первого кадра

  // ProviderScope создаётся один раз
  final container = ProviderContainer();

  // ────────────────────────── Автоматическая регистрация FCM токена (для тестирования) ──────────────────────────
  // Регистрируем FCM токен при запуске (dev/test), даже если check_token не проходит.
  // Это удобно для тестирования, когда авторизация жестко задана в auth_service.dart
  if (!Platform.isMacOS && firebaseInitialized) {
    // Ждем небольшую задержку, чтобы Firebase точно инициализировался
    Future.delayed(const Duration(milliseconds: 1000), () async {
      try {
        if (kDebugMode) {
          debugPrint('🔔 [FCM] Начинаем регистрацию токена при запуске...');
        }

        final auth = container.read(authServiceProvider);
        final userId = await auth.getUserId();
        if (kDebugMode) {
          debugPrint('🔔 [FCM] userId (из AuthService): $userId');
        }

        // Если userId есть — пытаемся инициализировать FCM и зарегистрировать токен.
        // Не завязываемся на auth.isAuthorized(), т.к. он дергает сеть (check_token)
        // и может возвращать false в dev среде.
        if (userId != null) {
          final fcmService = container.read(fcmServiceProvider);

          // Инициализируем FCM с подробным логированием
          try {
            await fcmService.initialize();
            if (kDebugMode) {
              debugPrint('✅ [FCM] Инициализация завершена');
            }
          } catch (e, stackTrace) {
            if (kDebugMode) {
              debugPrint('❌ [FCM] Ошибка инициализации FCM: $e');
              debugPrint('❌ [FCM] Stack trace: $stackTrace');
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ [FCM] userId == null, пропускаем регистрацию');
          }
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ [FCM] Критическая ошибка регистрации FCM токена: $e');
          debugPrint('❌ [FCM] Stack trace: $stackTrace');
        }
      }
    });
  } else if (!Platform.isMacOS && !firebaseInitialized) {
    if (kDebugMode) {
      debugPrint(
        '⚠️ [FCM] Firebase не инициализирован, пропускаем регистрацию FCM токена',
      );
    }
  }

  // Инициализируем базу данных через провайдер
  try {
    final db = container.read(appDatabaseProvider);

    // Проверяем подключение с обработкой ошибок чтения
    try {
      await db.select(db.cachedActivities).get();
    } catch (readError) {
      // Если ошибка при чтении, возможно в базе некорректные данные
      // Очищаем таблицу активностей и продолжаем работу
      try {
        await db.customStatement('DELETE FROM cached_activities;');
      } catch (deleteError) {
        // Игнорируем ошибки очистки
      }
    }

    // ────────── Автоматическая оптимизация БД ──────────
    // Запускаем фоновую оптимизацию (раз в неделю)
    // • Очистка старого кэша (>7 дней)
    // • ANALYZE, WAL checkpoint, vacuum
    // • Прирост: +15-20% query speed, -30% disk space
    final cache = container.read(cacheServiceProvider);
    final optimizer = DbOptimizer(cache);

    // Запуск в фоне, не блокируем UI
    optimizer.runOptimizationIfNeeded();
  } catch (e) {
    // Игнорируем ошибки инициализации БД
  }

  // ────────────────────────── Riverpod ──────────────────────────
  // ProviderScope обеспечивает доступ к провайдерам во всём приложении

  // ────────────────────────── Device Preview ──────────────────────────
  // Включаем Device Preview только в debug-режиме для тестирования адаптивности
  runApp(
    DevicePreview(
      enabled: kDebugMode, //kDebugMode false
      builder: (context) => UncontrolledProviderScope(
        container: container,
        child: const PaceUpApp(),
      ),
    ),
  );
}

class PaceUpApp extends StatefulWidget {
  const PaceUpApp({super.key});

  @override
  State<PaceUpApp> createState() => _PaceUpAppState();
}

class _PaceUpAppState extends State<PaceUpApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Используем Consumer для доступа к провайдеру темы
    return Consumer(
      builder: (context, ref, _) {
        final themeMode = ref.watch(themeModeNotifierProvider);

        // Базовая светлая тема (Material 3 + Inter + iOS-лайк цвета)
        final ThemeData lightTheme = ThemeData(
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
            surfaceTintColor: Colors.transparent,
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

        // Темная тема (iOS Dark Mode)
        final ThemeData darkTheme = ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.darkBackground,
          fontFamily: 'Inter',
          dividerColor: AppColors.darkDivider,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brandPrimary,
            primary: AppColors.brandPrimary,
            secondary: AppColors.brandSecondary,
            surface: AppColors.darkSurface,
            error: AppColors.error,
            onSurface: AppColors.darkTextPrimary,
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: AppColors.darkSurface,
            foregroundColor: AppColors.darkTextPrimary,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          dividerTheme: const DividerThemeData(
            thickness: 0.5,
            color: AppColors.darkDivider,
            space: 0,
          ),
          iconTheme: const IconThemeData(color: AppColors.darkIconPrimary),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: AppColors.darkSurface,
            surfaceTintColor: Colors.transparent,
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
          // ────────────────────────── Device Preview Integration ──────────────────────────
          // Локализация из DevicePreview (если включен) или дефолтная
          locale: DevicePreview.locale(context),
          // Объединяем DevicePreview.appBuilder с нашим существующим builder
          builder: (context, child) {
            // Сначала применяем DevicePreview.appBuilder
            final devicePreviewChild = DevicePreview.appBuilder(context, child);

            // Настраиваем unified image cache после первого билда
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ImageCacheManager.configure(context);
            });

            // Обновляем CupertinoTheme в зависимости от темы
            final brightness = themeMode == ThemeMode.dark
                ? Brightness.dark
                : Brightness.light;

            return CupertinoTheme(
              data: CupertinoThemeData(
                brightness: brightness,
                primaryColor: AppColors.brandPrimary,
                textTheme: const CupertinoTextThemeData(
                  textStyle: TextStyle(fontFamily: 'Inter'),
                ),
              ),
              child: devicePreviewChild,
            );
          },
          // ────────────────────────── MaterialApp Settings ──────────────────────────
          title: 'PaceUp',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode, // ← используем провайдер
          navigatorKey: _navigatorKey,
          initialRoute: '/splash',
          onGenerateRoute: onGenerateRoute,
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
// ========================================================================== 
