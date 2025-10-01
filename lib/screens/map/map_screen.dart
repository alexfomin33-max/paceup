import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';

// контент вкладок
import 'events/events_screen.dart' as ev;
import 'clubs/clubs_screen.dart' as clb;
import 'slots/slots_screen.dart' as slt;
import 'travelers/travelers_screen.dart' as trv;

// новый путь к экрану добавления события
import 'events/addevent_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedIndex = 0;

  final tabs = const ["События", "Клубы", "Слоты", "Попутчики"];

  /// Цвета маркеров по вкладкам
  final markerColors = const {
    0: Colors.blue, // события
    1: Colors.red, // клубы
    2: Colors.orange, // слоты
    3: Colors.purple, // попутчики
  };

  List<Map<String, dynamic>> _markersForTab(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return ev.eventsMarkers(context);
      case 1:
        return clb.clubsMarkers(context);
      case 2:
        return slt.slotsMarkers(context);
      case 3:
      default:
        return trv.travelersMarkers(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = _markersForTab(context);
    final markerColor = markerColors[_selectedIndex] ?? Colors.blue;

    return Scaffold(
      body: Stack(
        children: [
          /// ───────── Карта
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(56.129057, 40.406635),
              initialZoom: 6.0,
            ),
            children: [
              TileLayer(
                // без поддоменов, корректный User-Agent
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.paceip',
                maxZoom: 19,
                minZoom: 3,
                keepBuffer: 1,
                retinaMode: false,
              ),
              MarkerLayer(
                markers: markers.map((m) {
                  final LatLng point = m['point'] as LatLng;
                  final String title = m['title'] as String;
                  final int count = m['count'] as int;
                  final Widget? content = m['content'] as Widget?;

                  return Marker(
                    point: point,
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
                          builder: (_) => _BottomSheetScaffold(
                            title: title,
                            child: content ?? const _SheetPlaceholder(),
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
                          '$count',
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

          /// ───────── Верхняя панель вкладок (та же эстетика, что была)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
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
                                ? FontWeight.w600
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

          /// ───────── Нижние кнопки: «Фильтры» и «Добавить»
          Positioned(
            left: 12,
            right: 12,
            bottom: kBottomNavigationBarHeight - 40,
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
                    if (_selectedIndex == 0) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEventScreen(),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Добавление сейчас доступно на вкладке «События».',
                          ),
                        ),
                      );
                    }
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

/// Унифицированный низкий BottomSheet-каркас
class _BottomSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheetScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // полоска-«ручка»
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10, top: 6),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // заголовок
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text(title, style: AppTextStyles.h1)),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 6),

            // контент от вкладки
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: child,
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _SheetPlaceholder extends StatelessWidget {
  const _SheetPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 40),
      child: Text(
        'Здесь будет контент…',
        style: TextStyle(fontSize: 14, color: AppColors.text),
      ),
    );
  }
}

/// Кнопка-«таблетка»
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
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                  fontWeight: FontWeight.w500,
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
