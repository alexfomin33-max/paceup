import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../providers/services/auth_provider.dart';
import '../../../providers/services/fcm_provider.dart';

/// 🔹 SplashScreen — стартовый экран приложения, отображается при запуске
/// Используется для проверки авторизации пользователя и перенаправления
/// на соответствующий экран (HomeScreen или HomeShell)
///
/// ⚡ ОПТИМИЗАЦИЯ:
/// - Минимальное время показа splash screen (минимум 200ms для плавности)
/// - Немедленный переход без дополнительных задержек
/// - Предзагрузка данных происходит в самих экранах (offline-first подход)
/// - Плавная fade-in анимация логотипа (800ms) для профессионального вида
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

/// 🔹 State для SplashScreen
/// Содержит логику проверки авторизации и навигации
/// SingleTickerProviderStateMixin — для анимации fade-in логотипа
class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ────────────────────────── Анимация ──────────────────────────
  /// 🔹 Контроллер анимации для fade-in эффекта логотипа
  late AnimationController _animationController;

  /// 🔹 Анимация прозрачности (от 0.0 до 1.0)
  late Animation<double> _fadeAnimation;

  // ────────────────────────── Состояние интернета ──────────────────────────
  /// 🔹 Флаг наличия интернета (null = проверяется, true = есть, false = нет)
  bool? _hasInternet;

  /// 🔹 Флаг проверки интернета (чтобы избежать множественных проверок)
  bool _isCheckingInternet = false;

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

    // ────────────────────────── Проверка интернета и авторизации ──────────────────────────
    _checkInternetAndAuth(); // 🔹 Проверяем интернет и авторизацию сразу после инициализации экрана
  }

  @override
  void dispose() {
    // 🔹 Очищаем ресурсы контроллера анимации
    _animationController.dispose();
    super.dispose();
  }

  /// 🔹 Метод проверки интернета
  /// Пытается выполнить простой запрос к API для проверки подключения
  /// Возвращает true если интернет есть, false если нет
  Future<bool> _checkInternet() async {
    try {
      final api = ApiService();
      // Делаем простой запрос с коротким таймаутом для быстрой проверки
      // Уменьшен до 2 секунд для более быстрой реакции
      await api.get('/', timeout: const Duration(seconds: 5));
      return true;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } on ApiException catch (e) {
      // Проверяем, является ли ApiException сетевой ошибкой
      // (например, "Нет подключения к интернету", "Ошибка сети", "Failed host lookup")
      final message = e.message.toLowerCase();

      // Список фраз, которые точно означают отсутствие интернета
      final networkErrorPhrases = [
        'нет подключения',
        'connection',
        'сеть',
        'network',
        'timeout',
        'таймаут',
        'host lookup',
        'failed',
        'lookup failed',
        'превышено время ожидания',
      ];

      // Если в сообщении есть любая из этих фраз - интернета нет
      if (networkErrorPhrases.any((phrase) => message.contains(phrase))) {
        return false;
      }

      // Если это HTTP ошибка (404, 401, 500 и т.д.) - значит интернет есть,
      // но сервер вернул ошибку. Это нормально для проверки интернета.
      // Проверяем, что это не сетевая ошибка по содержимому сообщения
      if (message.contains('http') &&
          (message.contains('404') ||
              message.contains('401') ||
              message.contains('403') ||
              message.contains('500'))) {
        // HTTP ошибка - значит соединение работает, интернет есть
        return true;
      }

      // Если не можем определить - считаем что интернета нет (безопасный подход)
      // Лучше показать экран без интернета, чем перейти на экран с ошибкой
      return false;
    } catch (e) {
      // Для всех остальных ошибок проверяем через ErrorHandler
      if (ErrorHandler.isNetworkError(e)) {
        return false;
      }

      // Дополнительная проверка строковых ошибок
      final errorString = e.toString().toLowerCase();
      final networkIndicators = [
        'host lookup',
        'failed',
        'connection',
        'network',
        'socket',
        'timeout',
      ];

      if (networkIndicators.any(
        (indicator) => errorString.contains(indicator),
      )) {
        return false;
      }

      // Если не можем определить - считаем что интернета нет (безопасный подход)
      return false;
    }
  }

  /// 🔹 Метод проверки интернета и авторизации
  /// 1. Проверяет наличие интернета
  /// 2. Если интернета нет - показывает экран без подключения
  /// 3. Если интернет есть - проверяет авторизацию и переходит на основной экран
  Future<void> _checkInternetAndAuth() async {
    // Проверяем интернет только один раз
    if (_isCheckingInternet) return;
    _isCheckingInternet = true;

    try {
      // Запускаем проверку интернета и минимальное время показа параллельно
      // Уменьшена задержка до 500ms для более быстрой загрузки
      final results = await Future.wait([
        _checkInternet(),
        Future.delayed(
          const Duration(milliseconds: 500),
        ), // минимальная задержка для завершения анимации
      ]);

      final bool hasInternet = results[0] as bool;

      // 🔹 Проверка, что виджет еще монтирован
      if (!mounted) {
        _isCheckingInternet = false;
        return;
      }

      setState(() {
        _hasInternet = hasInternet;
        _isCheckingInternet = false;
      });

      // ⚠️ КРИТИЧНО: Если интернета нет - НЕ переходим на основной экран
      // Остаемся на splash screen с сообщением о отсутствии интернета
      if (!hasInternet) {
        if (kDebugMode) {
          debugPrint('⚠️ Интернета нет - остаемся на splash screen');
        }
        return;
      }

      // Если интернет есть - проверяем авторизацию и переходим на основной экран
      // Но перед переходом еще раз проверяем, что интернет все еще есть
      if (mounted && _hasInternet == true) {
        await _checkAuth();
      }
    } catch (e) {
      // В случае ошибки сбрасываем флаг и показываем экран без интернета
      if (mounted) {
        setState(() {
          _hasInternet = false;
          _isCheckingInternet = false;
        });
      }
      if (kDebugMode) {
        debugPrint('⚠️ Ошибка при проверке интернета: $e');
      }
    }
  }

  /// 🔹 Метод проверки авторизации
  /// 1. Проверяет, есть ли валидный токен
  /// 2. Если авторизован, получает userId
  /// 3. Перенаправляет на соответствующий экран
  ///
  /// ⚠️ ВАЖНО: Переход происходит ТОЛЬКО если интернет есть
  ///
  /// ⚡ ОПТИМИЗАЦИЯ:
  /// - Параллельная проверка авторизации и минимального времени показа
  /// - Предотвращает визуальный микролаг между splash и загруженной лентой
  Future<void> _checkAuth() async {
    // ⚠️ Дополнительная проверка: если интернета нет - не переходим
    if (_hasInternet == false) {
      if (kDebugMode) {
        debugPrint('⚠️ Интернета нет - не переходим на основной экран');
      }
      return;
    }

    // Получаем AuthService через провайдер
    final auth = ref.read(authServiceProvider);

    // Запускаем проверку авторизации и минимальное время показа параллельно
    // Убрана задержка - проверка авторизации быстрая (локальная)
    final results = await Future.wait([
      auth.isAuthorized(),
      Future.delayed(
        const Duration(milliseconds: 300),
      ), // минимальная задержка для плавности перехода
    ]);

    final bool authorized = results[0] as bool;

    // 🔹 Проверка, что виджет еще монтирован, чтобы избежать ошибок
    if (!mounted) return;

    // ⚠️ Еще раз проверяем интернет перед переходом (на случай если он пропал)
    if (_hasInternet == false) {
      if (kDebugMode) {
        debugPrint('⚠️ Интернет пропал - не переходим на основной экран');
      }
      return;
    }

    if (authorized) {
      // 🔹 Пользователь авторизован
      final int? userId = await auth.getUserId();
      if (!mounted) return;

      // Инициализируем FCM для авторизованного пользователя (только на Android, временно отключено для iOS)
      if (!Platform.isMacOS && !Platform.isIOS) {
        try {
          final fcmService = ref.read(fcmServiceProvider);
          await fcmService.initialize();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Ошибка инициализации FCM: $e');
          }
        }
      }

      // Синхронизация будет запущена в LentaScreen после загрузки экрана
      // (там пользователь уже точно авторизован и данные готовы)
      if (userId != null) {
        // 🔹 Если получили userId → переходим на основной экран с данными пользователя
        Navigator.pushReplacementNamed(
          context,
          '/entercode', // Можно заменить на HomeShell для bottom nav
          arguments: {'userId': userId},
        );
      } else {
        // 🔹 fallback: userId не найден, переходим на общий HomeScreen
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      // 🔹 Пользователь не авторизован → показываем экран приветствия / HomeScreen
      // Используем /home для плавного fade-in перехода
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ─────────── Тёмный фон для splash screen ───────────
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _hasInternet == false
            ? _buildNoInternetScreen()
            : _buildSplashScreen(),
      ),
    );
  }

  /// 🔹 Экран без интернета
  /// Показывается когда интернета нет, с текстом и кнопкой обновления
  Widget _buildNoInternetScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // ─────────── Контент по центру ───────────
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ─────────── Логотип ───────────
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Image.asset(
                      'assets/logo.png',
                      width: 150,
                      height: 150,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ─────────── Заголовок ───────────
                  const Text(
                    'Нет подключения',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // ─────────── Описание ───────────
                  const Text(
                    'Проверьте интернет соединение',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // ─────────── Кнопка обновления внизу ───────────
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCheckingInternet
                    ? null
                    : () {
                        setState(() {
                          _hasInternet = null;
                          _isCheckingInternet = false;
                        });
                        _checkInternetAndAuth();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: _isCheckingInternet
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black,
                          ),
                        ),
                      )
                    : const Text(
                        'Обновить',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Обычный splash screen с логотипом
  /// Показывается во время проверки интернета и авторизации
  Widget _buildSplashScreen() {
    return Center(
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
    );
  }
}
