import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
//import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🔹 Экран для ввода кода из SMS для подтверждения номера телефона
class LoginSmsScreen extends StatefulWidget {
  final String phone; // Номер телефона, на который отправлен код

  const LoginSmsScreen({super.key, required this.phone});

  @override
  State<LoginSmsScreen> createState() => LoginSmsScreenState();
}

class LoginSmsScreenState extends State<LoginSmsScreen> {
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

  /// 🔹 Метод для первоначальной отправки запроса регистрации пользователя
  Future<void> fetchApiData() async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/login_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );
      print(response.body);
    } catch (e) {
      // 🔹 Логируем ошибки в консоль
      debugPrint("fetchApiData error: $e");
    }
  }

  /// 🔹 Метод для повторной отправки кода на номер
  Future<void> resendCode() async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/resendlgn_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );
      print(response.body);
    } catch (e) {
      debugPrint("resendCode error: $e");
    }
  }

  /// 🔹 Метод для проверки введенного кода
  Future<void> enterCode(String userCode) async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/enterlgn_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': userCode, 'phone': widget.phone}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 🔹 Преобразуем код в int, если не получилось — 0
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
      }
    } catch (e) {
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
        style: const TextStyle(color: Colors.white, fontSize: 20),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1, // только одна цифра
        decoration: InputDecoration(
          counterText: "", // скрыть счетчик символов
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(10),
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// 🔹 Фоновое изображение
          Image.asset("assets/background.png", fit: BoxFit.cover),

          /// 🔹 Полупрозрачный черный слой поверх фона
          Container(color: Colors.black.withValues(alpha: 0.5)),

          /// 🔹 Логотип приложения сверху
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.11,
              ),
              child: Image.asset(
                "assets/logo_icon.png",
                width: 175,
                height: 175,
                fit: BoxFit.contain,
              ),
            ),
          ),

          /// 🔹 Блок ввода кода и кнопки
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 100,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🔹 Инструкция для пользователя
                  Text(
                    "Введите код, отправленный на номер\n${widget.phone}",
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 20),

                  /// 🔹 Ряд полей для ввода кода
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      6,
                      (index) => _buildCodeField(index),
                    ),
                  ),
                  const SizedBox(height: 15),

                  /// 🔹 Кнопка "Отправить заново"
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
                        color: Colors.white,
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
        ],
      ),
    );
  }
}
