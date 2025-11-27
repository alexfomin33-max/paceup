import 'package:flutter/material.dart';
import '../core/widgets/app_bottom_nav_shell.dart';

class HomeShell extends StatefulWidget {
  final int userId;
  const HomeShell({super.key, required this.userId});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  Widget build(BuildContext context) {
    // Передаём только userId, остальное внутри AppBottomNavShell
    return AppBottomNavShell(userId: widget.userId);
  }
}
