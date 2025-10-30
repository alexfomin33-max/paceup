import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../service/auth_service.dart';
import '../theme/colors.dart';
import '../providers/lenta/lenta_provider.dart';

/// 🔹 SplashScreen — стартовый экран приложения, отображается при запуске
/// Используется для проверки авторизации пользователя и перенаправления
/// на соответствующий экран (HomeScreen или HomeShell)
///
/// ⚡ ОПТИМИЗАЦИЯ:
/// - Плавная fade-in анимация логотипа (800ms) для профессионального вида
/// - Предзагрузка данных ленты ДО перехода на экран (параллельно с анимацией)
/// - Offline-first подход: показываем кэш мгновенно, обновляем в фоне
/// - Задержка 2000ms достаточна для загрузки первой порции постов
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

/// 🔹 State для SplashScreen
/// Содержит логику проверки авторизации, навигации и предзагрузки данных
/// SingleTickerProviderStateMixin — для анимации fade-in логотипа
class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 🔹 Сервис для работы с авторизацией (проверка токена, получение userId)
  final AuthService auth = AuthService();

  // ────────────────────────── Анимация ──────────────────────────
  /// 🔹 Контроллер анимации для fade-in эффекта логотипа
  late AnimationController _animationController;

  /// 🔹 Анимация прозрачности (от 0.0 до 1.0)
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // ────────────────────────── Инициализация анимации ──────────────────────────
    // 🔹 Создаем контроллер анимации с длительностью 800ms
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 🔹 Создаем плавную анимацию прозрачности с ease-in кривой
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // 🔹 Запускаем анимацию fade-in
    _animationController.forward();

    // ────────────────────────── Проверка авторизации ──────────────────────────
    _checkAuth(); // 🔹 Проверяем авторизацию сразу после инициализации экрана
  }

  @override
  void dispose() {
    // 🔹 Очищаем ресурсы контроллера анимации
    _animationController.dispose();
    super.dispose();
  }

  /// 🔹 Метод проверки авторизации и предзагрузки данных
  /// 1. Проверяет, есть ли валидный токен
  /// 2. Если авторизован, получает userId
  /// 3. 🚀 ЗАПУСКАЕТ ПРЕДЗАГРУЗКУ ЛЕНТЫ (параллельно с анимацией)
  /// 4. Перенаправляет на соответствующий экран
  ///
  /// ⚡ ОПТИМИЗАЦИЯ:
  /// - Увеличена задержка до 2000ms (2 секунды) для комфортной загрузки данных
  /// - Предзагрузка данных через Riverpod provider ДО перехода на экран
  /// - Offline-first: кэш показывается мгновенно (~50ms), свежие данные подгружаются в фоне
  /// - За это время успевает: завершиться fade-in анимация (800ms) + прогрузиться лента (~1000ms)
  /// - При переходе на Ленту данные уже загружены из кэша
  Future<void> _checkAuth() async {
    // ────────── ШАГ 1: Проверяем авторизацию ──────────
    final bool authorized = await auth.isAuthorized();
    if (!mounted) return;

    int? userId;
    
    if (authorized) {
      // 🔹 Получаем userId
      userId = await auth.getUserId();
      if (!mounted) return;
    }

    // ────────── ШАГ 2: Предзагружаем данные ленты ──────────
    // 🚀 КРИТИЧНЫЙ МОМЕНТ: запускаем загрузку ДО перехода на экран
    // Это даёт offline-first эффект - данные из кэша показываются мгновенно
    if (userId != null) {
      debugPrint('🚀 Предзагрузка данных ленты для userId: $userId');
      
      // Запускаем предзагрузку и задержку параллельно
      await Future.wait([
        // Загружаем данные через провайдер
        ref.read(lentaProvider(userId).notifier).loadInitial(),
        // Задержка для анимации
        Future.delayed(const Duration(milliseconds: 2000)),
      ]);
      
      debugPrint('✅ Данные ленты предзагружены, переходим на экран');
    } else {
      // Если userId нет, просто ждём завершения анимации
      await Future.delayed(const Duration(milliseconds: 2000));
    }

    if (!mounted) return;

    // ────────── ШАГ 3: Переходим на экран ──────────
    if (userId != null) {
      // 🔹 Переходим на ленту с предзагруженными данными
      Navigator.pushReplacementNamed(
        context,
        '/lenta',
        arguments: {'userId': userId},
      );
    } else {
      // 🔹 fallback: переходим без userId
      Navigator.pushReplacementNamed(context, '/lenta');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Пока идет проверка авторизации, показываем логотип с fade-in анимацией
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/logo.png',
            width: 150,
            height: 150,
            // 🔹 Сохраняем качество логотипа при масштабировании
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
