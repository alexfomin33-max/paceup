import 'package:flutter/material.dart';
import '../service/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final auth = AuthService();

  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  void checkAuth() async {
    bool authorized = await auth.isAuthorized();

    if (!mounted) return;

    if (authorized) {
      final userId = await auth.getUserId();
      Navigator.pushReplacementNamed(
        context,
        '/regstep2',
        arguments: {'userId': userId},
      );
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}
