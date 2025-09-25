import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import 'addevent_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedIndex = 0;

  final tabs = ["События", "Клубы", "Слоты", "Попутчики"];

  /// 🔹 Маркеры для разных вкладок
  final markersByTab = {
    0: [
      {
        'point': LatLng(56.129057, 40.406635),
        'title': 'События во Владимире',
        'count': 2,
      },
      {
        'point': LatLng(55.755864, 37.617698),
        'title': 'События в Москве',
        'count': 5,
      },
    ],
    1: [
      {
        'point': LatLng(56.326797, 44.006516),
        'title': 'Клуб в Нижнем Новгороде',
        'count': 1,
      },
      {
        'point': LatLng(57.626559, 39.893813),
        'title': 'Клуб в Ярославле',
        'count': 3,
      },
    ],
    2: [
      {
        'point': LatLng(56.999799, 40.973014),
        'title': 'Слот в Иванове',
        'count': 4,
      },
    ],
    3: [
      {
        'point': LatLng(55.45, 37.36),
        'title': 'Попутчик в Подольске',
        'count': 2,
      },
      {'point': LatLng(56.85, 35.9), 'title': 'Попутчик в Твери', 'count': 1},
    ],
  };

  /// 🔹 Цвета маркеров по вкладкам
  final markerColors = {
    0: Colors.blue, // события
    1: Colors.green, // клубы
    2: Colors.orange, // слоты
    3: Colors.purple, // попутчики
  };

  @override
  Widget build(BuildContext context) {
    final markers = markersByTab[_selectedIndex] ?? [];
    final markerColor = markerColors[_selectedIndex] ?? Colors.blue;

    // отступ снизу, чтобы кнопки не перекрывались системной панелью/навигацией
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          /// 🔹 Карта
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(56.129057, 40.406635),
              initialZoom: 6.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.paceip',
              ),
              MarkerLayer(
                markers: markers.map((marker) {
                  return Marker(
                    point: marker['point'] as LatLng,
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: Navigator.of(
                            context,
                            rootNavigator: true,
                          ).context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(AppRadius.large),
                              ),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Wrap(
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    /// 🔹 Полоска сверху
                                    Center(
                                      child: Container(
                                        width: 40,
                                        height: 4,
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.border,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),

                                    /// 🔹 Заголовок
                                    Center(
                                      child: Text(
                                        marker['title'] as String,
                                        style: AppTextStyles.h1,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 1,
                                      color: AppColors.border,
                                    ),
                                    const SizedBox(height: 12),

                                    /// 🔹 Контент по маркеру (пример)
                                    if (marker['title'] ==
                                        'События во Владимире')
                                      Column(
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Image.asset(
                                                'assets/Vlad_event_1.png',
                                                width: 90,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              ),
                                              const SizedBox(width: 8),
                                              const Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Субботний коферан",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      "14 июня 2025  ·  Участников: 32",
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: AppColors.text,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Image.asset(
                                                'assets/Vlad_event_2.png',
                                                width: 90,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              ),
                                              const SizedBox(width: 8),
                                              const Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Владимирский полумарафон «Золотые ворота»",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      "31 августа 2025  ·  Участников: 1426",
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: AppColors.text,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    else
                                      const Text("Здесь будет контент..."),

                                    const SizedBox(height: 50),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: markerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (marker['count'] as int).toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          /// 🔹 Верхняя панель вкладок (без прозрачности, без blur)
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(tabs.length, (index) {
                    final isSelected = _selectedIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.black87
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tabs[index],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          /// 🔹 Нижние кнопки: "Фильтры" и "Добавить" (без прозрачности)
          Positioned(
            left: 12,
            right: 12,
            bottom: kBottomNavigationBarHeight - 40, // ближе к нижней панели
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SolidPillButton(
                  icon: Icons.tune,
                  label: 'Фильтры',
                  onTap: () {
                    // TODO: открыть фильтры
                  },
                ),
                _SolidPillButton(
                  icon: Icons.add_circle_outline,
                  label: 'Добавить',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEventScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка-«таблетка» без прозрачности/blur
class _SolidPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SolidPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20), // ← радиус 20
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20), // ← радиус 20
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20), // ← радиус 20
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
