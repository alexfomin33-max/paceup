import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  // 🔹 Ключи для каждого Navigator, чтобы каждый экран имел свою навигацию

  @override
  void initState() {
    super.initState();
    // 🔹 Создаем ключи для каждого экрана, чтобы они сохраняли свое состояние
    _navigatorKeys = List.generate(
      widget.screens.length,
      (index) => GlobalKey<NavigatorState>(),
    );
  }

  /// 🔹 Обработка нажатия на BottomNavigationBar
  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index; // Меняем выбранный экран
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔹 Основная часть экрана — Stack с экранами
      body: Stack(
        children: widget.screens.asMap().entries.map((entry) {
          int index = entry.key;
          Widget screen = entry.value;

          // 🔹 Offstage позволяет показывать только выбранный экран, остальные скрыты
          return Offstage(
            offstage: _currentIndex != index,
            child: Navigator(
              key: _navigatorKeys[index], // Каждому экрану свой Navigator
              // 🔹 Генерация маршрута для экрана
              onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => screen),
            ),
          );
        }).toList(),
      ),

      // 🔹 Нижняя навигационная панель
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Фиксированные вкладки
        selectedItemColor: const Color(0xFF579FFF), // Цвет выбранной вкладки
        unselectedItemColor: Colors.grey, // Цвет невыбранных вкладок
        currentIndex: _currentIndex, // Текущий выбранный экран
        onTap: _onNavTap, // Обработка нажатия на вкладку
        items: const [
          // 🔹 Вкладка "Лента"
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Лента",
          ),
          // 🔹 Вкладка "Карта"
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            label: "Карта",
          ),
          // 🔹 Вкладка "Маркет"
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: "Маркет",
          ),
          // 🔹 Вкладка "Задачи" с иконкой FontAwesome
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.crosshairs),
            label: "Задачи",
          ),
          // 🔹 Вкладка "Профиль"
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Профиль",
          ),
        ],
      ),
    );
  }
}
