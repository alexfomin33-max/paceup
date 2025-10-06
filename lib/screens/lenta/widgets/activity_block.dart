import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';
import 'comments_bottom_sheet.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:paceup/models/activity_lenta.dart'; // <-- Модель Activity
import 'package:paceup/models/activity_lenta.dart' as AL;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../profile/profile_screen.dart';
import '../activity/together/together_screen.dart'; // добавьте импорт

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
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 1),
        Text(
          mainValue,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          subTitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 1),
        Text(
          subValue,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// 🔹 Карточка маршрута — статичная карта без интерактива + авто-вписывание по треку (без скруглений)
class RouteCard extends StatefulWidget {
  final List<LatLng> points;

  const RouteCard({super.key, required this.points});

  @override
  State<RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  // Центр по умолчанию (если fit не успеет)
  LatLng _centerFromPoints(List<LatLng> pts) {
    if (pts.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    final n = pts.length.toDouble();
    return LatLng(lat / n, lng / n);
  }

  // Границы трека для вписывания
  LatLngBounds _boundsFromPoints(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text("Нет точек маршрута"),
      );
    }

    final center = _centerFromPoints(points);

    return SizedBox(
      width: double.infinity,
      height: 200,
      // ❌ Полностью отключаем касания — карта как картинка
      child: IgnorePointer(
        ignoring: true,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
            // ❌ Жесты отключены
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
            backgroundColor: Colors.transparent,
            // ✅ Вписываем камеру по границам трека с отступами
            onMapReady: () {
              final fit = CameraFit.bounds(
                bounds: _boundsFromPoints(points),
                padding: const EdgeInsets.all(12),
              );
              _mapController.fitCamera(fit);
            },
          ),
          children: [
            TileLayer(
              // убрали {s}
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // нормальный user-agent — OSM это любит
              userAgentPackageName: 'com.example.paceip',
              tileProvider: NetworkTileProvider(
                // при желании можно добавить кастомные заголовки
                // headers: {'User-Agent': 'PaceUp/1.0 (com.example.paceip)'},
              ),
              keepBuffer: 1,
              retinaMode: false,
              maxZoom: 18,
              minZoom: 3,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 3.0,
                  color: const Color(0xFF0080FF), // без withOpacity
                ),
              ],
            ),
          ],
        ),
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
                  color: Color(0xFFECECEC),
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
  final List<AL.Equipment> items; // данные сюда

  const Equipment({super.key, required this.items});

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
    // берём первый элемент из списка; если пусто — используем фоллбек
    final AL.Equipment? e = widget.items.isNotEmpty ? widget.items.first : null;
    final String name = e?.name.toString().trim().isNotEmpty == true
        ? e!.name
        : "Asics Jolt 3 Wide 'Dive Blue'";
    final int mileage = e?.mileage ?? 582;
    final String img = e?.img ?? '';

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
                  image: (img.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(img),
                          fit: BoxFit.fill,
                        )
                      : const DecorationImage(
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
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "$name\n",
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
                      text: "$mileage",
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

/// 🔹 ActivityBlock c данными из модели Activity
class ActivityBlock extends StatefulWidget {
  final Activity activity;
  final int currentUserId;

  const ActivityBlock({
    super.key,
    required this.activity,
    this.currentUserId = 0,
  });

  @override
  _ActivityBlockState createState() => _ActivityBlockState();
}

class _ActivityBlockState extends State<ActivityBlock>
    with SingleTickerProviderStateMixin {
  bool isLiked = false;
  int likesCount = 0;
  bool _likeBusy = false;

  late AnimationController _likeController;
  late Animation<double> _likeAnimation;

  static const String _likeEndpoint =
      'http://api.paceup.ru/activity_likes_toggle.php';

  @override
  void initState() {
    super.initState();

    // Инициализируем локальный счётчик из данных активности
    likesCount = widget.activity.likes;
    isLiked = widget.activity.islike;

    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.easeOutBack),
    );
    _likeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _likeController.reverse();
    });
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  /* void _onLikeTap() {
    setState(() => isLiked = !isLiked);
    _likeController.forward(from: 0);
  }*/
  Future<void> _onLikeTap() async {
    if (_likeBusy) return; // защита от дабл-кликов

    // Оптимистично меняем UI
    setState(() {
      _likeBusy = true;
      isLiked = !isLiked;
      likesCount += isLiked ? 1 : -1;
    });
    _likeController.forward(from: 0);

    final ok = await _sendLike(
      activityId: widget.activity.id,
      userId: widget.currentUserId,
      isLikedNow: isLiked,
      type: 'activity',
    );

    // Откат при ошибке
    if (!ok && mounted) {
      setState(() {
        isLiked = !isLiked;
        likesCount += isLiked ? 1 : -1;
      });
    }

    if (mounted) {
      setState(() => _likeBusy = false);
    }
  }

  // ⬇️ Новый метод: запрос на сервер
  Future<bool> _sendLike({
    required int activityId, //ид активности или поста
    required int userId,
    required bool isLikedNow,
    required String type,
  }) async {
    final uri = Uri.parse(_likeEndpoint);

    try {
      final res = await http
          .post(
            uri,
            // ВАЖНО: только строки!
            body: jsonEncode({
              'userId': '$userId',
              'activityId': '$activityId',
              'action': isLikedNow ? 'like' : 'dislike',
              'type': type,
            }),
            // заголовок можно не ставить: http сам проставит form-urlencoded
            // headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'},
          )
          .timeout(const Duration(seconds: 10)); // а не 1 сек

      // эти принты теперь точно выполнятся
      final raw = utf8.decode(res.bodyBytes);

      bool ok = false;
      int? serverLikes;

      // пробуем распарсить JSON; если не JSON — оставим data = null
      dynamic data;
      try {
        data = json.decode(raw);
      } catch (_) {
        data = null;
      }

      // 1) нормальный кейс: объект
      if (data is Map<String, dynamic>) {
        ok = data['ok'] == true || data['status'] == 'ok';
        final likesVal = data['likes'];
        if (likesVal != null) {
          serverLikes = int.tryParse(likesVal.toString());
        }

        // 2) сервер вернул массив с одним объектом
      } else if (data is List &&
          data.isNotEmpty &&
          data.first is Map<String, dynamic>) {
        final m = data.first as Map<String, dynamic>;
        ok = m['ok'] == true || m['status'] == 'ok';
        final likesVal = m['likes'];
        if (likesVal != null) {
          serverLikes = int.tryParse(likesVal.toString());
        }

        // 3) не-JSON: просто "ok", "1", "true" и т.п.
      } else {
        final t = raw.trim().toLowerCase();
        ok = (res.statusCode == 200) && (t == 'ok' || t == '1' || t == 'true');
        if (!ok) {}
      }

      if (!ok) return false;

      // если сервер прислал число лайков — синхронизируем
      if (serverLikes != null && mounted) {
        setState(() => likesCount = serverLikes!);
      }
      return true;
    } on TimeoutException {
      return false;
    } catch (e) {
      return false;
    }
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return ''; // или '—', если хочешь выводить прочерк

    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return "$dd.$mm.${dt.year}, $hh:$min";
  }

  String _fmtDuration(num? seconds) {
    if (seconds == null) return '';

    final totalSeconds = seconds.toInt();
    final h = (totalSeconds ~/ 3600).toString().padLeft(1, '0');
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');

    return h != '0' ? "$h:$m:$s" : "$m:$s";
  }

  String _fmtPace(double paceMinPerKm) {
    // если avgPace = минуты.десятые (5.3 ≈ 5:18)
    final minutes = paceMinPerKm.floor();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} / км';
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final stats = activity.stats;

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
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => ProfileScreen(
                          userId: activity.userId,
                        ), // если у вас без аргументов
                        // builder: (_) => ProfileScreen(userId: activity.userId), // вариант, если экран принимает id
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildAvatar(activity.userAvatar),
                  ),
                ),

                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity.userName, style: AppTextStyles.name),
                      const SizedBox(height: 2),
                      Text(
                        _fmtDate(activity.dateStart),
                        style: AppTextStyles.date,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MetricVertical(
                            mainTitle: "Расстояние",
                            mainValue: stats != null
                                ? "${(stats.distance / 1000).toStringAsFixed(2)} км"
                                : "—",
                            subTitle: "Набор высоты",
                            subValue: stats != null
                                ? "${stats.cumulativeElevationGain.toStringAsFixed(0)} м"
                                : "—",
                          ),
                          const SizedBox(width: 30),
                          MetricVertical(
                            mainTitle: "Время",
                            mainValue: stats != null
                                ? _fmtDuration(stats.duration)
                                : "—",
                            subTitle: "Каденс",
                            subValue: "—",
                          ),
                          const SizedBox(width: 30),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Темп",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                stats != null ? _fmtPace(stats.avgPace) : "—",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Ср. пульс",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    stats?.avgHeartRate?.toStringAsFixed(0) ??
                                        "—",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Equipment(items: activity.equipments),
          ),
          const SizedBox(height: 8),
          // Маршрут с данными из activity.route
          RouteCard(
            points: activity.points.map((c) => LatLng(c.lat, c.lng)).toList(),
          ),
          const SizedBox(height: 12),
          // Нижняя панель: лайки/комменты и прочее
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
                        width: 25,
                        height: 25,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
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
                    Text(
                      likesCount.toString(),
                      //activity.likes.toString(),
                      style: const TextStyle(
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
                          builder: (context) => CommentsBottomSheet(
                            itemType: 'activity',
                            itemId: activity.id,
                            currentUserId: widget.currentUserId,
                          ),
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
                    Text(
                      activity.comments.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
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
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const TogetherScreen(),
                          ),
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
                          CupertinoIcons.person_crop_circle_badge_plus,
                          size: 20,
                          color: AppColors.secondary,
                        ),
                      ),
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

  Widget _buildAvatar(String urlOrAsset) {
    // если это HTTP(S) — грузим как сеть, иначе считаем ассетом
    final isNetwork =
        urlOrAsset.startsWith('http://') || urlOrAsset.startsWith('https://');
    if (isNetwork) {
      return Image.network(
        urlOrAsset,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          "assets/Avatar_2.png",
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset(
      urlOrAsset.isNotEmpty ? urlOrAsset : "assets/Avatar_2.png",
      width: 50,
      height: 50,
      fit: BoxFit.cover,
    );
  }
}
