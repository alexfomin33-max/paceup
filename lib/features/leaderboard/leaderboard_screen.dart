// lib/features/leaderboard/leaderboard_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран «Лидерборд» с PaceAppBar + TabBar для переключения вкладок
// Переключение вкладок через TabBarView со свайпом и синхронизированным TabBar.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bar.dart';
import 'tabs/subscriptions_tab.dart';
import 'tabs/all_users_tab.dart';
import 'tabs/city_tab.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Фон из темы: в светлой теме — surface, в темной — из темы
      backgroundColor: AppColors.getBackgroundColor(context),

      // ── Глобальная шапка без нижнего бордера
      appBar: const PaceAppBar(
        title: 'Лидерборд',
        showBack: false,
        showBottomDivider: false,
      ),

      body: Column(
        children: [
          // ── Вкладки: только текст (без иконок)
          Container(
            // ── Цвет контейнера вкладок из темы
            color: AppColors.getSurfaceColor(context),
            child: TabBar(
              controller: _tab,
              isScrollable: false,
              // ── Активная вкладка: всегда brandPrimary (одинаковый в светлой/темной)
              labelColor: AppColors.brandPrimary,
              // ── Неактивные вкладки: вторичный текст из темы
              unselectedLabelColor: AppColors.getTextSecondaryColor(context),
              indicatorColor: AppColors.brandPrimary,
              indicatorWeight: 1,
              labelPadding: const EdgeInsets.symmetric(horizontal: 0),
              tabs: const [
                Tab(text: 'Подписки'),
                Tab(text: 'Все пользователи'),
                Tab(text: 'Город'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const BouncingScrollPhysics(),
              children: const [
                SubscriptionsTab(
                  key: PageStorageKey('leaderboard_subscriptions'),
                ),
                AllUsersTab(key: PageStorageKey('leaderboard_users')),
                CityTab(key: PageStorageKey('leaderboard_city')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
