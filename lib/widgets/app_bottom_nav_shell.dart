import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import '../screens/lenta_screen.dart';
import '../screens/map_screen.dart';
import '../screens/market_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/profile_screen.dart';

/// 🔹 Обертка нижней навигации
class AppBottomNavShell extends StatelessWidget {
  final int userId;

  const AppBottomNavShell({super.key, required this.userId});

  static const TextStyle tabTextStyle = TextStyle(fontSize: 10);

  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      // фон самого контейнера делаем прозрачным — рисуем свой ниже
      backgroundColor: Colors.transparent,

      tabs: [
        PersistentTabConfig(
          screen: LentaScreen(userId: userId),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.news),
            title: "Лента",
            textStyle: tabTextStyle,
          ),
        ),
        PersistentTabConfig(
          screen: const MapScreen(),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.placemark),
            title: "Карта",
            textStyle: tabTextStyle,
          ),
        ),
        PersistentTabConfig(
          screen: const MarketScreen(),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.shopping_cart),
            title: "Маркет",
            textStyle: tabTextStyle,
          ),
        ),
        PersistentTabConfig(
          screen: const TasksScreen(),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.scope),
            title: "Задачи",
            textStyle: tabTextStyle,
          ),
        ),
        PersistentTabConfig(
          screen: ProfileScreen(userId: userId),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.person),
            title: "Профиль",
            textStyle: tabTextStyle,
          ),
        ),
      ],

      // панель с полупрозрачным фоном + лёгкая тень сверху
      navBarBuilder: (navBarConfig) => Container(
        decoration: BoxDecoration(
          // белая полупрозрачная «дымка»
          color: Colors.white.withValues(alpha: 0.1),
          // маленькая тень СВЕРХУ: отрицательный offset по Y
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), // мягкая тень
              blurRadius: 12, // размытость
              spreadRadius: 0, // без растекания
              offset: const Offset(0, -1), // тень сверху (отрицательный Y)
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Style1BottomNavBar(navBarConfig: navBarConfig),
        ),
      ),
    );
  }
}
