// lib/features/leaderboard/widgets/leaderboard_row.dart
// ─────────────────────────────────────────────────────────────────────────────
// Виджет строки таблицы лидерборда
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/transparent_route.dart';
import '../../profile/screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     СТРОКА ТАБЛИЦЫ ЛИДЕРБОРДА
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final String value;
  final String avatarUrl;
  final bool highlight;
  final bool isLast;
  final int? userId; // ID пользователя для навигации в профиль

  const LeaderboardRow({
    super.key,
    required this.rank,
    required this.name,
    required this.value,
    required this.avatarUrl,
    required this.highlight,
    required this.isLast,
    this.userId,
  });

  void _navigateToProfile(BuildContext context) {
    if (userId != null) {
      Navigator.of(context).push(
        TransparentPageRoute(builder: (_) => ProfileScreen(userId: userId!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: highlight
                    ? AppColors.success
                    : AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Кликабельный аватар
          GestureDetector(
            onTap: userId != null ? () => _navigateToProfile(context) : null,
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                // ── Встроенная анимация fade-in работает по умолчанию
                placeholder: (context, url) => Container(
                  width: 32,
                  height: 32,
                  color: AppColors.getBackgroundColor(context),
                  child: Center(
                    child: CupertinoActivityIndicator(
                      radius: 8,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 32,
                  height: 32,
                  color: AppColors.getBackgroundColor(context),
                  child: Icon(
                    CupertinoIcons.person_fill,
                    size: 20,
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Кликабельное имя
          Expanded(
            child: GestureDetector(
              onTap: userId != null ? () => _navigateToProfile(context) : null,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: highlight
                      ? AppColors.success
                      : AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: highlight
                  ? AppColors.success
                  : AppColors.getTextPrimaryColor(context),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        row,
        // if (!isLast)
        //   Divider(
        //     height: 1,
        //     thickness: 0.5,
        //     indent: 12,
        //     endIndent: 12,
        //     color: AppColors.getDividerColor(context),
        //   ),
      ],
    );
  }
}
