import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_shell.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../providers/services/api_provider.dart';
import '../../../providers/services/auth_provider.dart';
import '../../../core/providers/form_state_provider.dart';
import '../widgets/sms_code_input.dart';
import '../widgets/resend_code_button.dart';
import '../../../core/widgets/form_error_display.dart';

/// 🔹 Экран ввода кода из SMS для подтверждения номера телефона
/// Используется после регистрации телефона для подтверждения кода.
class AddAccSmsScreen extends ConsumerStatefulWidget {
  /// 🔹 Номер телефона, на который отправлен код
  final String phone;
  /// 🔹 ID пользователя, если он уже был создан (например, через check_phone)
  final int? userId;

  const AddAccSmsScreen({
    super.key,
    required this.phone,
    this.userId,
  });

  @override
  ConsumerState<AddAccSmsScreen> createState() => AddAccSmsScreenState();
}

class AddAccSmsScreenState extends ConsumerState<AddAccSmsScreen> {
  /// 🔹 Ключ для доступа к виджету SmsCodeInput (для очистки полей)
  final GlobalKey<SmsCodeInputState> _smsCodeInputKey = GlobalKey();

  /// 🔹 Ключ для доступа к виджету ResendCodeButton (для перезапуска таймера)
  final GlobalKey<ResendCodeButtonState> _resendButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 🔹 При открытии экрана отправляем запрос на регистрацию пользователя,
    // 🔹 только если userId не был передан (пользователь ещё не создан)
    // 🔹 Обёртываем в Future, чтобы избежать изменения провайдера во время построения виджета
    if (widget.userId == null) {
      Future(() => fetchApiData());
    }
  }

  /// 🔹 Метод для первоначальной отправки запроса регистрации пользователя
  /// Отправляет номер телефона на сервер для генерации SMS-кода
  /// Вызывается только если пользователь ещё не был создан (userId == null)
  Future<void> fetchApiData() async {
    final formState = ref.read(formStateProvider);
    if (formState.isLoading) return;

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);

    await formNotifier.submitWithLoading(
      () async {
        final data = await api.post(
          '/registry_user.php',
          body: {'phone': widget.phone},
        );
        if (kDebugMode) {
          debugPrint('fetchApiData response: $data');
        }
      },
      // 🔹 Ошибки отправки кода только логируем, не показываем пользователю
      onError: (error) {
        if (kDebugMode) {
          debugPrint('fetchApiData error: $error');
        }
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
          '/resend_code.php',
          body: {'phone': widget.phone},
        );
        if (kDebugMode) {
          debugPrint('resendCode response: $data');
        }
      },
      onSuccess: () {
        // 🔹 После успешной отправки перезапускаем таймер
        _resendButtonKey.currentState?.resetTimer();
      },
      // 🔹 Ошибки повторной отправки кода только логируем, не показываем пользователю
      onError: (error) {
        if (kDebugMode) {
          debugPrint('resendCode error: $error');
        }
        formNotifier.clearGeneralError();
      },
    );
  }

  /// 🔹 Метод для проверки введённого кода
  /// Если сервер вернул корректный код, происходит переход на следующий экран регистрации
  Future<void> enterCode(String userCode) async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);

    await formNotifier.submit(
      () async {
        final data = await api.post(
          '/enter_code.php',
          body: {'code': userCode, 'phone': widget.phone},
        );

        // ApiService уже распарсил JSON
        final codeValue = int.tryParse(data['code'].toString()) ?? 0;
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;

        // 🔹 Если код валиден и экран всё ещё "смонтирован", сохраняем токены и переходим к следующему шагу
        if (codeValue > 0 && accessToken != null && refreshToken != null && mounted) {
          // 🔹 Сохраняем токены в безопасное хранилище
          final auth = ref.read(authServiceProvider);
          
          if (kDebugMode) {
            debugPrint('🔹 Сохранение токенов: userId=$codeValue');
          }
          
          // 🔹 Сохраняем токены и ждем завершения операции
          await auth.saveTokens(accessToken, refreshToken, codeValue);
          
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
          
          // 🔹 Проверяем, что виджет еще монтирован перед навигацией
          if (!mounted) return;

          Navigator.pushReplacementNamed(
            context,
            '/reg_step1', // экран следующего шага регистрации
            arguments: {'userId': codeValue}, // передаём userId
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
          debugPrint('enterCode error: $error');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Получаем состояние формы
    final formState = ref.watch(formStateProvider);

    // 🔹 Получаем высоту клавиатуры для адаптации контента
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // 🔹 Базовый отступ снизу, который уменьшается при появлении клавиатуры
    final verticalPadding = 100.0 - (keyboardHeight * 0.3).clamp(0.0, 60.0);

    return Scaffold(
      // 🔹 Отключаем автоматическую прокрутку Scaffold, используем свою
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AuthShell(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 40,
            vertical: verticalPadding,
          ),
          overlayAlpha: 0.5,
          child: SingleChildScrollView(
            // 🔹 Прокручиваем контент при появлении клавиатуры
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Введите код, отправленный на номер\n${widget.phone}",
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 15,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 20),
                // 🔹 Используем общий виджет для ввода SMS-кода
                SmsCodeInput(
                  key: _smsCodeInputKey,
                  onCodeComplete: formState.isSubmitting ? null : enterCode,
                  enabled: !formState.isSubmitting,
                ),
                // 🔹 Показываем ошибку, если есть
                if (formState.error != null) ...[
                  const SizedBox(height: 12),
                  FormErrorDisplay(formState: formState),
                ],
                const SizedBox(height: 15),
                // 🔹 Используем общий виджет для кнопки повторной отправки
                ResendCodeButton(
                  key: _resendButtonKey,
                  onPressed: formState.isLoading ? null : resendCode,
                  initialSeconds: 60,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
