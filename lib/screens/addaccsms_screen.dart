import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Экран ввода кода из SMS для подтверждения номера телефона
class AddAccSmsScreen extends StatefulWidget {
  final String phone; // Номер телефона, на который отправлен код
  const AddAccSmsScreen({super.key, required this.phone});

  @override
  State<AddAccSmsScreen> createState() => AddAccSmsScreenState();
}

class AddAccSmsScreenState extends State<AddAccSmsScreen> {
  final controllers = List.generate(6, (_) => TextEditingController());
  final nodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    fetchApiData();
  }

  Future<void> fetchApiData() async {
    try {
      await http.post(
        Uri.parse('http://api.paceup.ru/registry_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );
    } catch (e) {
      debugPrint("fetchApiData error: $e");
    }
  }

  Future<void> resendCode() async {
    try {
      await http.post(
        Uri.parse('http://api.paceup.ru/resend_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );
    } catch (e) {
      debugPrint("resendCode error: $e");
    }
  }

  Future<void> enterCode(String userCode) async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/enter_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': userCode, 'phone': widget.phone}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final codeValue = int.tryParse(data['code'].toString()) ?? 0;

        if (codeValue > 0 && mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/regstep1',
            arguments: {'userId': codeValue},
          );
        }
      }
    } catch (e) {
      debugPrint("enterCode error: $e");
    }
  }

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
        maxLength: 1,
        decoration: InputDecoration(
          counterText: "",
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
          if (v.isNotEmpty && index < 5) {
            nodes[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            nodes[index - 1].requestFocus();
          } else if (index == 5) {
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
          Image.asset("assets/background.png", fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.5)),

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
                  Text(
                    "Введите код, отправленный на номер\n${widget.phone}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontFamily: "Inter",
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      6,
                      (index) => _buildCodeField(index),
                    ),
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
