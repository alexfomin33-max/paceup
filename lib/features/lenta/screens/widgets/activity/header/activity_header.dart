// lib/screens/lenta/widgets/activity/header/activity_header.dart
import 'package:flutter/cupertino.dart';
import '../../../../widgets/user_header.dart';
import '../../../../../profile/screens/profile_screen.dart';
import '../../../../../../core/utils/feed_date.dart';

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

  /// Слот между заголовком и bottom — сюда передаём описание тренировки
  final Widget? middle;
  final double middleGap;

  /// Слот снизу — сюда передаём StatsRow из ActivityBlock
  final Widget? bottom;
  final double bottomGap;

  /// Trailing виджет (например, кнопка меню с тремя точками)
  final Widget? trailing;

  const ActivityHeader({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.dateStart,
    this.dateTextOverride,
    this.middle,
    this.middleGap = 12.0,
    this.bottom,
    this.bottomGap = 18.0,
    this.trailing,
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

    // ──────────────────────────────────────────────────────────────
    // ОБРАБОТЧИК ПЕРЕХОДА В ПРОФИЛЬ: используется для аватара и имени
    // ──────────────────────────────────────────────────────────────
    void openProfile() {
      Navigator.of(
        context,
      ).push(CupertinoPageRoute(builder: (_) => ProfileScreen(userId: userId)));
    }

    return UserHeader(
      userName: userName,
      userAvatar: userAvatar,
      dateText: dateText,
      onAvatarTap: openProfile,
      onNameTap: openProfile,
      middle: middle,
      middleGap: middleGap,
      bottom: bottom,
      bottomGap: bottomGap,
      trailing: trailing,
    );
  }
}
