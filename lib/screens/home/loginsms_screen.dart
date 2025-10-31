import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_shell.dart';
import '../../../theme/app_theme.dart';
import '../../providers/services/api_provider.dart';
import '../../service/api_service.dart' show ApiException;

//import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🔹 Экран для ввода кода из SMS для подтверждения номера телефона
class LoginSmsScreen extends ConsumerStatefulWidget {
  final String phone; // Номер телефона, на который отправлен код

  const LoginSmsScreen({super.key, required this.phone});

  @override
  ConsumerState<LoginSmsScreen> createState() => LoginSmsScreenState();
}

class LoginSmsScreenState extends ConsumerState<LoginSmsScreen> {
  /// 🔹 Контроллеры для 6 полей ввода кода
  final controllers = List.generate(6, (_) => TextEditingController());

  /// 🔹 FocusNode для каждого поля, чтобы автоматически переключаться между ними
  final nodes = List.generate(6, (_) => FocusNode());
  //final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();

    /// 🔹 При открытии экрана сразу отправляем запрос на регистрацию пользователя
    fetchApiData();
  }

  @override
  void dispose() {
    // ✅ ДОБАВИЛИ: аккуратно освобождаем ресурсы
    for (final c in controllers) {
      c.dispose();
    }
    for (final n in nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// 🔹 Метод для первоначальной отправки запроса регистрации пользователя
  Future<void> fetchApiData() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/login_user.php',
        body: {'phone': widget.phone},
      );
      debugPrint(data.toString());
    } on ApiException catch (e) {
      debugPrint("fetchApiData error: $e");
    }
  }

  /// 🔹 Метод для повторной отправки кода на номер
  Future<void> resendCode() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/resendlgn_code.php',
        body: {'phone': widget.phone},
      );
      debugPrint(data.toString());
    } on ApiException catch (e) {
      debugPrint("resendCode error: $e");
    }
  }

  /// 🔹 Метод для проверки введенного кода
  Future<void> enterCode(String userCode) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/enterlgn_code.php',
        body: {'code': userCode, 'phone': widget.phone},
      );

      // ApiService уже распарсил JSON
      final codeValue = int.tryParse(data['code'].toString()) ?? 0;

      /// 🔹 Если код валиден и виджет всё ещё в дереве
      if (codeValue > 0 && mounted) {
        //await storage.write(key: "access_token", value: data["access_token"]);
        //await storage.write(key: "refresh_token", value: data["refresh_token"]);
        //await storage.write(key: "user_id", value: data['code']);
        Navigator.pushReplacementNamed(
          context,
          '/lenta',
          arguments: {
            'userId': codeValue,
          }, // передаем userId на следующий экран
        );
      }
    } on ApiException catch (e) {
      debugPrint("enterCode error: $e");
    }
  }

  /// 🔹 Генерация отдельного поля для ввода одной цифры кода
  Widget _buildCodeField(int index) {
    return SizedBox(
      width: 45, // фиксированная ширина
      height: 50, // фиксированная высота
      child: TextFormField(
        controller: controllers[index],
        focusNode: nodes[index],
        style: const TextStyle(color: AppColors.surface, fontSize: 20),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1, // только одна цифра
        decoration: InputDecoration(
          counterText: "", // скрыть счетчик символов
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.surface),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.surface),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(0),
        ),
        onChanged: (v) {
          // 🔹 Логика автоматического перехода между полями
          if (v.isNotEmpty && index < 5) {
            nodes[index + 1].requestFocus(); // переходим к следующему полю
          } else if (v.isEmpty && index > 0) {
            nodes[index - 1].requestFocus(); // возвращаемся к предыдущему полю
          } else if (index == 5) {
            // 🔹 Если последний символ введен — объединяем код и отправляем
            final code = controllers.map((c) => c.text).join();
            enterCode(code);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AuthShell(
        // как в исходнике: горизонтально 40, вертикально 100
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 100,
        ),
        overlayAlpha: 0.5, // было 0.5 в этом файле
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Введите код, отправленный на номер\n${widget.phone}",
              style: const TextStyle(color: AppColors.surface, fontSize: 15),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) => _buildCodeField(index)),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: resendCode,
              style: const ButtonStyle(
                overlayColor: WidgetStatePropertyAll(Colors.transparent),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              child: const Text(
                "Отправить заново",
                style: TextStyle(
                  color: AppColors.surface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
