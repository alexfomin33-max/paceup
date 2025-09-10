import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';


class RouteCard extends StatelessWidget {
  final LatLng start;
  final LatLng end;

  const RouteCard({super.key, required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    // если координаты валидные, берём середину
    final center = (start.latitude.isFinite &&
            start.longitude.isFinite &&
            end.latitude.isFinite &&
            end.longitude.isFinite)
        ? LatLng(
            (start.latitude + end.latitude) / 2,
            (start.longitude + end.longitude) / 2,
          )
        : start; // fallback

    final polylinePoints = <LatLng>[start, end];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            //center: center,
            //zoom: 10,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'paceup.ru',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: start,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on,
                      color: Colors.green, size: 32),
                ),
                Marker(
                  point: end,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.flag,
                      color: Colors.red, size: 28),
                ),
              ],
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: polylinePoints,
                  strokeWidth: 4.0,
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class LentaScreen extends StatefulWidget {
  final int userId;

  const LentaScreen({super.key, required this.userId});

  @override
  _LentaScreenState createState() => _LentaScreenState();
}

class _LentaScreenState extends State<LentaScreen> {
 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true, // чтобы "Лента" была по центру
        leadingWidth: 100, // расширяем область для двух иконок
        leading: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                // действие
              },
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // действие
              },
            ),
          ],
        ),
        title: const Text(
          "Лента",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF171A1F),
            fontFamily: 'Inter'
          ),
        ),
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
                    style: TextStyle(fontSize: 8, color: Colors.white, fontFamily: 'Inter'),
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF579FFF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed_outlined),
            label: "Лента",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: "Карта",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            label: "Маркет",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
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
                const CircleAvatar(radius: 20, backgroundColor: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Игорь Зелёный",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter',),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Text(
                    "8 июня 2025, в 10:28",
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Inter',),
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
                _Metric(title: "Расстояние", value: "16,00 км"),
                _Metric(title: "Время", value: "1:12:34"),
                _Metric(title: "Темп", value: "4:16 / км"),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _Metric(title: "Набор высоты", value: "203 м"),
                _Metric(title: "Каденс", value: "179"),
                _Metric(title: "Пульс", value: "141"),
              ],
            ),
            const SizedBox(height: 8,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                RouteCard(
                  start: LatLng(55.7558, 37.6173), // Москва
                  end: LatLng(59.9343, 30.3351),   // Питер
                ),
              ],
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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter',),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _friendCard("Екатерина Виноградова", "36 лет, Санкт-Петербург",
                  "6 общих друзей"),
              const SizedBox(width: 12),
              _friendCard(
                  "Анатолий Курагин", "38 лет, Ковров", "4 общих друга"),
            ],
          ),
        )
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
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blueGrey,
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter',),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Inter',),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            mutual,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Inter',),
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
            child: const Text("Подписаться", style: TextStyle(fontFamily: 'Inter',),),
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
                    radius: 20, backgroundColor: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Алексей Лукашин",
                        style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter',),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "7 июня 2025, в 14:36",
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Inter',),
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
              "https://picsum.photos/400/200", // пока заглушка
              fit: BoxFit.cover),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text("Вот так вот очень легко всех победил", style: TextStyle(fontFamily: 'Inter',),),
          ),
          Row(
            children: const [
              SizedBox(width: 12),
              Icon(Icons.favorite_border, size: 20),
              SizedBox(width: 4),
              Text("2707", style: TextStyle(fontFamily: 'Inter',),),
              SizedBox(width: 16),
              Icon(Icons.mode_comment_outlined, size: 20),
              SizedBox(width: 4),
              Text("50", style: TextStyle(fontFamily: 'Inter',),),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String title;
  final String value;

  const _Metric({required this.title, required this.value});

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