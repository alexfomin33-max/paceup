import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../providers/services/api_provider.dart';
import '../../../providers/services/auth_provider.dart';
import '../../../providers/services/fcm_provider.dart';
import '../../../core/providers/form_state_provider.dart';
import '../widgets/sms_code_input.dart';
import '../../../core/widgets/form_error_display.dart';

/// 🔹 Экран для ввода кода из SMS для подтверждения номера телефона
class LoginSmsScreen extends ConsumerStatefulWidget {
  /// 🔹 Номер телефона, на который отправлен код
  final String phone;

  const LoginSmsScreen({super.key, required this.phone});

  @override
  ConsumerState<LoginSmsScreen> createState() => LoginSmsScreenState();
}

class LoginSmsScreenState extends ConsumerState<LoginSmsScreen> {
  /// 🔹 Ключ для доступа к виджету SmsCodeInput (для очистки полей)
  final GlobalKey<SmsCodeInputState> _smsCodeInputKey = GlobalKey();

  /// 🔹 Таймер для обратного отсчёта до возможности повторной отправки
  Timer? _resendTimer;

  /// 🔹 Оставшееся время до возможности повторной отправки (в секундах)
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    // 🔹 Запускаем таймер при инициализации
    _startTimer();
    // 🔹 При открытии экрана отправляем запрос на вход пользователя
    // Откладываем выполнение до завершения сборки виджета, чтобы избежать
    // ошибки "Tried to modify a provider while the widget tree was building"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchApiData();
    });
  }

  @override
  void dispose() {
    // 🔹 Отменяем таймер при уничтожении виджета
    _resendTimer?.cancel();
    super.dispose();
  }

  /// 🔹 Запуск таймера обратного отсчёта
  void _startTimer() {
    _remainingSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// 🔹 Перезапуск таймера (вызывается после успешной отправки)
  void _resetTimer() {
    _startTimer();
  }

  /// 🔹 Метод для первоначальной отправки запроса входа пользователя
  Future<void> fetchApiData() async {
    final formState = ref.read(formStateProvider);
    if (formState.isLoading) return;

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);

    await formNotifier.submitWithLoading(
      () async {
        final data = await api.post(
          '/login_user.php',
          body: {'phone': widget.phone},
        );
        if (kDebugMode) {
          debugPrint('fetchApiData response: $data');
        }
      },
      // 🔹 Ошибки отправки кода только логируем, не показываем пользователю
      onError: (error) {
        if (kDebugMode) {
          debugPrint("fetchApiData error: $error");
        }
        // Очищаем ошибку, чтобы не показывать пользователю
        formNotifier.clearGeneralError();
      },
    );
  }

  /// 🔹 Метод для повторной отправки кода на номер
  Future<void> resendCode() async {
    final formState = ref.read(formStateProvider);
    if (formState.isLoading) return;

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);

    await formNotifier.submitWithLoading(
      () async {
        final data = await api.post(
          '/resendlgn_code.php',
          body: {'phone': widget.phone},
        );
        if (kDebugMode) {
          debugPrint('resendCode response: $data');
        }
      },
      onSuccess: () {
        // 🔹 После успешной отправки перезапускаем таймер
        _resetTimer();
      },
      // 🔹 Ошибки повторной отправки кода только логируем, не показываем пользователю
      onError: (error) {
        if (kDebugMode) {
          debugPrint("resendCode error: $error");
        }
        formNotifier.clearGeneralError();
      },
    );
  }

  /// 🔹 Метод для проверки введённого кода
  Future<void> enterCode(String userCode) async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);

    await formNotifier.submit(
      () async {
        final data = await api.post(
          '/enterlgn_code.php',
          body: {'code': userCode, 'phone': widget.phone},
        );

        // ApiService уже распарсил JSON
        final codeValue = int.tryParse(data['code'].toString()) ?? 0;
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;

        // 🔹 Если код валиден и виджет всё ещё в дереве, сохраняем токены
        if (codeValue > 0 && accessToken != null && refreshToken != null && mounted) {
          // 🔹 Сохраняем токены в безопасное хранилище
          final auth = ref.read(authServiceProvider);
          
          if (kDebugMode) {
            debugPrint('🔹 Сохранение токенов: userId=$codeValue');
          }
          
          // 🔹 Сохраняем токены и ждем завершения операции
          await auth.saveTokens(accessToken, refreshToken, codeValue);
          // 🔹 Сохраняем телефон для экрана PIN при холодном старте приложения
          await auth.savePhone(widget.phone);
          
          // 🔹 Дополнительная проверка: убеждаемся, что токены действительно сохранились
          final hasTokens = await auth.hasStoredTokens();
          if (!hasTokens) {
            if (kDebugMode) {
              debugPrint('⚠️ ОШИБКА: Токены не сохранились после операции saveTokens!');
            }
            throw Exception('Не удалось сохранить токены');
          }
          
          if (kDebugMode) {
            debugPrint('✅ Токены успешно сохранены и проверены');
          }

          // 🔹 Инвалидируем провайдеры авторизации, чтобы экран профиля и другие
          // экраны получили актуальный userId после входа (иначе показывается
          // «Необходима авторизация» из-за закэшированного состояния).
          ref.invalidate(currentUserIdProvider);
          ref.invalidate(isAuthorizedProvider);

          // Регистрируем FCM токен после успешного входа (только на Android, временно отключено для iOS)
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

          // 🔹 Проверяем, что виджет еще монтирован перед навигацией
          if (!mounted) return;
          
          Navigator.pushReplacementNamed(
            context,
            '/entercode',
            arguments: {
              'userId': codeValue,
              'phone': widget.phone,
            }, // передаём userId и phone на следующий экран
          );
        } else {
          // 🔹 Неверный код — показываем ошибку и очищаем поля
          if (mounted) {
            formNotifier.setError('Неверный код. Попробуйте ещё раз.');
            _smsCodeInputKey.currentState?.clear();
          }
          throw Exception('Неверный код');
        }
      },
      onError: (error) {
        if (mounted) {
          _smsCodeInputKey.currentState?.clear();
        }
        if (kDebugMode) {
          debugPrint("enterCode error: $error");
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Получаем состояние формы
    final formState = ref.watch(formStateProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.darkSurface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          // 🔹 Отключаем автоматическую прокрутку Scaffold, используем свою
          resizeToAvoidBottomInset: true,
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
                      // ─────────── Форма внизу ───────────
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height * 0.1,
                            left: MediaQuery.of(context).size.width * 0.1,
                            right: MediaQuery.of(context).size.width * 0.1,
                          ),
                          child: SingleChildScrollView(
                            // 🔹 Прокручиваем контент при появлении клавиатуры
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🔹 Текст с номером телефона
                                Text(
                                  "Введите код, отправленный на номер\n${widget.phone}",
                                  style: const TextStyle(
                                    color: AppColors.surface,
                                    fontSize: 15,
                                    fontFamily: 'Inter',
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                                const SizedBox(height: 20),
                                // 🔹 Используем общий виджет для ввода SMS-кода
                                SmsCodeInput(
                                  key: _smsCodeInputKey,
                                  onCodeComplete: formState.isSubmitting
                                      ? null
                                      : enterCode,
                                  enabled: !formState.isSubmitting,
                                ),
                                // 🔹 Показываем ошибку, если есть
                                Builder(
                                  builder: (context) {
                                    if (formState.hasErrors) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: FormErrorDisplay(
                                          formState: formState,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                                const SizedBox(height: 20),
                                // 🔹 Кнопка "Отправить заново" в стиле "Получить код"
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        (_remainingSeconds > 0 ||
                                            formState.isLoading)
                                        ? null
                                        : resendCode,
                                    style: ButtonStyle(
                                      backgroundColor:
                                          WidgetStateProperty.resolveWith((
                                            states,
                                          ) {
                                            if (states.contains(
                                              WidgetState.disabled,
                                            )) {
                                              return AppColors.disabledBg
                                                  .withValues(alpha: 0.5);
                                            }
                                            return AppColors.getSurfaceColor(
                                              context,
                                            );
                                          }),
                                      foregroundColor:
                                          WidgetStateProperty.resolveWith((
                                            states,
                                          ) {
                                            if (states.contains(
                                              WidgetState.disabled,
                                            )) {
                                              return AppColors.textPrimary
                                                  .withValues(alpha: 0.5);
                                            }
                                            return AppColors.textPrimary;
                                          }),
                                      padding: const WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(vertical: 15),
                                      ),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.xxl,
                                          ),
                                        ),
                                      ),
                                      elevation: const WidgetStatePropertyAll(
                                        0,
                                      ),
                                    ),
                                    child: formState.isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CupertinoActivityIndicator(
                                              radius: 10,
                                              color: AppColors.textPrimary,
                                            ),
                                          )
                                        : Text(
                                            _remainingSeconds > 0
                                                ? "Отправить заново ($_remainingSecondsс)"
                                                : "Отправить заново",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ─────────── Кнопка "Назад" в верхнем левом углу ───────────
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.076,
                    left: 16,
                    child: Builder(
                      builder: (context) {
                        final formState = ref.watch(formStateProvider);
                        return TextButton(
                          onPressed: formState.isSubmitting
                              ? null
                              : () => Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                ),
                          style: const ButtonStyle(
                            overlayColor: WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            animationDuration: Duration(milliseconds: 0),
                            padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
                            minimumSize: WidgetStatePropertyAll(Size(40, 40)),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppColors.surface,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
