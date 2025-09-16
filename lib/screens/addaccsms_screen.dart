import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  /// 🔹 Метод для первоначальной отправки запроса регистрации пользователя
  /// Отправляет номер телефона на сервер для генерации SMS-кода
  Future<void> fetchApiData() async {
    try {
      await http.post(
        Uri.parse('http://api.paceup.ru/registry_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );
    } catch (e) {
      // 🔹 Ошибки игнорируются, можно добавить логирование или уведомление
      // debugPrint('fetchApiData error: $e');
    }
  }

  /// 🔹 Метод для повторной отправки кода на номер
  Future<void> resendCode() async {
    try {
      await http.post(
        Uri.parse('http://api.paceup.ru/resend_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );
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
        style: const TextStyle(color: Colors.white, fontSize: 20),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1, // 🔹 Ограничение на одну цифру
        decoration: InputDecoration(
          counterText: "", // 🔹 Скрываем счетчик символов
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
      body: Stack(
        fit: StackFit.expand, // 🔹 Заполнение всего экрана
        children: [
          // 🔹 Фоновое изображение
          Image.asset("assets/background.png", fit: BoxFit.cover),

          // 🔹 Полупрозрачный черный слой поверх фона
          Container(color: Colors.black.withValues(alpha: 127)),

          // 🔹 Логотип приложения сверху
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

          // 🔹 Блок ввода кода и кнопки
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
                  // 🔹 Инструкция для пользователя
                  Text(
                    "Введите код, отправленный на номер\n${widget.phone}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontFamily: "Inter",
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🔹 Ряд из 6 полей для ввода кода
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      6,
                      (index) => _buildCodeField(index),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 🔹 Кнопка "Отправить заново"
                  TextButton(
                    onPressed: resendCode, // 🔹 Повторная отправка кода
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
                        fontFamily: "Inter",
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
