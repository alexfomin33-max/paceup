import 'package:flutter/cupertino.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import '../screens/lenta_screen.dart';
import '../screens/map_screen.dart';
import '../screens/market_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/profile_screen.dart';

/// 🔹 Обертка нижней навигации на базе persistent_bottom_nav_bar_v2
class AppBottomNavShell extends StatelessWidget {
  final int userId; // пробрасываем userId в экраны, где нужен

  const AppBottomNavShell({super.key, required this.userId});

  // Константа для стиля текста вкладок
  static const TextStyle tabTextStyle = TextStyle(
    fontSize: 10, // размер шрифта вкладок
  );

  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
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
      navBarBuilder: (navBarConfig) =>
          Style1BottomNavBar(navBarConfig: navBarConfig),
    );
  }
}
