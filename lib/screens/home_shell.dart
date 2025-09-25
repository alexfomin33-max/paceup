import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav_shell.dart';
import 'lenta/newpost_screen.dart';

class HomeShell extends StatefulWidget {
  final int userId;
  const HomeShell({super.key, required this.userId});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  void _openNewPost() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NewPostScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Передаём только userId, остальное внутри AppBottomNavShell
    return AppBottomNavShell(userId: widget.userId);
  }
}
