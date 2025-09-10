import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
//import 'package:paceip/screens/regstep1_screen.dart';
import 'dart:convert';
//import "lenta_screen.dart";
//import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddAccSmsScreen extends StatefulWidget {
  final String phone;

  const AddAccSmsScreen({super.key, required this.phone});

  @override
  _AddAccSmsScreenState createState() => _AddAccSmsScreenState();
}

class _AddAccSmsScreenState extends State<AddAccSmsScreen> {
  final controllers = List.generate(6, (_) => TextEditingController());
  final nodes = List.generate(6, (_) => FocusNode());
   //временный костыль
  //final storage = const FlutterSecureStorage();

  //String apiResponse = "Загрузка...";
  //String resendResponse = ""; // ответ на повторный запрос

  @override
  void initState() {
    super.initState();
    fetchApiData(); // вызываем API при загрузке экрана
  }

  //отправляем код при открытии окна
  Future<void> fetchApiData() async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/registry_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
         // final data = jsonDecode(response.body);
         // setState(() {
            //apiResponse = data.toString(); // сохраняем результат для отображения
            //final Map<String, dynamic> data = json.decode(response.body);//data['code']
          //});
      } else {
          //"Ошибка: ${response.statusCode}"
        }
    } catch (e) {
      //"Ошибка запроса: $e"
    }
  }

  /// новый код по кнопке отправить заново
  Future<void> resendCode() async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/resend_code.php'), // ⚡️ другой endpoint
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );

      if (response.statusCode == 200) {
        //final Map<String, dynamic> data = json.decode(response.body);//data['code']
      } else {
        //"Ошибка: ${response.statusCode}"
      }
    } catch (e) {
      //"Ошибка отправки кода: $e"
    }
  }

    /// запрос после ввода кода
  Future<void> enterCode(String userCode) async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/enter_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': userCode, 'phone': widget.phone}),
      );

     // print(response.body);

      if (response.statusCode == 200) {
        
        final Map<String, dynamic> data = json.decode(response.body);
        final codeValue = int.tryParse(data['code'].toString()) ?? 0;

        if (codeValue > 0) {
           //временный костыль
          //await storage.write(key: "access_token", value: data["access_token"]);
         // await storage.write(key: "refresh_token", value: data["refresh_token"]);
         // await storage.write(key: "user_id", value: data['code']);
          if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/regstep1', arguments: {'userId': codeValue},);
            /*Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => Regstep1Screen(userId: codeValue,)),
            );*/
        } else {
          //print("Ошибка $codeValue");
        }
      } else {
       // print("Ошибка не 200");
        //"Ошибка: ${response.statusCode}"
      }
    } catch (e) {
      //"Ошибка отправки кода: $e"
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset("assets/background.png", fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.4)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 55),
                  child: Image.asset(
                    "assets/logo_icon.png",
                    width: 125,
                    height: 125,
                    fit: BoxFit.contain,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 15),
                        child: SizedBox(
                          width: 210,
                          child: Text(
                            "Введите код, отправленный на номер \n ${widget.phone}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: "Inter",
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 29,
                              height: 33,
                              child: TextFormField(
                                controller: controllers[index],
                                focusNode: nodes[index],
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.all(1),
                                  counterText: "",
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.white),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.white),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                ),
                                onChanged: (v) {
                                  if (v.isNotEmpty && index < 5) {
                                    nodes[index + 1].requestFocus();
                                  } else if (v.isEmpty && index > 0) {
                                    nodes[index - 1].requestFocus();
                                  } else if (index == 5) {
                                    final code = controllers.map((c) => c.text).join();
                                    //debugPrint('CODE: $code');
                                    enterCode(code);
                                  }
                                },
                                textInputAction: index == 5 ? TextInputAction.done : TextInputAction.next,
                              ),
                            );
                          }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 1, left: 10),
                        child: SizedBox(
                          height: 32,
                          child: OutlinedButton(
                            onPressed: resendCode,
                            style: const ButtonStyle(
                              side: WidgetStatePropertyAll(BorderSide.none),
                              overlayColor: WidgetStatePropertyAll(Colors.transparent),
                              padding: WidgetStatePropertyAll(EdgeInsets.zero),
                            ),
                            child: const Text(
                              "Отправить заново",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w300,
                                fontFamily: "Inter",
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ),
                    /*  Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          "API ответ: $apiResponse",
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),*/
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

