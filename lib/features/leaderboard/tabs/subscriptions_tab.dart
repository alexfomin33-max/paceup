// lib/features/leaderboard/tabs/subscriptions_tab.dart
// ─────────────────────────────────────────────────────────────────────────────
// Вкладка "Подписки" лидерборда
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/leaderboard_filters_panel.dart';
import '../widgets/leaderboard_table.dart';
import '../widgets/top_three_leaders.dart';
import '../providers/subscriptions_leaderboard_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     ВКЛАДКА "ПОДПИСКИ"
// ─────────────────────────────────────────────────────────────────────────────
class SubscriptionsTab extends ConsumerStatefulWidget {
  const SubscriptionsTab({super.key});

  @override
  ConsumerState<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends ConsumerState<SubscriptionsTab>
    with AutomaticKeepAliveClientMixin {
  // ── выбранный параметр лидерборда (по умолчанию "Расстояние")
  String? _selectedParameter = 'Расстояние';

  // ── вид спорта: 0 бег, 1 вело, 2 плавание (single-select)
  int _sport = 0;

  // ── выбранный период (по умолчанию "Текущая неделя")
  String? _selectedPeriod = 'Текущая неделя';

  // ── пол: по умолчанию оба выбраны, всегда хотя бы один должен быть активен
  bool _genderMale = true;
  bool _genderFemale = true;
  
  // ── выбранный диапазон дат для кастомного периода
  DateTimeRange? _selectedDateRange;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Обязательно вызываем для AutomaticKeepAliveClientMixin
    // Преобразуем период в формат для API
    String period = 'current_week';
    if (_selectedPeriod == 'Текущий месяц') {
      period = 'current_month';
    } else if (_selectedPeriod == 'Текущий год') {
      period = 'current_year';
    } else if (_selectedPeriod == 'Выбранный период') {
      period = 'custom';
    }

    final params = SubscriptionsLeaderboardParams(
      sport: _sport,
      period: period,
      dateStart: _selectedDateRange != null
          ? _selectedDateRange!.start.toIso8601String().split('T')[0] // YYYY-MM-DD
          : null,
      dateEnd: _selectedDateRange != null
          ? _selectedDateRange!.end.toIso8601String().split('T')[0] // YYYY-MM-DD
          : null,
      genderMale: _genderMale,
      genderFemale: _genderFemale,
      parameter: _selectedParameter ?? 'Расстояние',
    );

    final leaderboardAsync = ref.watch(
      subscriptionsLeaderboardProvider(params),
    );

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
                  });
                  // Обновляем данные при изменении параметра
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final newParams = SubscriptionsLeaderboardParams(
                      sport: _sport,
                      period: period,
                      dateStart: _selectedDateRange != null
                          ? _selectedDateRange!.start.toIso8601String().split('T')[0]
                          : null,
                      dateEnd: _selectedDateRange != null
                          ? _selectedDateRange!.end.toIso8601String().split('T')[0]
                          : null,
                      genderMale: _genderMale,
                      genderFemale: _genderFemale,
                      parameter: newValue,
                    );
                    ref.invalidate(subscriptionsLeaderboardProvider(newParams));
                  });
                }
              },
              onSportChanged: (int sport) {
                setState(() {
                  _sport = sport;
                });
              },
              onPeriodChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedPeriod = newValue;
                    // Сбрасываем выбранные даты, если период изменился на не "Выбранный период"
                    if (newValue != 'Выбранный период') {
                      _selectedDateRange = null;
                    }
                  });
                }
              },
              onGenderMaleChanged: (bool value) {
                setState(() {
                  _genderMale = value;
                });
                // Обновляем данные при изменении фильтра по полу
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final newParams = SubscriptionsLeaderboardParams(
                    sport: _sport,
                    period: period,
                    dateStart: _selectedDateRange != null
                        ? _selectedDateRange!.start.toIso8601String().split('T')[0]
                        : null,
                    dateEnd: _selectedDateRange != null
                        ? _selectedDateRange!.end.toIso8601String().split('T')[0]
                        : null,
                    genderMale: value,
                    genderFemale: _genderFemale,
                  );
                  ref.invalidate(subscriptionsLeaderboardProvider(newParams));
                });
              },
              onGenderFemaleChanged: (bool value) {
                setState(() {
                  _genderFemale = value;
                });
                // Обновляем данные при изменении фильтра по полу
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final newParams = SubscriptionsLeaderboardParams(
                    sport: _sport,
                    period: period,
                    dateStart: _selectedDateRange != null
                        ? _selectedDateRange!.start.toIso8601String().split('T')[0]
                        : null,
                    dateEnd: _selectedDateRange != null
                        ? _selectedDateRange!.end.toIso8601String().split('T')[0]
                        : null,
                    genderMale: _genderMale,
                    genderFemale: value,
                  );
                  ref.invalidate(subscriptionsLeaderboardProvider(newParams));
                });
              },
              onApplyDate: (dateRange) {
                setState(() {
                  _selectedDateRange = dateRange;
                });
                // Обновляем данные при применении дат (после обновления состояния)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Преобразуем период в формат для API
                  String periodValue = 'current_week';
                  if (_selectedPeriod == 'Текущий месяц') {
                    periodValue = 'current_month';
                  } else if (_selectedPeriod == 'Текущий год') {
                    periodValue = 'current_year';
                  } else if (_selectedPeriod == 'Выбранный период') {
                    periodValue = 'custom';
                  }
                  
                  final newParams = SubscriptionsLeaderboardParams(
                    sport: _sport,
                    period: periodValue,
                    dateStart: dateRange != null
                        ? dateRange.start.toIso8601String().split('T')[0]
                        : null,
                    dateEnd: dateRange != null
                        ? dateRange.end.toIso8601String().split('T')[0]
                        : null,
                  );
                  ref.invalidate(subscriptionsLeaderboardProvider(newParams));
                });
              },
            ),
          ),

          // ── Контент лидерборда
          leaderboardAsync.when(
            data: (result) {
              final rows = result.leaderboard;
              final currentUserRank = result.currentUserRank;
              
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'Нет данных для отображения',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // ── Топ-3 лидера перед таблицей (только если есть 3+ пользователя)
                  if (rows.length >= 3) TopThreeLeaders(rows: rows),
                  if (rows.length >= 3) const SizedBox(height: 16),
                  // ── Таблица лидерборда на всю ширину с отступами по 4px
                  // Если пользователей меньше 3, показываем всех в таблице
                  // Если 3 или больше, показываем только с 4-го места
                  LeaderboardTable(
                    rows: rows,
                    currentUserRank: currentUserRank,
                    showAllIfLessThanThree: true,
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'Ошибка загрузки данных',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(subscriptionsLeaderboardProvider(params));
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
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

