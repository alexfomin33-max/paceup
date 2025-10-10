// lib/screens/lenta/widgets/activity/header/activity_header.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../utils/activity_format.dart';
import 'avatar.dart';
import '../../../../profile/profile_screen.dart';
import '../../../../../theme/app_theme.dart';

/// Шапка тренировки: аватар, имя, дата.
/// Здесь — только навигация в профиль и отображение.
class ActivityHeader extends StatelessWidget {
  final int userId;
  final String userName;
  final String userAvatar;
  final DateTime? dateStart;

  const ActivityHeader({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.dateStart,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => ProfileScreen(userId: userId)),
            );
          },
          child: ClipOval(child: Avatar(image: userAvatar, size: 50)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userName, style: AppTextStyles.name),
              const SizedBox(height: 2),
              Text(
                formatDate(dateStart),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
