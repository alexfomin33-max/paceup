import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../providers/services/api_provider.dart';
import '../../../providers/services/auth_provider.dart';
import '../../lenta/providers/lenta_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// 🔹 Экран для ввода кода доступа (4-значный PIN)
class EnterCodeScreen extends ConsumerStatefulWidget {
  const EnterCodeScreen({super.key});

  @override
  ConsumerState<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends ConsumerState<EnterCodeScreen> {
  /// 🔹 Введённый код доступа (максимум 4 цифры)
  String _code = '';

  /// 🔹 Имя пользователя для отображения приветствия
  String _userFirstName = '';

  /// 🔹 Флаг загрузки данных пользователя
  bool _isLoadingUserName = true;

  /// 🔹 Флаг, чтобы загрузить имя пользователя только один раз
  bool _hasLoadedUserName = false;

  /// 🔹 Сервис API для загрузки данных пользователя
  final ApiService _api = ApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🔹 Загружаем имя пользователя только один раз, когда контекст готов
    if (!_hasLoadedUserName) {
      _hasLoadedUserName = true;
      _loadUserName();
    }
  }

  /// 🔹 Загрузка имени пользователя из API
  Future<void> _loadUserName() async {
    if (!mounted) return;

    // 🔹 Получаем userId из аргументов маршрута
    final args = ModalRoute.of(context)?.settings.arguments;
    final userId = (args is Map && args.containsKey('userId'))
        ? args['userId'] as int
        : null;

    if (userId == null || userId <= 0) {
      if (mounted) {
        setState(() {
          _isLoadingUserName = false;
        });
      }
      return;
    }

    try {
      final data = await _api.post(
        '/get_user_info.php',
        body: {'user_id': userId.toString()},
        timeout: const Duration(seconds: 10),
      );

      if (!mounted) return;

      if (data['ok'] == true) {
        final firstName = data['first_name']?.toString() ?? '';
        setState(() {
          _userFirstName = firstName.trim();
          _isLoadingUserName = false;
        });
      } else {
        setState(() {
          _isLoadingUserName = false;
        });
      }
    } catch (e) {
      // 🔹 В случае ошибки просто не показываем имя
      if (mounted) {
        setState(() {
          _isLoadingUserName = false;
        });
      }
    }
  }

  /// 🔹 Обработка нажатия на цифру
  void _onNumberPressed(String number) {
    if (_code.length < 4) {
      setState(() {
        _code += number;
      });

      // 🔹 Если код полностью введён (4 цифры), проверяем PIN-код
      if (_code.length == 4) {
        _checkPinCode();
      }
    }
  }

  /// 🔹 Проверка PIN-кода через API
  Future<void> _checkPinCode() async {
    // 🔹 Получаем userId и phone из аргументов маршрута или из AuthService (холодный старт)
    final args = ModalRoute.of(context)?.settings.arguments;
    int? userId = (args is Map && args.containsKey('userId'))
        ? args['userId'] as int
        : null;
    String phone = (args is Map && args.containsKey('phone'))
        ? args['phone'] as String
        : '';
    if (phone.isEmpty) {
      final auth = ref.read(authServiceProvider);
      phone = await auth.getPhone() ?? '';
    }
    // 🔹 Если телефона нет в хранилище (старый вход до savePhone) — подгружаем по API
    // Сначала обновляем access_token при необходимости (он живёт ~15 мин, при холодном старте мог истечь)
    if (phone.isEmpty) {
      final auth = ref.read(authServiceProvider);
      try {
        await auth.validateToken();
        if (!mounted) return;
        final api = ref.read(apiServiceProvider);
        final data = await api.post('/get_my_phone.php');
        if (data['ok'] == true && data['phone'] != null) {
          phone = data['phone'].toString();
          await auth.savePhone(phone);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('get_my_phone error: $e');
        // 🔹 Токены недействительны (access истёк, refresh не обновился) — выход и переход на вход
        final err = e.toString().toLowerCase();
        if (err.contains('токен') ||
            err.contains('token') ||
            err.contains('refresh_token') ||
            err.contains('401') ||
            err.contains('недействителен')) {
          if (!mounted) return;
          await auth.logout();
          ref.invalidate(currentUserIdProvider);
          ref.invalidate(isAuthorizedProvider);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Сессия истекла. Войдите снова.'),
              backgroundColor: AppColors.error,
            ),
          );
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      }
    }
    if (userId == null) {
      final auth = ref.read(authServiceProvider);
      userId = await auth.getUserId();
    }

    if (userId == null || phone.isEmpty) {
      if (mounted) {
        setState(() {
          _code = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: не переданы данные пользователя'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);

      final data = await api.post(
        '/check_pin_code.php',
        body: {'pin_code': _code, 'phone': phone},
      );

      if (kDebugMode) {
        debugPrint('check_pin_code response: $data');
      }

      if (data['success'] == true && mounted) {
        // 🔹 PIN-код верный - загружаем данные ленты и переходим на экран ленты
        developer.log(
          '[ENTER_CODE_SCREEN] PIN-код верный, загружаем данные ленты',
          name: 'EnterCodeScreen',
        );

        try {
          // Загружаем сохраненные фильтры из SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final showTrainings =
              prefs.getBool('lenta_filter_show_trainings') ?? true;
          final showPosts = prefs.getBool('lenta_filter_show_posts') ?? true;
          final showOwn = prefs.getBool('lenta_filter_show_own') ?? true;
          final showOthers = prefs.getBool('lenta_filter_show_others') ?? true;

          // Загружаем данные ленты через провайдер
          await ref
              .read(lentaProvider(userId).notifier)
              .loadInitial(
                showTrainings: showTrainings,
                showPosts: showPosts,
                showOwn: showOwn,
                showOthers: showOthers,
              );

          developer.log(
            '[ENTER_CODE_SCREEN] Данные ленты загружены',
            name: 'EnterCodeScreen',
          );
        } catch (e, stackTrace) {
          developer.log(
            '[ENTER_CODE_SCREEN] Ошибка при загрузке данных: $e',
            name: 'EnterCodeScreen',
            error: e,
            stackTrace: stackTrace,
          );
          // Игнорируем ошибки загрузки - данные загрузятся на экране ленты
        }

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/lenta',
            arguments: {'userId': userId},
          );
        }
      } else {
        // 🔹 PIN-код неверный - очищаем поле и показываем ошибку
        if (mounted) {
          setState(() {
            _code = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']?.toString() ?? 'Неверный PIN-код'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        '[ENTER_CODE_SCREEN] Ошибка при проверке PIN-кода: $e',
        name: 'EnterCodeScreen',
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        setState(() {
          _code = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при проверке PIN-кода. Попробуйте ещё раз.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 🔹 Обработка удаления последней цифры
  void _onDeletePressed() {
    if (_code.isNotEmpty) {
      setState(() {
        _code = _code.substring(0, _code.length - 1);
      });
    }
  }

  /// 🔹 Обработка нажатия на кнопку выхода
  void _onExitPressed() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.darkSurface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = MediaQuery.of(context).size;
            return Stack(
              fit: StackFit.expand,
              children: [
                // ─────────── Фоновая картинка (заполняет весь экран включая системные области) ───────────
                Positioned.fill(
                  child: Opacity(
                    opacity: 1.0,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Image.asset(
                        'assets/back.jpg',
                        width: screenSize.width,
                        height: screenSize.height,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  ),
                ),
                // ─────────── Темный градиент поверх фоновой картинки ───────────
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(
                            alpha: 0.6,
                          ), // Сверху менее прозрачный (темнее)
                          Colors.black.withValues(
                            alpha: 0.2,
                          ), // Снизу более прозрачный (светлее)
                        ],
                      ),
                    ),
                  ),
                ),
                // ─────────── Контент ───────────
                Stack(
                  fit: StackFit.expand,
                  children: [
                    // ─────────── Логотип на 1/3 от высоты экрана ───────────
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).size.height * 0.085,
                        ),
                        child: Opacity(
                          opacity: 0.9,
                          child: Image.asset(
                            'assets/gorizont.png',
                            width: 180,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                    // ─────────── Приветствие, заголовок и индикаторы ввода кода с отступом 40% от верха ───────────
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.35,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🔹 Приветствие с именем пользователя (или невидимый плейсхолдер при загрузке)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AnimatedOpacity(
                              opacity: _isLoadingUserName ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeIn,
                              child: Text(
                                _userFirstName.isNotEmpty
                                    ? 'Здравствуйте, $_userFirstName'
                                    : 'Здравствуйте, ',
                                style: const TextStyle(
                                  color: AppColors.surface,
                                  fontSize: 20,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // 🔹 Заголовок
                          const SizedBox(height: 25),
                          const Text(
                            "Введите код для входа",
                            style: TextStyle(
                              color: AppColors.surface,
                              fontSize: 16,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          // 🔹 Индикаторы ввода кода (4 кружочка)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final isFilled = index < _code.length;
                              return Container(
                                width: 16,
                                height: 16,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isFilled
                                      ? AppColors.surface
                                      : AppColors.textPrimary.withValues(
                                          alpha: 0.3,
                                        ),
                                  border: Border.all(
                                    color: AppColors.surface.withValues(
                                      alpha: 0.7,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    // ─────────── Цифровая клавиатура с отступом 10% от низа ───────────
                    Positioned(
                      bottom: MediaQuery.of(context).size.height * 0.1,
                      left: 0,
                      right: 0,
                      child: _buildNumpad(screenSize),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 🔹 Построение цифровой клавиатуры
  Widget _buildNumpad(Size screenSize) {
    // 🔹 Адаптивные размеры: промежуток между кнопками = 4% от ширины экрана
    final buttonSpacing = screenSize.width * 0.06;
    // 🔹 Адаптивный размер кнопки = 15% от ширины экрана
    final buttonSize = screenSize.width * 0.15;
    // 🔹 Адаптивный вертикальный отступ между строками = 2.5% от ширины экрана
    final rowSpacing = screenSize.width * 0.03;

    return Column(
      children: [
        // Первая строка: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('1', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('2', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('3', buttonSize),
          ],
        ),
        SizedBox(height: rowSpacing),
        // Вторая строка: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('4', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('5', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('6', buttonSize),
          ],
        ),
        SizedBox(height: rowSpacing),
        // Третья строка: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('7', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('8', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('9', buttonSize),
          ],
        ),
        SizedBox(height: rowSpacing),
        // Четвёртая строка: кнопка выхода, 0, кнопка удаления
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔹 Кнопка выхода
            _buildExitButton(buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('0', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildDeleteButton(buttonSize),
          ],
        ),
      ],
    );
  }

  /// 🔹 Создание кнопки с цифрой
  Widget _buildNumberButton(String number, double size) {
    return GestureDetector(
      onTap: () => _onNumberPressed(number),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textPrimary.withValues(alpha: 0.3),
          border: Border.all(
            color: AppColors.surface.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.surface,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 Создание кнопки выхода
  Widget _buildExitButton(double size) {
    return GestureDetector(
      onTap: _onExitPressed,
      child: SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Text(
            'Выйти',
            style: TextStyle(
              color: AppColors.surface,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 Создание кнопки удаления
  Widget _buildDeleteButton(double size) {
    return GestureDetector(
      onTap: _onDeletePressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textPrimary.withValues(alpha: 0.3),
          border: Border.all(
            color: AppColors.surface.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: AppColors.surface,
            size: 24,
          ),
        ),
      ),
    );
  }
}
