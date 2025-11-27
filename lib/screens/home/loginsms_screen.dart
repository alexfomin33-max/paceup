import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_shell.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/services/api_provider.dart';
import '../../core/providers/form_state_provider.dart';
import '../../core/widgets/auth/sms_code_input.dart';
import '../../core/widgets/auth/resend_code_button.dart';
import '../../core/widgets/form_error_display.dart';

//import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  /// 🔹 Ключ для доступа к виджету ResendCodeButton (для перезапуска таймера)
  final GlobalKey<ResendCodeButtonState> _resendButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 🔹 При открытии экрана сразу отправляем запрос на вход пользователя
    fetchApiData();
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
        debugPrint('fetchApiData response: $data');
      },
      // 🔹 Ошибки отправки кода только логируем, не показываем пользователю
      onError: (error) {
        debugPrint("fetchApiData error: $error");
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
        debugPrint('resendCode response: $data');
      },
      onSuccess: () {
        // 🔹 После успешной отправки перезапускаем таймер
        _resendButtonKey.currentState?.resetTimer();
      },
      // 🔹 Ошибки повторной отправки кода только логируем, не показываем пользователю
      onError: (error) {
        debugPrint("resendCode error: $error");
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

        // 🔹 Если код валиден и виджет всё ещё в дереве
        if (codeValue > 0 && mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/lenta',
            arguments: {
              'userId': codeValue,
            }, // передаём userId на следующий экран
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
        debugPrint("enterCode error: $error");
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
                  textAlign: TextAlign.left,
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
