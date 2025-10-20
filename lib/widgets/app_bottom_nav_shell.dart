import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import '../screens/lenta/lenta_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/market/market_screen.dart';
import '../screens/tasks/tasks_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../../../../../theme/app_theme.dart';

class AppBottomNavShell extends StatefulWidget {
  final int userId;
  const AppBottomNavShell({super.key, required this.userId});

  @override
  State<AppBottomNavShell> createState() => _AppBottomNavShellState();
}

class _AppBottomNavShellState extends State<AppBottomNavShell> {
  static const TextStyle tabTextStyle = TextStyle(fontSize: 10);
  static const double navIconSize = 22.0;

  // Цвета для активного/неактивного состояний
  static const Color _active = AppColors.brandPrimary;
  static const Color _inactive = AppColors.textSecondary;

  // отдельные стеки навигации для каждой вкладки
  final _navKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  void _onTabChanged(int index) {
    // ВСЕГДА возвращаем выбранную вкладку на корень
    _navKeys[index].currentState?.popUntil((r) => r.isFirst);
    setState(() {});
  }

  // обёртка, чтобы каждая вкладка имела свой Navigator
  Widget _tabRoot(GlobalKey<NavigatorState> key, Widget root) {
    return Navigator(
      key: key,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      backgroundColor: AppColors.surface,
      onTabChanged: _onTabChanged,

      tabs: [
        PersistentTabConfig(
          screen: _tabRoot(_navKeys[0], LentaScreen(userId: widget.userId)),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.news, size: navIconSize),
            title: "Лента",
            textStyle: tabTextStyle,
            activeForegroundColor: _active,
            inactiveForegroundColor: _inactive,
          ),
        ),
        PersistentTabConfig(
          screen: _tabRoot(_navKeys[1], const MapScreen()),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.placemark, size: navIconSize),
            title: "Карта",
            textStyle: tabTextStyle,
            activeForegroundColor: _active,
            inactiveForegroundColor: _inactive,
          ),
        ),
        PersistentTabConfig(
          screen: _tabRoot(_navKeys[2], const MarketScreen()),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.shopping_cart, size: navIconSize),
            title: "Маркет",
            textStyle: tabTextStyle,
            activeForegroundColor: _active,
            inactiveForegroundColor: _inactive,
          ),
        ),
        PersistentTabConfig(
          screen: _tabRoot(_navKeys[3], const TasksScreen()),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.scope, size: navIconSize),
            title: "Задачи",
            textStyle: tabTextStyle,
            activeForegroundColor: _active,
            inactiveForegroundColor: _inactive,
          ),
        ),
        PersistentTabConfig(
          screen: _tabRoot(_navKeys[4], ProfileScreen(userId: widget.userId)),
          item: ItemConfig(
            icon: const Icon(CupertinoIcons.person, size: navIconSize),
            title: "Профиль",
            textStyle: tabTextStyle,
            activeForegroundColor: _active,
            inactiveForegroundColor: _inactive,
          ),
        ),
      ],

      // нижняя панель — белая с тонким разделителем
      navBarBuilder: (navBarConfig) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Style1BottomNavBar(navBarConfig: navBarConfig),
          ),
        ),
      ),
    );
  }
}
