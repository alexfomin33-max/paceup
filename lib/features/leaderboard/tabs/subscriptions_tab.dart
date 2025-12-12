// lib/features/leaderboard/tabs/subscriptions_tab.dart
// ─────────────────────────────────────────────────────────────────────────────
// Вкладка "Подписки" лидерборда
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/leaderboard_data.dart';
import '../widgets/leaderboard_filters_panel.dart';
import '../widgets/leaderboard_table.dart';
import '../widgets/top_three_leaders.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     ВКЛАДКА "ПОДПИСКИ"
// ─────────────────────────────────────────────────────────────────────────────
class SubscriptionsTab extends ConsumerStatefulWidget {
  const SubscriptionsTab({super.key});

  @override
  ConsumerState<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends ConsumerState<SubscriptionsTab> {
  // ── выбранный параметр лидерборда (по умолчанию "Расстояние")
  String? _selectedParameter = 'Расстояние';

  // ── вид спорта: 0 бег, 1 вело, 2 плавание (single-select)
  int _sport = 0;

  // ── выбранный период (по умолчанию "Текущая неделя")
  String? _selectedPeriod = 'Текущая неделя';

  // ── пол: по умолчанию оба выбраны, всегда хотя бы один должен быть активен
  bool _genderMale = true;
  bool _genderFemale = true;

  @override
  Widget build(BuildContext context) {
    // TODO: заменить на реальные данные из API
    final rows = kDemoLeaderboardRows;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Верхние элементы с padding
          Padding(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            child: LeaderboardFiltersPanel(
              selectedParameter: _selectedParameter,
              sport: _sport,
              selectedPeriod: _selectedPeriod,
              genderMale: _genderMale,
              genderFemale: _genderFemale,
              onParameterChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedParameter = newValue;
                    // TODO: здесь будет фильтрация лидерборда по выбранному параметру
                  });
                }
              },
              onSportChanged: (int sport) {
                setState(() {
                  _sport = sport;
                  // TODO: здесь будет фильтрация лидерборда по виду спорта
                });
              },
              onPeriodChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedPeriod = newValue;
                    // TODO: здесь будет фильтрация лидерборда по выбранному периоду
                  });
                }
              },
              onGenderMaleChanged: (bool value) {
                setState(() {
                  _genderMale = value;
                  // TODO: здесь будет фильтрация лидерборда по полу
                });
              },
              onGenderFemaleChanged: (bool value) {
                setState(() {
                  _genderFemale = value;
                  // TODO: здесь будет фильтрация лидерборда по полу
                });
              },
              onApplyDate: () {
                // TODO: здесь будет применение выбранного периода
              },
            ),
          ),

          // ── Топ-3 лидера перед таблицей
          TopThreeLeaders(rows: rows),
          const SizedBox(height: 16),
          // ── Таблица лидерборда на всю ширину с отступами по 4px
          LeaderboardTable(
            rows: rows,
            currentUserRank: 4, // TODO: получить из API
          ),
          // ── Отступ снизу, чтобы контент не перекрывался нижним меню
          Builder(
            builder: (context) =>
                SizedBox(height: MediaQuery.of(context).padding.bottom + 60),
          ),
        ],
      ),
    );
  }
}

