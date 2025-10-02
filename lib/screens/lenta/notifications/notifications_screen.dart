// lib/screens/notifications_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

// ⬇️ наш полноэкранный шит с настройками уведомлений
import 'settings_sheet.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final List<_Notif> _items;

  @override
  void initState() {
    super.initState();
    _items = _demo();
  }

  String _formatWhen(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diffDays = day.difference(today).inDays;

    if (diffDays == 0) return DateFormat('HH:mm').format(d);
    if (diffDays == -1) return 'Вчера, ${DateFormat('HH:mm').format(d)}';
    if (diffDays == -2) return 'Позавчера, ${DateFormat('HH:mm').format(d)}';
    return DateFormat('dd.MM.yyyy').format(d);
  }

  void _onHorizontalDrag(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
      Navigator.of(context).maybePop();
    }
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true, // поверх нижней навигации
      isScrollControlled: true, // высота по контенту
      backgroundColor: Colors.transparent, // радиусы рисуем сами
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: _onHorizontalDrag,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          leadingWidth: 60,
          leading: IconButton(
            splashRadius: 22,
            icon: const Icon(
              CupertinoIcons.back,
              size: 22,
              color: AppColors.text,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Уведомления',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          actions: [
            IconButton(
              padding: const EdgeInsets.only(right: 12),
              icon: const Icon(
                CupertinoIcons.slider_horizontal_3,
                size: 20,
                color: AppColors.text,
              ),
              onPressed: _openSettingsSheet,
              splashRadius: 22,
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(0.5),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: AppColors.border,
            ),
          ),
        ),
        body: ListView.separated(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: _items.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          itemBuilder: (context, i) {
            final n = _items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Аватар
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      n.avatar,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Контент: 1-я строка (иконка + дата), 2-я строка (текст)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Первая строка — иконка и время на одной линии
                        Row(
                          children: [
                            Icon(n.icon, size: 16, color: n.color),
                            const Spacer(),
                            Text(
                              _formatWhen(n.when),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.greytext,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Вторая строка — текст
                        Text(
                          n.text,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.text,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Демо-данные под макет (иконки — безопасные Material/ Cupertino аналоги)
List<_Notif> _demo() {
  final now = DateTime.now();
  DateTime onDay(DateTime base, int hour, int min, {int shiftDays = 0}) =>
      DateTime(base.year, base.month, base.day + shiftDays, hour, min);

  return [
    _Notif(
      avatar: 'assets/Avatar_2.png',
      icon: Icons.directions_run,
      color: AppColors.secondary,
      text: 'Игорь Зелёный закончил забег 10,5 км.',
      when: onDay(now, 7, 14),
    ),
    _Notif(
      avatar: 'assets/Avatar_1.png',
      icon: Icons.directions_bike,
      color: Colors.blue,
      text: 'Алексей Лукашин закончил заезд 54,2 км.',
      when: onDay(now, 14, 32, shiftDays: -1),
    ),
    _Notif(
      avatar: 'assets/Avatar_9.png',
      icon: CupertinoIcons.heart,
      color: Colors.pink,
      text: 'Лейла Мустафаева оценила вашу тренировку',
      when: onDay(now, 10, 48, shiftDays: -1),
    ),
    _Notif(
      avatar: 'assets/Avatar_3.png',
      icon: CupertinoIcons.square_pencil,
      color: AppColors.green,
      text: 'Татьяна Свиридова опубликовала новый пост',
      when: onDay(now, 16, 26, shiftDays: -2),
    ),
    _Notif(
      avatar: 'assets/coffeerun.png',
      icon: Icons.directions_walk,
      color: AppColors.secondary,
      text: 'Клуб "Coffeerun" разместил новое событие',
      when: DateTime(now.year, 3, 21),
    ),
    _Notif(
      avatar: 'assets/Avatar_4.png',
      icon: CupertinoIcons.text_bubble,
      color: AppColors.orange,
      text: 'Екатерина Виноградова оставила комментарий к посту',
      when: DateTime(now.year, 3, 20),
    ),
    _Notif(
      avatar: 'assets/Avatar_6.png',
      icon: Icons.pool,
      color: Colors.lightBlue,
      text: 'Дмитрий Фадеев закончил заплыв 3,8 км.',
      when: DateTime(now.year, 3, 18),
    ),
    _Notif(
      avatar: 'assets/Avatar_1.png',
      icon: Icons.emoji_events_outlined,
      color: Colors.purple,
      text:
          'Алексей Лукашин зарегистрировался на забег "Ночь. Стрелка. Ярославль", 19 июля 2025. 42,2 км',
      when: DateTime(now.year, 3, 16),
    ),
  ];
}

/// Локальная модель
class _Notif {
  final String avatar;
  final IconData icon;
  final Color color;
  final String text;
  final DateTime when;
  const _Notif({
    required this.avatar,
    required this.icon,
    required this.color,
    required this.text,
    required this.when,
  });
}
