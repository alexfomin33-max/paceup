// lib/screens/chat_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final List<_Chat> _items;

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

    if (diffDays == 0) return DateFormat('H:mm').format(d);
    if (diffDays == -1) return 'Вчера, ${DateFormat('H:mm').format(d)}';
    if (diffDays == -2) return 'Позавчера, ${DateFormat('H:mm').format(d)}';
    return DateFormat('dd.MM.yyyy').format(d);
  }

  void _onHorizontalDrag(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
      Navigator.of(context).maybePop();
    }
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
            'Чаты',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                CupertinoIcons.slider_horizontal_3,
                size: 20,
                color: AppColors.text,
              ),
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
            final c = _items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Аватар
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      c.avatar,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Контент
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Первая строка: имя + время
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatWhen(c.when),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.greytext,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Вторая строка: превью сообщения
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            if (c.unread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2F7BFF), // синий индикатор
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
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

/// Демо-диалоги под макет
List<_Chat> _demo() {
  final now = DateTime.now();
  DateTime at(int h, int m, {int shiftDays = 0}) =>
      DateTime(now.year, now.month, now.day + shiftDays, h, m);

  return [
    _Chat(
      name: 'Дмитрий Фадеев',
      avatar: 'assets/Avatar_6.png',
      preview: 'Ты в субботу на коферан или может поедем на трейл?',
      when: at(9, 35),
      unread: true,
    ),
    _Chat(
      name: 'Алексей Лукашин',
      avatar: 'assets/Avatar_1.png',
      preview: 'Завтра утром со мной побежали в Мосино',
      when: at(8, 07),
      unread: true,
    ),
    _Chat(
      name: 'Субботний коферан',
      avatar: 'assets/coffeerun.png',
      preview: 'Бежим в любую погоду, даже если будет дождь ☕️',
      when: at(7, 45),
      unread: true,
    ),
    _Chat(
      name: 'Игорь Зелёный',
      avatar: 'assets/Avatar_2.png',
      preview: 'Вы: Ну чего, в Мишку то когда пойдём?',
      when: at(10, 52, shiftDays: -1),
      unread: false,
    ),
    _Chat(
      name: 'Татьяна Свиридова',
      avatar: 'assets/Avatar_3.png',
      preview: 'Ты когда уже GRUT T100 побежишь?',
      when: at(11, 34, shiftDays: -2),
      unread: false,
    ),
    _Chat(
      name: 'Екатерина Виноградова',
      avatar: 'assets/Avatar_4.png',
      preview: 'Приезжай ещё к нам в Казань на массовые старты…',
      when: DateTime(now.year, 3, 21),
      unread: false,
    ),
    _Chat(
      name: 'Женский забег "Медный Всадник"',
      avatar: 'assets/slot_7.png', // заменитель баннера события
      preview: 'Никто не знает, когда выложат программу забега?',
      when: DateTime(now.year, 3, 20),
      unread: false,
    ),
  ];
}

/// Локальная модель диалога
class _Chat {
  final String name;
  final String avatar;
  final String preview;
  final DateTime when;
  final bool unread;
  const _Chat({
    required this.name,
    required this.avatar,
    required this.preview,
    required this.when,
    required this.unread,
  });
}
