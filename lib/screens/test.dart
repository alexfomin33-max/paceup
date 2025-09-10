import "package:flutter/material.dart";
import "createacc_screen.dart";

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
                top: MediaQuery.of(context).size.height * 0.10,
              ),
              child: Image.asset(
                "assets/logo_icon.png",
                width: 125,
                height: 125,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 60,
              ), // отступ от низа экрана
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // чтобы колонка занимала минимум места
                children: [
                  SizedBox(
                    width: 250,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateaccScreen(),
                          ),
                        );
                      },
                      style: ButtonStyle(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 15),
                        ),
                        side: const WidgetStatePropertyAll(
                          BorderSide(color: Colors.white, width: 1),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        animationDuration: Duration(milliseconds: 0),
                      ),
                      child: const Text(
                        "Создать аккаунт",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          fontFamily: "Inter",
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ), // 🔥 фиксированный отступ между кнопками
                  SizedBox(
                    width: 250,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: ButtonStyle(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 15),
                        ),
                        side: const WidgetStatePropertyAll(
                          BorderSide(color: Colors.white, width: 1),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        animationDuration: Duration(milliseconds: 0),
                      ),
                      child: const Text(
                        "Войти",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          fontFamily: "Inter",
                        ),
                        textAlign: TextAlign.center,
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
