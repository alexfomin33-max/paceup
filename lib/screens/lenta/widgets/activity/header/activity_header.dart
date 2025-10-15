// lib/screens/lenta/widgets/activity/header/activity_header.dart
import 'package:flutter/cupertino.dart';
import '../../../../../widgets/user_header.dart';
import '../../../../profile/profile_screen.dart';
import '../../../../../utils/feed_date.dart';

/// ──────────────────────────────────────────────────────────────
/// ШАПКА АКТИВНОСТИ: обёртка над UserHeader (единый визуал)
/// ──────────────────────────────────────────────────────────────
class ActivityHeader extends StatelessWidget {
  final int userId;
  final String userName;
  final String userAvatar;
  final DateTime? dateStart;

  /// Если пришёл готовый текст даты из модели — передаём сюда.
  /// Он будет иметь приоритет над локальным форматированием.
  final String? dateTextOverride;

  /// Слот снизу — сюда передаём StatsRow из ActivityBlock
  final Widget? bottom;
  final double bottomGap;

  const ActivityHeader({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.dateStart,
    this.dateTextOverride,
    this.bottom,
    this.bottomGap = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────────────────────────────────
    // ЕДИНЫЙ ФОРМАТ ДАТЫ ДЛЯ ЛЕНТЫ
    // ──────────────────────────────────────────────────────────────
    final String dateText = formatFeedDateText(
      serverText:
          dateTextOverride, // если есть «постовый» текст — используем его
      date: dateStart, // иначе локально форматируем
    );

    return UserHeader(
      userName: userName,
      userAvatar: userAvatar,
      dateText: dateText,
      onAvatarTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => ProfileScreen(userId: userId)),
        );
      },
      bottom: bottom,
      bottomGap: bottomGap,
    );
  }
}
