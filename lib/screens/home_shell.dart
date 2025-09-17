import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav_shell.dart';
import 'home_screen.dart';
import 'lenta_screen.dart';
import 'newpost_screen.dart';

/// 🔹 HomeShell — это "обертка" для экранов с нижней навигацией
/// Она использует AppBottomNavShell, чтобы переключаться между вкладками
/// Все экраны, которые должны быть доступны через нижнюю навигацию, добавляются в список screens
class HomeShell extends StatefulWidget {
  /// 🔹 Идентификатор пользователя, передаваемый в экраны, где нужен userId
  final int userId;

  const HomeShell({super.key, required this.userId});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(),
      LentaScreen(userId: widget.userId, onNewPostPressed: _openNewPost),
      // Здесь можно добавить остальные экраны: MapScreen, MarketScreen и т.д.
    ];
  }

  void _openNewPost() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NewPostScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomNavShell(screens: _screens);
  }
}
