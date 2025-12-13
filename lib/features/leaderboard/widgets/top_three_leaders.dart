// lib/features/leaderboard/widgets/top_three_leaders.dart
// ─────────────────────────────────────────────────────────────────────────────
// Виджет для отображения топ-3 лидеров
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/leaderboard_data.dart';
import 'leaderboard_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     ТОП-3 ЛИДЕРА
// ─────────────────────────────────────────────────────────────────────────────
/// Виджет для отображения топ-3 лидеров в стиле all_results_screen.dart
class TopThreeLeaders extends StatelessWidget {
  final List<LeaderboardRowData> rows;

  const TopThreeLeaders({
    super.key,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    // ── Берем первые 3 элемента из данных
    final topThree = rows.take(3).toList();
    if (topThree.length < 3) {
      return const SizedBox.shrink();
    }

    return Padding(
      // ── Отступы слева и справа как у элементов выше (16px)
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        // ── Светлый фон для светлой темы с закруглением углов и тонкой рамкой
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // ── 2 место (слева)
            LeaderboardAvatar(
              rank: topThree[1].rank,
              name: topThree[1].name,
              value: topThree[1].value,
              avatarUrl: topThree[1].avatarUrl,
              borderColor: AppColors.textSecondary, // светло-серый
              userId: topThree[1].userId,
            ),
            // ── 1 место (по центру, больше)
            LeaderboardAvatar(
              rank: topThree[0].rank,
              name: topThree[0].name,
              value: topThree[0].value,
              avatarUrl: topThree[0].avatarUrl,
              borderColor: AppColors.accentYellow, // желтый
              isFirst: true,
              userId: topThree[0].userId,
            ),
            // ── 3 место (справа)
            LeaderboardAvatar(
              rank: topThree[2].rank,
              name: topThree[2].name,
              value: topThree[2].value,
              avatarUrl: topThree[2].avatarUrl,
              borderColor: AppColors.orange, // оранжевый
              userId: topThree[2].userId,
            ),
          ],
        ),
      ),
    );
  }
}

