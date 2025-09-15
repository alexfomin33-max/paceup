import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/text_styles.dart';

/// 🔹 RouteCard — отображает маршрут на карте
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
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
      ),
    );
  }
}

/// 🔹 Экран Ленты
class LentaScreen extends StatelessWidget {
  final int userId;

  const LentaScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leadingWidth: 100,
        leading: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(icon: const Icon(Icons.star_border), onPressed: () {}),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {},
            ),
          ],
        ),
        title: const Text("Лента", style: AppTextStyles.h1),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    "9",
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.message_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildActivityCard(),
          const SizedBox(height: 16),
          _buildRecommendations(),
          const SizedBox(height: 16),
          _buildPostCard(),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Игорь Зелёный",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Text(
                    "8 июня 2025, в 10:28",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'Inter',
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Metric(title: "Расстояние", value: "16,00 км"),
                Metric(title: "Время", value: "1:12:34"),
                Metric(title: "Темп", value: "4:16 / км"),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Metric(title: "Набор высоты", value: "203 м"),
                Metric(title: "Каденс", value: "179"),
                Metric(title: "Пульс", value: "141"),
              ],
            ),
            const SizedBox(height: 8),
            RouteCard(
              points: [LatLng(56.43246, 40.42653), LatLng(56.43242, 40.42624)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "Рекомендации для вас",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _friendCard(
                "Екатерина Виноградова",
                "36 лет, Санкт-Петербург",
                "6 общих друзей",
              ),
              const SizedBox(width: 12),
              _friendCard(
                "Анатолий Курагин",
                "38 лет, Ковров",
                "4 общих друга",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _friendCard(String name, String desc, String mutual) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            mutual,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3999E6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Подписаться",
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Алексей Лукашин",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "7 июня 2025, в 14:36",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'Inter',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),
          Image.network("https://picsum.photos/400/200", fit: BoxFit.cover),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              "Вот так вот очень легко всех победил",
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
          Row(
            children: const [
              SizedBox(width: 12),
              Icon(Icons.favorite_border, size: 20),
              SizedBox(width: 4),
              Text("2707", style: TextStyle(fontFamily: 'Inter')),
              SizedBox(width: 16),
              Icon(Icons.mode_comment_outlined, size: 20),
              SizedBox(width: 4),
              Text("50", style: TextStyle(fontFamily: 'Inter')),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// 🔹 Виджет метрики (Расстояние, Время и т.д.)
class Metric extends StatelessWidget {
  final String title;
  final String value;

  const Metric({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
