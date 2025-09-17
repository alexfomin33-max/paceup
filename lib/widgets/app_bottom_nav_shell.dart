import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 🔹 Обертка для нижней навигации с сохранением состояния экранов
class AppBottomNavShell extends StatefulWidget {
  final List<Widget> screens; // Список экранов для каждой вкладки

  const AppBottomNavShell({super.key, required this.screens});

  @override
  State<AppBottomNavShell> createState() => AppBottomNavShellState();
}

/// 🔹 Состояние нижней навигации
class AppBottomNavShellState extends State<AppBottomNavShell> {
  int _currentIndex = 0; // Текущий выбранный экран
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12, width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF56A2FF),
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          onTap: _onNavTap,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.news), // Лента
              label: "Лента",
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.map), // Карта
              label: "Карта",
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.shopping_cart), // Маркет
              label: "Маркет",
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.doc_text), // Задачи
              label: "Задачи",
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person), // Профиль
              label: "Профиль",
            ),
          ],
        ),
      ),
    );
  }
}
