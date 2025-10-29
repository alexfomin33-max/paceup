import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_shell.dart';
import '../../../theme/app_theme.dart';

//import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🔹 Экран ввода кода из SMS для подтверждения номера телефона
/// Используется после регистрации телефона для подтверждения кода.
class AddAccSmsScreen extends StatefulWidget {
  /// 🔹 Номер телефона, на который отправлен код
  final String phone;

  const AddAccSmsScreen({super.key, required this.phone});

  @override
  State<AddAccSmsScreen> createState() => AddAccSmsScreenState();
}

class AddAccSmsScreenState extends State<AddAccSmsScreen> {
  // 🔹 Контроллеры для каждого из 6 полей ввода кода
  final controllers = List.generate(6, (_) => TextEditingController());

  // 🔹 FocusNode для каждого поля, чтобы автоматически переходить к следующему при вводе
  final nodes = List.generate(6, (_) => FocusNode());
  //final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    // 🔹 При открытии экрана сразу отправляем запрос на регистрацию пользователя
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
  /// Отправляет номер телефона на сервер для генерации SMS-кода
  Future<void> fetchApiData() async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/registry_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );
      debugPrint('fetchApiData response: ${response.body}');
    } catch (e) {
      // 🔹 Ошибки игнорируются, можно добавить логирование или уведомление
      // debugPrint('fetchApiData error: $e');
    }
  }

  /// 🔹 Метод для повторной отправки кода на номер
  Future<void> resendCode() async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/resend_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );
      debugPrint('resendCode response: ${response.body}');
    } catch (e) {
      // 🔹 Лог ошибок при повторной отправке
      // debugPrint('resendCode error: $e');
    }
  }

  /// 🔹 Метод для проверки введенного кода
  /// Если сервер вернул корректный код, происходит переход на следующий экран регистрации
  Future<void> enterCode(String userCode) async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/enter_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': userCode, 'phone': widget.phone}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 🔹 Преобразуем код из ответа сервера в int, если не удалось — 0
        final codeValue = int.tryParse(data['code'].toString()) ?? 0;

        // 🔹 Если код валиден и экран всё ещё "смонтирован", переходим к следующему шагу
        if (codeValue > 0 && mounted) {
          //await storage.write(key: "access_token", value: data["access_token"]);
          //await storage.write(key: "refresh_token", value: data["refresh_token"]);
          //await storage.write(key: "user_id", value: data['code']);
          Navigator.pushReplacementNamed(
            context,
            '/regstep1', // экран следующего шага регистрации
            arguments: {'userId': codeValue}, // передаем userId
          );
        }
      }
    } catch (e) {
      // 🔹 Лог ошибок при проверке кода
      // debugPrint('enterCode error: $e');
    }
  }

  /// 🔹 Генерация отдельного поля для ввода одной цифры кода
  Widget _buildCodeField(int index) {
    return SizedBox(
      width: 45,
      height: 50,
      child: TextFormField(
        controller: controllers[index],
        focusNode: nodes[index],
        style: const TextStyle(color: AppColors.surface, fontSize: 20),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1, // 🔹 Ограничение на одну цифру
        decoration: InputDecoration(
          counterText: "", // 🔹 Скрываем счетчик символов
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
            // Если введена цифра и это не последний индекс — переходим к следующему полю
            nodes[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            // Если удалили цифру — возвращаемся к предыдущему полю
            nodes[index - 1].requestFocus();
          } else if (index == 5) {
            // Если последний символ введен — объединяем код и отправляем на сервер
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
      body: AuthShell(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 100,
        ),
        overlayAlpha: 0.5, // раньше у вас было 127/255 ≈ 0.5
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Введите код, отправленный на номер\n${widget.phone}",
              style: const TextStyle(color: AppColors.surface, fontSize: 15),
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
    );
  }
}
