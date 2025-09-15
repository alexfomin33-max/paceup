import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppBottomNavShell extends StatefulWidget {
  final List<Widget> screens;

  const AppBottomNavShell({super.key, required this.screens});

  @override
  State<AppBottomNavShell> createState() => AppBottomNavShellState();
}

class AppBottomNavShellState extends State<AppBottomNavShell> {
  int _currentIndex = 0;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;

  @override
  void initState() {
    super.initState();
    _navigatorKeys = List.generate(
      widget.screens.length,
      (index) => GlobalKey<NavigatorState>(),
    );
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: widget.screens.asMap().entries.map((entry) {
          int index = entry.key;
          Widget screen = entry.value;
          return Offstage(
            offstage: _currentIndex != index,
            child: Navigator(
              key: _navigatorKeys[index],
              onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => screen),
            ),
          );
        }).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF579FFF),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Лента",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            label: "Карта",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: "Маркет",
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.crosshairs),
            label: "Задачи",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Профиль",
          ),
        ],
      ),
    );
  }
}
