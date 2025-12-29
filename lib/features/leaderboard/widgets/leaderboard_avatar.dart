// lib/features/leaderboard/widgets/leaderboard_avatar.dart
// ─────────────────────────────────────────────────────────────────────────────
// Виджет аватара лидера с рамкой и значком места
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/transparent_route.dart';
import '../../profile/screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     АВАТАР ЛИДЕРА С РАМКОЙ И ЗНАЧКОМ
// ─────────────────────────────────────────────────────────────────────────────
/// Аватар лидера в стиле _LeaderCard из all_results_screen.dart:
/// цветной контейнер с padding, значок в правом нижнем углу
class LeaderboardAvatar extends StatelessWidget {
  final int rank;
  final String name;
  final String value;
  final String avatarUrl;
  final Color borderColor;
  final bool isFirst;
  final int? userId; // ID пользователя для навигации в профиль

  const LeaderboardAvatar({
    super.key,
    required this.rank,
    required this.name,
    required this.value,
    required this.avatarUrl,
    required this.borderColor,
    this.isFirst = false,
    this.userId,
  });

  void _navigateToProfile(BuildContext context) {
    if (userId != null) {
      Navigator.of(context).push(
        TransparentPageRoute(
          builder: (_) => ProfileScreen(userId: userId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Размер внешнего контейнера: 1 место заметно больше, остальные одинаковые
    final containerSize = isFirst ? 104.0 : 80.0;
    // ── Размер внутреннего аватара (с учетом padding)
    final avatarSize = containerSize - 6; // padding 3px с каждой стороны
    // ── Размер значка места (для первого места немного больше)
    final badgeSize = isFirst ? 26.0 : 24.0;
    // ── Позиция значка пропорциональна размеру контейнера для визуального выравнивания
    // ── Для 80px используется 2px, для 104px нужно ~2.6px (округляем до 3px)
    final badgeOffset = isFirst ? 3.0 : 2.0;

    return Column(
      children: [
        // ── Аватар с цветной обводкой и значком (стиль как в _LeaderCard)
        GestureDetector(
          onTap: userId != null ? () => _navigateToProfile(context) : null,
          child: SizedBox(
            width: containerSize,
            height: containerSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Цветной контейнер с padding (вместо border)
                Container(
                  width: containerSize,
                  height: containerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: borderColor,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    // ── Промежуточная обводка цвета фона
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.getSurfaceColor(context),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        width:
                            avatarSize -
                            4, // учитываем промежуточную обводку (2px с каждой стороны)
                        height: avatarSize - 4,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: avatarSize - 4,
                          height: avatarSize - 4,
                          color: AppColors.getBackgroundColor(context),
                          child: Center(
                            child: CupertinoActivityIndicator(
                              radius: (avatarSize - 4) * 0.15,
                              color: AppColors.getIconSecondaryColor(context),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: avatarSize - 4,
                          height: avatarSize - 4,
                          color: AppColors.getBackgroundColor(context),
                          child: Icon(
                            CupertinoIcons.person_fill,
                            size: (avatarSize - 4) * 0.6,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // ── Значок с номером места в правом нижнем углу
              // ── Позиционирование пропорционально размеру контейнера для визуального выравнивания
              Positioned(
                right: badgeOffset,
                bottom: badgeOffset,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: borderColor,
                    border: Border.all(
                      color: AppColors.getSurfaceColor(context),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
        const SizedBox(height: 8),
        // ── Имя пользователя (стиль как в таблице, одна строка, чуть толще) - кликабельное
        GestureDetector(
          onTap: userId != null ? () => _navigateToProfile(context) : null,
          child: SizedBox(
            width: containerSize + 20, // немного шире контейнера для текста
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        // ── Значение из правой колонки таблицы
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ],
    );
  }
}
