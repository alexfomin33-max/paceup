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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white, // фон всего бара
          border: Border(
            top: BorderSide(
              color: Colors.black12, // линия сверху
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor:
              Colors.transparent, // 🔹 фон убираем, используем от контейнера
          elevation: 0, // 🔹 отключаем тень, если вдруг появится
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
              icon: Icon(Icons.article_outlined),
              label: "Задачи",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: "Профиль",
            ),
          ],
        ),
      ),
    );
  }
}
