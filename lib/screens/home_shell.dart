import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav_shell.dart';
import 'home_screen.dart';
import 'lenta_screen.dart';
// import 'map_screen.dart';
// import 'market_screen.dart';
// import 'tasks_screen.dart';
// import 'profile_screen.dart';

/// 🔹 HomeShell — это "обертка" для экранов с нижней навигацией
/// Она использует AppBottomNavShell, чтобы переключаться между вкладками
/// Все экраны, которые должны быть доступны через нижнюю навигацию, добавляются в список screens
class HomeShell extends StatelessWidget {
  /// 🔹 Идентификатор пользователя, передаваемый в экраны, где нужен userId
  final int userId;

  /// 🔹 Конструктор с обязательным параметром userId
  const HomeShell({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return AppBottomNavShell(
      // 🔹 Список экранов, между которыми можно переключаться с помощью нижней навигации
      screens: [
        HomeScreen(), // 🔹 Первый экран (приветственный / основной экран)
        LentaScreen(userId: userId), // 🔹 Экран ленты, получает userId
        // MapScreen(userId: userId),      // 🔹 Можно раскомментировать для карты
        // MarketScreen(userId: userId),   // 🔹 Можно раскомментировать для магазина
        // TasksScreen(userId: userId),    // 🔹 Можно раскомментировать для задач
        // ProfileScreen(userId: userId),  // 🔹 Можно раскомментировать для профиля
      ],
    );
  }
}
