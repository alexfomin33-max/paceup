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

  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      tabs: [
        PersistentTabConfig(
          screen: LentaScreen(userId: userId),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.news),
            title: "Лента",
          ),
        ),
        PersistentTabConfig(
          screen: const MapScreen(),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.map),
            title: "Карта",
          ),
        ),
        PersistentTabConfig(
          screen: const MarketScreen(),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.shopping_cart),
            title: "Маркет",
          ),
        ),
        PersistentTabConfig(
          screen: const TasksScreen(),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.doc_text),
            title: "Задачи",
          ),
        ),
        PersistentTabConfig(
          screen: ProfileScreen(userId: userId),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.person),
            title: "Профиль",
          ),
        ),
      ],
      navBarBuilder: (navBarConfig) =>
          Style1BottomNavBar(navBarConfig: navBarConfig),
    );
  }
}
