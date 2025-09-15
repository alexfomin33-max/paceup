import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav_shell.dart';
import 'home_screen.dart';
import 'lenta_screen.dart';
// import 'map_screen.dart';
// import 'market_screen.dart';
// import 'tasks_screen.dart';
// import 'profile_screen.dart';

class HomeShell extends StatelessWidget {
  final int userId;

  const HomeShell({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return AppBottomNavShell(
      screens: [
        HomeScreen(), // теперь первый экран
        LentaScreen(userId: userId),
        // MapScreen(userId: userId),
        // MarketScreen(userId: userId),
        // TasksScreen(userId: userId),
        // ProfileScreen(userId: userId),
      ],
    );
  }
}
