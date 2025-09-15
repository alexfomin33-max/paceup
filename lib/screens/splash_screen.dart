import 'package:flutter/material.dart';
import '../service/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  final AuthService auth = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final bool authorized = await auth.isAuthorized();

    if (!mounted) return;

    if (authorized) {
      final int? userId = await auth.getUserId();
      if (!mounted) return;

      if (userId != null) {
        Navigator.pushReplacementNamed(
          context,
          '/home', // 🔹 авторизован → HomeShell
          arguments: {'userId': userId},
        );
      } else {
        Navigator.pushReplacementNamed(context, '/homeScreen'); // 🔹 fallback
      }
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/homeScreen',
      ); // 🔹 не авторизован → HomeScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
