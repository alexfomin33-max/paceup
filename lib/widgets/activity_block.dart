// activity_block.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// 🔹 Виджет вертикальной метрики
class MetricVertical extends StatelessWidget {
  final String mainTitle;
  final String mainValue;
  final String subTitle;
  final String subValue;

  const MetricVertical({
    super.key,
    required this.mainTitle,
    required this.mainValue,
    required this.subTitle,
    required this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mainTitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          mainValue,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          subTitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          subValue,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// 🔹 Карточка маршрута
class RouteCard extends StatelessWidget {
  final List<LatLng> points;

  const RouteCard({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Text("Нет точек маршрута");

    final lat =
        points.map((e) => e.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((e) => e.longitude).reduce((a, b) => a + b) / points.length;
    final center = LatLng(lat, lng);

    return SizedBox(
      width: double.infinity,
      height: 200,
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 12.0),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'paceup.ru',
          ),
          PolylineLayer(
            polylines: [
              Polyline(points: points, strokeWidth: 4.0, color: Colors.blue),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: points.first,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 32,
                ),
              ),
              Marker(
                point: points.last,
                width: 40,
                height: 40,
                child: const Icon(Icons.flag, color: Colors.red, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 🔹 Equipment
class Equipment extends StatelessWidget {
  const Equipment({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: ShapeDecoration(
        color: const Color(0xFFF3F4F6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: Stack(
        children: [
          // Иконка слева с отступом 3px
          Positioned(
            left: 3,
            top: 3,
            bottom: 3,
            child: Container(
              width: 50,
              height: 50,
              decoration: ShapeDecoration(
                image: const DecorationImage(
                  image: NetworkImage("https://placehold.co/50x50"),
                  fit: BoxFit.fill,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),

          // Текст по центру
          Positioned(
            left: 60,
            top: 7,
            right: 60,
            child: Text.rich(
              TextSpan(
                children: const [
                  TextSpan(
                    text: "Asics Jolt 3 Wide 'Dive Blue'\n",
                    style: TextStyle(
                      color: Color(0xFF323743),
                      fontSize: 13,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      height: 1.69,
                    ),
                  ),
                  TextSpan(
                    text: "Пробег: ",
                    style: TextStyle(
                      color: Color(0xFF565D6D),
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      height: 1.64,
                    ),
                  ),
                  TextSpan(
                    text: "582",
                    style: TextStyle(
                      color: Color(0xFF171A1F),
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      height: 1.64,
                    ),
                  ),
                  TextSpan(
                    text: " км",
                    style: TextStyle(
                      color: Color(0xFF565D6D),
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      height: 1.64,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Кнопка справа с иконкой трех точек
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_horiz_outlined,
                  size: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔹 ActivityBlock
class ActivityBlock extends StatelessWidget {
  const ActivityBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(width: 0.5, color: Color(0xFFBDC1CA)),
          bottom: BorderSide(width: 0.5, color: Color(0xFFBDC1CA)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Текст и аватар с паддингом
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFA3D4EC),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Игорь Зелёный",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "8 июня 2025, в 10:28",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 18),
                      // 🔹 Метрики под текстом
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MetricVertical(
                            mainTitle: "Расстояние",
                            mainValue: "16,00 км",
                            subTitle: "Набор высоты",
                            subValue: "203 м",
                          ),
                          const SizedBox(width: 24),
                          MetricVertical(
                            mainTitle: "Время",
                            mainValue: "1:12:34",
                            subTitle: "Каденс",
                            subValue: "179",
                          ),
                          const SizedBox(width: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Темп",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "4:16 / км",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Средний пульс",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    "141",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 2),

          // 🔹 Equipment с отступами снаружи
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Equipment(),
          ),

          const SizedBox(height: 8),

          // 🔹 Карта маршрута
          RouteCard(
            points: [LatLng(56.43246, 40.42653), LatLng(56.43242, 40.42624)],
          ),

          const SizedBox(height: 12),

          // 🔹 Иконки под картой с числами (черными)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Слева
                Row(
                  children: const [
                    Row(
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 20,
                          color: AppColors.red,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "35",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                          color: AppColors.orange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "2",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Справа
                Row(
                  children: const [
                    Row(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 20,
                          color: AppColors.green,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "48",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          size: 20,
                          color: AppColors.secondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "3",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
