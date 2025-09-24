import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import '../screens/lenta_screen.dart';
import '../screens/map_screen.dart';
import '../screens/market_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/profile/profile_screen.dart';

/// 🔹 Обертка нижней навигации
class AppBottomNavShell extends StatelessWidget {
  final int userId;

  const AppBottomNavShell({super.key, required this.userId});

  static const TextStyle tabTextStyle = TextStyle(fontSize: 10);

  /// Размер иконок во вкладках
  static const double navIconSize = 22.0;

  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      // фон самого контейнера делаем прозрачным — рисуем свой ниже
      backgroundColor: Colors.transparent,

      tabs: [
        PersistentTabConfig(
          screen: LentaScreen(userId: userId),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.news, size: navIconSize),
            title: "Лента",
            textStyle: tabTextStyle,
          ),
        ),
        PersistentTabConfig(
          screen: const MapScreen(),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.placemark, size: navIconSize),
            title: "Карта",
            textStyle: tabTextStyle,
          ),
        ),
        PersistentTabConfig(
          screen: const MarketScreen(),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.shopping_cart, size: navIconSize),
            title: "Маркет",
            textStyle: tabTextStyle,
          ),
        ),
        PersistentTabConfig(
          screen: const TasksScreen(),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.scope, size: navIconSize),
            title: "Задачи",
            textStyle: tabTextStyle,
          ),
        ),
        PersistentTabConfig(
          screen: const ProfileScreen(),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.person, size: navIconSize),
            title: "Профиль",
            textStyle: tabTextStyle,
          ),
        ),
      ],

      // панель с полупрозрачным фоном + лёгкая тень сверху
      navBarBuilder: (navBarConfig) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0xFFE0E0E0), // светло-серый разделитель
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 2,
            ), // чуть воздуха сверху/снизу
            child: Style1BottomNavBar(navBarConfig: navBarConfig),
          ),
        ),
      ),
    );
  }
}
