import "package:flutter/material.dart";
import "package:mask_input_formatter/mask_input_formatter.dart";

class CreateaccScreen extends StatelessWidget {
  const CreateaccScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AddAccScreen();
  }
}

class AddAccScreen extends StatelessWidget {
  AddAccScreen({super.key});

  final TextEditingController phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset("assets/background.png", fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.5)),

          /// 🔹 Логотип — как на WelcomeScreen
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

          /// 🔹 Поле ввода, кнопка "Зарегистрироваться", текст условий и кнопка "Назад"
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30, left: 40, right: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Поле ввода телефона
                  SizedBox(
                    width: double.infinity,
                    child: TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      inputFormatters: [
                        MaskInputFormatter(mask: '+# (###) ###-##-##'),
                      ],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(
                            width: 1.0,
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            width: 1.0,
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            width: 1.0,
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        hintText: "+7 (999) 123-45-67",
                        labelText: "Телефон",
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        hintStyle: const TextStyle(color: Colors.grey),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: "Inter",
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Кнопка "Зарегистрироваться"
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/addaccsms',
                          arguments: {'phone': phoneController.text},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // белая кнопка
                        foregroundColor: Colors.black, // текст чёрный
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 0, // убираем тень, если нужна плоская
                      ),
                      child: const Text(
                        "Зарегистрироваться",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: "Inter",
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🔹 Текст условий
                  SizedBox(
                    width: 250,
                    child: const Text(
                      "Регистрируясь, вы принимаете Условия предоставления услуг и Политику конфиденциальности",
                      style: TextStyle(
                        color: Color.fromARGB(255, 192, 192, 192),
                        fontSize: 12,
                        fontFamily: "Inter",
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // 🔹 Кнопка Назад без рамки
                  SizedBox(
                    width: 100,
                    height: 36,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/home');
                      },
                      style: ButtonStyle(
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        animationDuration: const Duration(milliseconds: 0),
                      ),
                      child: const Text(
                        "<- Назад",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Inter",
                        ),
                      ),
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
