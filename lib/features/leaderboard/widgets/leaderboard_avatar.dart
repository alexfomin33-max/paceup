// lib/features/leaderboard/widgets/leaderboard_avatar.dart
// ─────────────────────────────────────────────────────────────────────────────
// Виджет аватара лидера с рамкой и значком места
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     АВАТАР ЛИДЕРА С РАМКОЙ И ЗНАЧКОМ
// ─────────────────────────────────────────────────────────────────────────────
/// Аватар лидера в стиле _LeaderCard из all_results_screen.dart:
/// цветной контейнер с padding, значок в правом нижнем углу
class LeaderboardAvatar extends StatelessWidget {
  final int rank;
  final String name;
  final String value;
  final AssetImage avatar;
  final Color borderColor;
  final bool isFirst;

  const LeaderboardAvatar({
    super.key,
    required this.rank,
    required this.name,
    required this.value,
    required this.avatar,
    required this.borderColor,
    this.isFirst = false,
  });

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
        SizedBox(
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
                    child: Image(
                      image: avatar,
                      width:
                          avatarSize -
                          4, // учитываем промежуточную обводку (2px с каждой стороны)
                      height: avatarSize - 4,
                      fit: BoxFit.cover,
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
                      style: TextStyle(
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
        const SizedBox(height: 8),
        // ── Имя пользователя (стиль как в таблице, одна строка, чуть толще)
        SizedBox(
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

