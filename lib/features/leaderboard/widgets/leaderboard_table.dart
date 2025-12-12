// lib/features/leaderboard/widgets/leaderboard_table.dart
// ─────────────────────────────────────────────────────────────────────────────
// Виджет таблицы лидерборда
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/leaderboard_data.dart';
import 'leaderboard_row.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     ТАБЛИЦА ЛИДЕРБОРДА
// ─────────────────────────────────────────────────────────────────────────────
/// Таблица лидерборда на всю ширину экрана с отступами по 4px
class LeaderboardTable extends StatelessWidget {
  final List<LeaderboardRowData> rows;
  final int? currentUserRank;

  const LeaderboardTable({
    super.key,
    required this.rows,
    this.currentUserRank,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          border: Border(
            top: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 0.5,
            ),
            bottom: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          // ── Пропускаем первые 3 места (они показываются в топ-3 лидерах)
          // ── Таблица начинается с 4-го места
          children: rows.length > 3
              ? List.generate(rows.length - 3, (i) {
                  final r = rows[i + 3]; // начинаем с индекса 3 (4-е место)
                  final isMe = currentUserRank != null && r.rank == currentUserRank;
                  final totalTableRows = rows.length - 3;
                  return LeaderboardRow(
                    rank: r.rank,
                    name: r.name,
                    value: r.value,
                    avatar: r.avatar,
                    highlight: isMe,
                    isLast: i == totalTableRows - 1,
                  );
                })
              : [],
        ),
      ),
    );
  }
}

