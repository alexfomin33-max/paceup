import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../widgets/comments_bottom_sheet.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

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
        options: MapOptions(initialCenter: center, initialZoom: 8.0),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.paceip',
          ),
          PolylineLayer(
            polylines: [
              Polyline(points: points, strokeWidth: 4.0, color: Colors.blue),
            ],
          ),
          // MarkerLayer(
          //   markers: [
          //     Marker(
          //       point: points.first,
          //       width: 40,
          //       height: 40,
          //       child: const Icon(
          //         Icons.location_on,
          //         color: Colors.green,
          //         size: 32,
          //       ),
          //     ),
          //     Marker(
          //       point: points.last,
          //       width: 40,
          //       height: 40,
          //       child: const Icon(Icons.flag, color: Colors.red, size: 28),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }
}

/// 🔹 Popup для обуви (Equipment)
class Popup extends StatelessWidget {
  const Popup({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 288,
          height: 112,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.white),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: 288,
                  height: 56,
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 56,
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Colors.white),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            "assets/Hoka.png",
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                      Container(
                        width: 208,
                        height: 56,
                        color: Colors.white,
                        padding: const EdgeInsets.only(left: 5, top: 8),
                        child: const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Hoka One One Bondi 8\n',
                                style: TextStyle(
                                  color: Color(0xFF323743),
                                  fontSize: 12,

                                  fontWeight: FontWeight.w400,
                                  height: 1.67,
                                ),
                              ),
                              TextSpan(
                                text: 'Пробег: ',
                                style: TextStyle(
                                  color: Color(0xFF565D6D),
                                  fontSize: 11,

                                  fontWeight: FontWeight.w400,
                                  height: 1.64,
                                ),
                              ),
                              TextSpan(
                                text: '836',
                                style: TextStyle(
                                  color: Color(0xFF171A1F),
                                  fontSize: 11,

                                  fontWeight: FontWeight.w600,
                                  height: 1.64,
                                ),
                              ),
                              TextSpan(
                                text: ' км',
                                style: TextStyle(
                                  color: Color(0xFF565D6D),
                                  fontSize: 11,

                                  fontWeight: FontWeight.w400,
                                  height: 1.64,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 56,
                child: Container(
                  width: 288,
                  height: 1,
                  color: const Color(0xFFECECEC),
                ),
              ),
              Positioned(
                left: 0,
                top: 57,
                child: SizedBox(
                  width: 288,
                  height: 56,
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 56,
                        color: Colors.white,
                        padding: const EdgeInsets.all(5),
                        child: Image.asset("assets/Anta.png", fit: BoxFit.fill),
                      ),
                      Container(
                        width: 208,
                        height: 56,
                        color: Colors.white,
                        padding: const EdgeInsets.only(left: 5, top: 8),
                        child: const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Anta M C202\n',
                                style: TextStyle(
                                  color: Color(0xFF323743),
                                  fontSize: 12,

                                  fontWeight: FontWeight.w400,
                                  height: 1.67,
                                ),
                              ),
                              TextSpan(
                                text: 'Пробег: ',
                                style: TextStyle(
                                  color: Color(0xFF565D6D),
                                  fontSize: 11,

                                  fontWeight: FontWeight.w400,
                                  height: 1.64,
                                ),
                              ),
                              TextSpan(
                                text: '1204',
                                style: TextStyle(
                                  color: Color(0xFF171A1F),
                                  fontSize: 11,

                                  fontWeight: FontWeight.w600,
                                  height: 1.64,
                                ),
                              ),
                              TextSpan(
                                text: ' км',
                                style: TextStyle(
                                  color: Color(0xFF565D6D),
                                  fontSize: 11,

                                  fontWeight: FontWeight.w400,
                                  height: 1.64,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 🔹 Equipment с анимацией Popup
class Equipment extends StatefulWidget {
  const Equipment({super.key});

  @override
  _EquipmentState createState() => _EquipmentState();
}

class _EquipmentState extends State<Equipment>
    with SingleTickerProviderStateMixin {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late AnimationController _popupController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _popupController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _popupController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _popupController.dispose();
    super.dispose();
  }

  void _showPopup() {
    final context = _buttonKey.currentContext;
    if (context == null) return;
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final topPosition = position.dy - 120 < 20
        ? position.dy + size.height
        : position.dy - 120;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hidePopup,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: topPosition,
            left: position.dx + size.width - 288 < 0
                ? 8
                : position.dx + size.width - 288,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 288,
                    height: 112,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Popup(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _popupController.forward(from: 0);
  }

  void _hidePopup() {
    _popupController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
      ), // 👉 отступы слева и справа
      child: Container(
        height: 56,
        decoration: ShapeDecoration(
          color: const Color(0xFFF3F4F6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 3,
              top: 3,
              bottom: 3,
              child: Container(
                width: 50,
                height: 50,
                decoration: ShapeDecoration(
                  image: const DecorationImage(
                    image: AssetImage("assets/Asics.png"),
                    fit: BoxFit.fill,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 60,
              top: 7,
              right: 60,
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Asics Jolt 3 Wide 'Dive Blue'\n",
                      style: TextStyle(
                        color: Color(0xFF323743),
                        fontSize: 13,

                        fontWeight: FontWeight.w500,
                        height: 1.69,
                      ),
                    ),
                    TextSpan(
                      text: "Пробег: ",
                      style: TextStyle(
                        color: Color(0xFF565D6D),
                        fontSize: 11,

                        fontWeight: FontWeight.w400,
                        height: 1.64,
                      ),
                    ),
                    TextSpan(
                      text: "582",
                      style: TextStyle(
                        color: Color(0xFF171A1F),
                        fontSize: 12,

                        fontWeight: FontWeight.w600,
                        height: 1.64,
                      ),
                    ),
                    TextSpan(
                      text: " км",
                      style: TextStyle(
                        color: Color(0xFF565D6D),
                        fontSize: 11,

                        fontWeight: FontWeight.w400,
                        height: 1.64,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (_overlayEntry == null) {
                      _showPopup();
                    } else {
                      _hidePopup();
                    }
                  },
                  child: Container(
                    key: _buttonKey,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white, // фон кнопки
                      shape: BoxShape.circle, // делает кнопку круглой
                    ),
                    child: const Icon(
                      CupertinoIcons.ellipsis,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔹 ActivityBlock с анимацией сердечка и плавной интерактивностью
class ActivityBlock extends StatefulWidget {
  const ActivityBlock({super.key});

  @override
  _ActivityBlockState createState() => _ActivityBlockState();
}

class _ActivityBlockState extends State<ActivityBlock>
    with SingleTickerProviderStateMixin {
  bool isLiked = false;
  late AnimationController _likeController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.easeOutBack),
    );

    _likeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _likeController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  void _onLikeTap() {
    setState(() => isLiked = !isLiked);
    _likeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(width: 0.5, color: AppColors.border),
          bottom: BorderSide(width: 0.5, color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Текст и аватар
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    "assets/Avatar_2.png",
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Игорь Зелёный", style: AppTextStyles.name),
                      const SizedBox(height: 2),
                      const Text(
                        "8 июня 2025, в 10:28",
                        style: AppTextStyles.date,
                      ),
                      const SizedBox(height: 18),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Темп",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "4:16 / км",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Средний пульс",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "141",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    CupertinoIcons.heart_fill,
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Equipment(),
          ),
          const SizedBox(height: 8),
          const RouteCard(
            points: [LatLng(56.43246, 40.42653), LatLng(56.43242, 40.42624)],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _onLikeTap,
                      child: Container(
                        width: 25, // размер зоны нажатия
                        height: 25,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Colors.transparent, // визуально ничего не видно
                        ),
                        child: ScaleTransition(
                          scale: _likeAnimation,
                          child: Icon(
                            isLiked
                                ? CupertinoIcons.heart_solid
                                : CupertinoIcons.heart,
                            size: 20,
                            color: isLiked ? Colors.red : AppColors.red,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),
                    const Text(
                      "35",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        showCupertinoModalBottomSheet(
                          context: context,
                          expand: false,
                          builder: (context) => const CommentsBottomSheet(),
                        );
                      },
                      child: Container(
                        width: 25,
                        height: 25,
                        alignment: Alignment.center,

                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                        ),
                        child: const Icon(
                          CupertinoIcons.chat_bubble,
                          size: 20,
                          color: AppColors.orange,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),
                    const Text(
                      "2",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: const [
                    Icon(
                      CupertinoIcons.person_2,
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
                    SizedBox(width: 12),
                    Icon(
                      CupertinoIcons.person_crop_circle_badge_plus,
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
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
