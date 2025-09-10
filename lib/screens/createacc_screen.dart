import "package:flutter/material.dart";
import "package:mask_input_formatter/mask_input_formatter.dart";
import "home_screen.dart";
import "createacccode_screen.dart";

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
          Image.asset(
            "assets/background.png", 
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withValues(alpha: 0.4)),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top:55),
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
              padding: EdgeInsets.only(bottom:150),
              child: SizedBox(
                width: 250,
                height: 38,
                child: TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: Colors.white,
                  ),
                  inputFormatters: [
                    MaskInputFormatter(mask: '+# (###) ###-##-##'),
                  ],
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(width: 1.0, color: Colors.white),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    enabledBorder: OutlineInputBorder(
                       borderSide: BorderSide(width: 1.0, color: Colors.white),
                       borderRadius: BorderRadius.circular(26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(width: 1.0, color: Colors.white),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    hintText: "+7 (999) 123-45-67",
                    labelText: "Телефон",
                    hintStyle: const TextStyle(color: Colors.grey),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
                    constraints: BoxConstraints(maxWidth: 250, maxHeight: 50),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom:100),
              child: SizedBox(
                width: 250,
                height: 38,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/addaccsms', arguments: {'phone': phoneController.text},);
                   /*Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => AddAccSmsScreen(phone: phoneController.text,)),
                    );*/
                  }, 
                  style: ButtonStyle(
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 15)),
                    side: const WidgetStatePropertyAll(BorderSide(color: Colors.white, width: 1)),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(26),)),
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    animationDuration: Duration(milliseconds: 0),
                  ),
                  child: Text(
                    "Зарегистрироваться",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: "Inter",
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Column(
            //alignment: Alignment.bottomCenter,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                //padding: EdgeInsets.only(bottom:45),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    //margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.only(bottom:45),
                      child: Text(
                        "Регистрируясь, вы принимаете Условия предоставления услуг и Политику конфиденциальности",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: "InterThin",
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ]
              ),
            ]
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom:15),
                child: SizedBox(
                  width: 90,
                  height: 32,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/home',);
                      /*Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                      );*/
                    }, 
                    style: ButtonStyle(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 15),
                      ),
                      side: const WidgetStatePropertyAll(BorderSide.none),
                      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      animationDuration: Duration(milliseconds: 0),
                    ),

                    child: Text(
                      "<- Назад",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        fontFamily: "Inter",
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}