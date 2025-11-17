import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_shell.dart';
import '../../../theme/app_theme.dart';
import '../../providers/services/api_provider.dart';
import '../../service/api_service.dart' show ApiException;
import '../../widgets/auth/sms_code_input.dart';
import '../../widgets/auth/resend_code_button.dart';

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

  /// 🔹 Флаг загрузки (блокирует повторные отправки)
  bool _isLoading = false;

  /// 🔹 Флаг отправки кода (блокирует ввод во время проверки)
  bool _isSubmitting = false;

  /// 🔹 Сообщение об ошибке (если есть)
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 🔹 При открытии экрана сразу отправляем запрос на вход пользователя
    fetchApiData();
  }

  /// 🔹 Метод для первоначальной отправки запроса входа пользователя
  Future<void> fetchApiData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/login_user.php',
        body: {'phone': widget.phone},
      );
      debugPrint('fetchApiData response: $data');
    } on ApiException catch (e) {
      // 🔹 Ошибки отправки кода только логируем, не показываем пользователю
      debugPrint("fetchApiData error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 🔹 Метод для повторной отправки кода на номер
  Future<void> resendCode() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/resendlgn_code.php',
        body: {'phone': widget.phone},
      );
      debugPrint('resendCode response: $data');
      // 🔹 После успешной отправки перезапускаем таймер
      _resendButtonKey.currentState?.resetTimer();
    } on ApiException catch (e) {
      // 🔹 Ошибки повторной отправки кода только логируем, не показываем пользователю
      debugPrint("resendCode error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 🔹 Метод для проверки введённого кода
  Future<void> enterCode(String userCode) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/enterlgn_code.php',
        body: {'code': userCode, 'phone': widget.phone},
      );

      // ApiService уже распарсил JSON
      final codeValue = int.tryParse(data['code'].toString()) ?? 0;

      // 🔹 Если код валиден и виджет всё ещё в дереве
      if (codeValue > 0 && mounted) {
        //await storage.write(key: "access_token", value: data["access_token"]);
        //await storage.write(key: "refresh_token", value: data["refresh_token"]);
        //await storage.write(key: "user_id", value: data['code']);
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
          setState(() {
            _errorMessage = 'Неверный код. Попробуйте ещё раз.';
          });
          _smsCodeInputKey.currentState?.clear();
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка проверки кода: ${e.message}';
        });
        _smsCodeInputKey.currentState?.clear();
      }
      debugPrint("enterCode error: $e");
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AuthShell(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 100,
          ),
          overlayAlpha: 0.5,
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
                onCodeComplete: _isSubmitting ? null : enterCode,
                enabled: !_isSubmitting,
              ),
              // 🔹 Показываем ошибку, если есть
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                SelectableText.rich(
                  TextSpan(
                    text: _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 15),
              // 🔹 Используем общий виджет для кнопки повторной отправки
              ResendCodeButton(
                key: _resendButtonKey,
                onPressed: _isLoading ? null : resendCode,
                initialSeconds: 60,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
