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
/// Таблица лидерборда на всю ширину экрана
/// Горизонтальные отступы задаются в родительских вкладках (12px)
class LeaderboardTable extends StatelessWidget {
  final List<LeaderboardRowData> rows;
  final int? currentUserRank;
  final bool showAllIfLessThanThree;

  const LeaderboardTable({
    super.key,
    required this.rows,
    this.currentUserRank,
    this.showAllIfLessThanThree = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        // ── Если пользователей меньше 3 и showAllIfLessThanThree = true, показываем всех
        // ── Иначе пропускаем первые 3 места (они показываются в топ-3 лидерах)
        // ── Таблица начинается с 4-го места
        children: _buildTableRows(),
      ),
    );
  }

  List<Widget> _buildTableRows() {
    // Если пользователей меньше 3 и нужно показать всех
    if (showAllIfLessThanThree && rows.length < 3) {
      return List.generate(rows.length, (i) {
        final r = rows[i];
        final isMe = currentUserRank != null && r.rank == currentUserRank;
        return LeaderboardRow(
          rank: r.rank,
          name: r.name,
          value: r.value,
          avatarUrl: r.avatarUrl,
          highlight: isMe,
          isLast: i == rows.length - 1,
          userId: r.userId,
        );
      });
    }
    
    // Если пользователей 3 или больше, показываем только с 4-го места
    if (rows.length > 3) {
      return List.generate(rows.length - 3, (i) {
        final r = rows[i + 3]; // начинаем с индекса 3 (4-е место)
        final isMe = currentUserRank != null && r.rank == currentUserRank;
        final totalTableRows = rows.length - 3;
        return LeaderboardRow(
          rank: r.rank,
          name: r.name,
          value: r.value,
          avatarUrl: r.avatarUrl,
          highlight: isMe,
          isLast: i == totalTableRows - 1,
          userId: r.userId,
        );
      });
    }
    
    // Если пользователей ровно 3, таблица пустая (все в топ-3)
    return [];
  }
}

