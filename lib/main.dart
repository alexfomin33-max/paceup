/*import "package:flutter/material.dart";
import "screens/home_screen.dart";

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        //'/login': (context) => LoginScreen(),
        //'/profile': (context) => ProfileScreen(),
      },
      theme: ThemeData(
        fontFamily: "Inter",
      ),
    );
  }
}*/

import 'package:flutter/material.dart';
import 'routes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaceUp',
      theme: ThemeData(fontFamily: 'Inter'),
      initialRoute: '/splash',
      routes: appRoutes,
    );
  }
}




