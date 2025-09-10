import 'package:flutter/material.dart';
//import 'createacc_screen.dart';
// import '../design/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeScreen();
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset("assets/background.png", fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.4)),
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
              padding: const EdgeInsets.only(bottom: 150, left: 40, right: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildButton(
                    text: "Создать аккаунт",
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/createacc',);
                      /*Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateaccScreen(),
                        ),
                      );*/
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildButton(
                    text: "Войти",
                    onPressed: () {
                      // действие для входа
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Универсальный метод для кнопки
  Widget _buildButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 15),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Colors.white, width: 1),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          animationDuration: const Duration(milliseconds: 0),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: "Inter",
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
