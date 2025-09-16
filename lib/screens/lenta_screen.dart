import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/text_styles.dart';

/// 🔹 Экран Ленты (Feed)
class LentaScreen extends StatelessWidget {
  final int userId;

  const LentaScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
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
          _buildActivityCard(context),
          const SizedBox(height: 16),
          _buildRecommendations(),
          const SizedBox(height: 16),
          _buildPostCard(),
        ],
      ),
    );
  }

  /// 🔹 Карточка активности пользователя
  Widget _buildActivityCard(BuildContext context) {
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
                  backgroundColor: Colors.blueGrey,
                ),
                const SizedBox(width: 12),
                // Вся правая часть: текст сверху, метрики снизу
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 Текстовые поля
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
                      const SizedBox(height: 12),
                      // 🔹 Метрики под текстом, выровнены по левому краю текста
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          MetricVertical(
                            mainTitle: "Расстояние",
                            mainValue: "16,00 км",
                            subTitle: "Набор высоты",
                            subValue: "203 м",
                          ),
                          SizedBox(width: 24),
                          MetricVertical(
                            mainTitle: "Время",
                            mainValue: "1:12:34",
                            subTitle: "Каденс",
                            subValue: "179",
                          ),
                          SizedBox(width: 24),
                          MetricVertical(
                            mainTitle: "Темп",
                            mainValue: "4:16 / км",
                            subTitle: "Пульс",
                            subValue: "141",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 🔹 Карта на всю ширину без паддинга
          const RouteCard(
            points: [LatLng(56.43246, 40.42653), LatLng(56.43242, 40.42624)],
          ),
        ],
      ),
    );
  }

  /// 🔹 Блок рекомендаций
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
          Image.network(
            "http://uploads.paceup.ru/images/background-min.png",
            fit: BoxFit.cover,
          ),
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
