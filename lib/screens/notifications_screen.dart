import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_item.dart';

/// 🔹 Экран уведомлений
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    // Пример уведомлений с аватарами
    _notifications.addAll([
      NotificationItem(
        title: "Новая подписка",
        body: "Пользователь Алексей подписался на вас.",
        date: DateTime.now().subtract(const Duration(minutes: 5)),
        avatarAsset: "assets/Avatar_1.png",
      ),
      NotificationItem(
        title: "Новый комментарий",
        body: "Мария оставила комментарий к вашему посту.",
        date: DateTime.now().subtract(const Duration(hours: 1)),
        avatarAsset: "assets/Avatar_2.png",
      ),
      NotificationItem(
        title: "Обновление приложения",
        body: "Доступна новая версия приложения.",
        date: DateTime.now().subtract(const Duration(days: 1)),
        avatarAsset: "assets/Avatar_3.png",
      ),
    ]);
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return "${diff.inMinutes} мин назад";
    if (diff.inHours < 24) return "${diff.inHours} ч назад";
    return DateFormat('dd.MM.yyyy').format(date);
  }

  // 🔹 Обработчик свайпа вправо
  void _onHorizontalDrag(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: _onHorizontalDrag,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Оповещения"),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          actions: [
            if (_notifications.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    _notifications.clear();
                  });
                },
              ),
          ],
        ),
        body: _notifications.isEmpty
            ? const Center(
                child: Text(
                  "Уведомлений пока нет",
                  style: TextStyle(fontSize: 16),
                ),
              )
            : ListView.separated(
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  return ListTile(
                    leading: notif.avatarAsset != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              notif.avatarAsset!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.notifications),
                    title: Text(
                      notif.title,
                      style: TextStyle(
                        fontWeight: notif.viewed
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(notif.body),
                    trailing: Text(
                      _timeAgo(notif.date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      setState(() {
                        notif.viewed =
                            true; // отмечаем уведомление как просмотренное
                      });
                      // Здесь можно добавить логику перехода к конкретному уведомлению
                    },
                  );
                },
              ),
      ),
    );
  }
}
