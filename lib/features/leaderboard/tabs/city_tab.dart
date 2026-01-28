// lib/features/leaderboard/tabs/city_tab.dart
// ─────────────────────────────────────────────────────────────────────────────
// Вкладка "Город" лидерборда с полем поиска города
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/auth_service.dart';
import '../../profile/providers/profile_header_provider.dart';
import '../providers/city_leaderboard_provider.dart';
import '../widgets/city_autocomplete_field.dart';
import '../widgets/leaderboard_filters_panel.dart';
import '../widgets/leaderboard_table.dart';
import '../widgets/top_three_leaders.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     ВКЛАДКА "ГОРОД"
// ─────────────────────────────────────────────────────────────────────────────
class CityTab extends ConsumerStatefulWidget {
  const CityTab({super.key});

  @override
  ConsumerState<CityTab> createState() => _CityTabState();
}

class _CityTabState extends ConsumerState<CityTab>
    with AutomaticKeepAliveClientMixin {
  // ── контроллер для поля поиска города
  final _cityController = TextEditingController();

  // ── список городов для автокомплита
  List<String> _cities = [];

  // ── выбранный город
  String? _selectedCity;

  // ── выбранный параметр лидерборда (по умолчанию "Расстояние")
  String? _selectedParameter = 'Расстояние';

  // ── вид спорта: 0 бег, 1 вело, 2 плавание, 3 лыжи (single-select)
  int _sport = 0;
  bool _defaultSportSet = false;

  // ── выбранный период (по умолчанию "Текущий месяц")
  String? _selectedPeriod = 'Текущий месяц';

  // ── пол: по умолчанию оба выбраны, всегда хотя бы один должен быть активен
  bool _genderMale = true;
  bool _genderFemale = true;

  // ── выбранный диапазон дат для кастомного периода
  DateTimeRange? _selectedDateRange;

  // ── флаг для отслеживания, был ли город уже установлен из профиля
  bool _citySetFromProfile = false;

  // ── ID авторизованного пользователя
  int? _currentUserId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Загружаем список городов при инициализации
    _loadCities();
    // Загружаем город пользователя
    _loadUserCity();
  }

  /// Загрузка города авторизованного пользователя
  Future<void> _loadUserCity() async {
    try {
      final authService = AuthService();
      final userId = await authService.getUserId();
      if (userId != null && mounted) {
        setState(() {
          _currentUserId = userId;
        });
      }
    } catch (e) {
      // Игнорируем ошибки при получении userId
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  /// Загрузка списка городов из БД через API
  Future<void> _loadCities() async {
    try {
      final api = ApiService();
      final data = await api
          .get('/get_cities.php')
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException(
                'Превышено время ожидания загрузки городов',
              );
            },
          );

      if (data['success'] == true && data['cities'] != null) {
        final cities = data['cities'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _cities = cities.map((city) => city.toString()).toList();
          });
        }
      }
    } catch (e) {
      // В случае ошибки оставляем пустой список
      // Пользователь все равно сможет ввести город вручную
    }
  }

  /// Применение выбранного города
  void _applyCity() {
    final city = _cityController.text.trim();
    if (city.isNotEmpty) {
      // Проверяем, что город выбран из списка
      if (!_cities.contains(city)) {
        // Город не найден в списке - очищаем поле
        _cityController.clear();
        setState(() {
          _selectedCity = null;
        });
        return;
      }
      setState(() {
        _selectedCity = city;
      });
      // Обновляем данные при применении города
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateLeaderboard();
      });
    }
  }

  /// Обновление лидерборда с текущими параметрами
  void _updateLeaderboard() {
    String period = 'current_week';
    if (_selectedPeriod == 'Текущий месяц') {
      period = 'current_month';
    } else if (_selectedPeriod == 'Текущий год') {
      period = 'current_year';
    } else if (_selectedPeriod == 'Выбранный период') {
      period = 'custom';
    }

    final newParams = CityLeaderboardParams(
      city: _selectedCity,
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
      parameter: _selectedParameter ?? 'Расстояние',
    );
    ref.invalidate(cityLeaderboardProvider(newParams));
  }

  @override
  Widget build(BuildContext context) {
    super.build(
      context,
    ); // Обязательно вызываем для AutomaticKeepAliveClientMixin
    // По умолчанию активна иконка основного вида спорта пользователя (users.sport)
    if (!_defaultSportSet) {
      _defaultSportSet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _sport = ref.read(defaultSportIndexProvider);
          });
        }
      });
    }
    // ── Загружаем профиль пользователя для получения города
    if (_currentUserId != null) {
      final profileState = ref.watch(profileHeaderProvider(_currentUserId!));

      // ── Устанавливаем город из профиля, если он доступен и еще не был установлен
      if (!_citySetFromProfile &&
          profileState.profile != null &&
          profileState.profile!.city != null &&
          profileState.profile!.city!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_citySetFromProfile) {
            final userCity = profileState.profile!.city!;
            setState(() {
              _selectedCity = userCity;
              _cityController.text = userCity;
              _citySetFromProfile = true;
            });
            // Обновляем лидерборд после установки города
            _updateLeaderboard();
          }
        });
      }
    }

    // Преобразуем период в формат для API
    String period = 'current_week';
    if (_selectedPeriod == 'Текущий месяц') {
      period = 'current_month';
    } else if (_selectedPeriod == 'Текущий год') {
      period = 'current_year';
    } else if (_selectedPeriod == 'Выбранный период') {
      period = 'custom';
    }

    final params = CityLeaderboardParams(
      city: _selectedCity,
      sport: _sport,
      period: period,
      dateStart: _selectedDateRange != null
          ? _selectedDateRange!.start.toIso8601String().split(
              'T',
            )[0] // YYYY-MM-DD
          : null,
      dateEnd: _selectedDateRange != null
          ? _selectedDateRange!.end.toIso8601String().split(
              'T',
            )[0] // YYYY-MM-DD
          : null,
      genderMale: _genderMale,
      genderFemale: _genderFemale,
      parameter: _selectedParameter ?? 'Расстояние',
    );

    final leaderboardAsync = ref.watch(cityLeaderboardProvider(params));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Верхние элементы с padding
          Padding(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 8,
              left: 12,
              right: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Поле автокомплита для выбора города
                CityAutocompleteField(
                  controller: _cityController,
                  suggestions: _cities,
                  onSelected: (city) {
                    setState(() {
                      _selectedCity = city;
                      _cityController.text = city;
                    });
                    // Обновляем данные при выборе города из списка
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateLeaderboard();
                    });
                  },
                  onSubmitted: _applyCity, // Применяем город при нажатии Enter
                  hasError:
                      _selectedCity == null && _cityController.text.isNotEmpty,
                  errorText:
                      _selectedCity == null && _cityController.text.isNotEmpty
                      ? 'Выберите город из списка'
                      : null,
                ),
                const SizedBox(height: 8),
                // ── Панель фильтров
                LeaderboardFiltersPanel(
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
                        _updateLeaderboard();
                      });
                    }
                  },
                  onSportChanged: (int sport) {
                    setState(() {
                      _sport = sport;
                    });
                    // Обновляем данные при изменении вида спорта
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateLeaderboard();
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
                      // Обновляем данные при изменении периода
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _updateLeaderboard();
                      });
                    }
                  },
                  onGenderMaleChanged: (bool value) {
                    setState(() {
                      _genderMale = value;
                    });
                    // Обновляем данные при изменении фильтра по полу
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateLeaderboard();
                    });
                  },
                  onGenderFemaleChanged: (bool value) {
                    setState(() {
                      _genderFemale = value;
                    });
                    // Обновляем данные при изменении фильтра по полу
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateLeaderboard();
                    });
                  },
                  onApplyDate: (dateRange) {
                    setState(() {
                      _selectedDateRange = dateRange;
                    });
                    // Обновляем данные при применении дат (после обновления состояния)
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateLeaderboard();
                    });
                  },
                ),
              ],
            ),
          ),

          // ── Контент лидерборда
          leaderboardAsync.when(
            data: (result) {
              final rows = result.leaderboard;
              final currentUserRank = result.currentUserRank;

              // Если город не выбран, показываем сообщение
              if (_selectedCity == null || _selectedCity!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 32),
                  child: Center(
                    child: Text(
                      'Выберите город для отображения лидерборда',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 32),
                  child: Center(
                    child: Text(
                      'Нет данных для отображения',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
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
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 32),
              child: Center(child: CupertinoActivityIndicator(radius: 10)),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    const Text(
                      'Ошибка загрузки данных',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(cityLeaderboardProvider(params));
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
