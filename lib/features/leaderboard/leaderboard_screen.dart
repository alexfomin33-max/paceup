// lib/features/tasks/screens/leaderboard_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран «Лидерборд» с PaceAppBar + TabBar для переключения вкладок
// Переключение вкладок через TabBarView со свайпом и синхронизированным TabBar.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bar.dart';

// ── Параметры статистики для выпадающего списка
const _kLeaderboardParameters = [
  'Расстояние',
  'Тренировок',
  'Общее время',
  'Набор высоты',
  'Средний темп',
  'Средний пульс',
];

// ── Периоды для выпадающего списка
const _kPeriods = [
  'Текущая неделя',
  'Текущий месяц',
  'Текущий год',
  'Выбранный период',
];

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
                // TODO: заменить на реальные виджеты контента
                _PlaceholderContent(
                  key: PageStorageKey('leaderboard_subscriptions'),
                  label: 'Подписки',
                ),
                _PlaceholderContent(
                  key: PageStorageKey('leaderboard_users'),
                  label: 'Все пользователи',
                ),
                _CityLeaderboardContent(
                  key: PageStorageKey('leaderboard_city'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ЗАГЛУШКА ДЛЯ КОНТЕНТА ВКЛАДОК
// ─────────────────────────────────────────────────────────────────────────────
/// Временный виджет-заглушка, будет заменен на реальный контент
class _PlaceholderContent extends ConsumerStatefulWidget {
  final String label;

  const _PlaceholderContent({super.key, required this.label});

  @override
  ConsumerState<_PlaceholderContent> createState() =>
      _PlaceholderContentState();
}

class _PlaceholderContentState extends ConsumerState<_PlaceholderContent> {
  // ── выбранный параметр лидерборда (по умолчанию "Расстояние")
  String? _selectedParameter = 'Расстояние';

  // ── вид спорта: 0 бег, 1 вело, 2 плавание (single-select)
  int _sport = 0;

  // ── выбранный период (по умолчанию "Текущая неделя")
  String? _selectedPeriod = 'Текущая неделя';

  // ── пол: по умолчанию оба выбраны, всегда хотя бы один должен быть активен
  bool _genderMale = true;
  bool _genderFemale = true;

  // ── состояние кнопки применения даты (активна при нажатии)
  bool _applyDatePressed = false;

  // ── контроллеры для полей дат (появляются при выборе "Выбранный период")
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  // ── FocusNode для полей дат
  final _startDateFocusNode = FocusNode();
  final _endDateFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // ── Добавляем слушатели для обновления состояния кнопки при изменении текста
    _startDateController.addListener(_updateDateButtonState);
    _endDateController.addListener(_updateDateButtonState);
  }

  @override
  void dispose() {
    _startDateController.removeListener(_updateDateButtonState);
    _endDateController.removeListener(_updateDateButtonState);
    _startDateController.dispose();
    _endDateController.dispose();
    _startDateFocusNode.dispose();
    _endDateFocusNode.dispose();
    super.dispose();
  }

  // ── Обновляет состояние при изменении текста в полях дат
  void _updateDateButtonState() {
    setState(() {});
  }

  // ── форматирует дату в формат "dd.MM.yyyy"
  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd.$mm.$yy';
  }

  // ── проверяет, заполнены ли оба поля дат полностью (по 8 цифр в каждом)
  bool _areDateFieldsComplete() {
    final startDigits = _startDateController.text.replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    final endDigits = _endDateController.text.replaceAll(RegExp(r'[^\d]'), '');
    return startDigits.length == 8 && endDigits.length == 8;
  }

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Выпадающий список параметров + иконки видов спорта
                Row(
                  children: [
                    Expanded(
                      child: _ParameterDropdown(
                        value: _selectedParameter,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedParameter = newValue;
                              // TODO: здесь будет фильтрация лидерборда по выбранному параметру
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    _SportIcon(
                      selected: _sport == 0,
                      icon: Icons.directions_run,
                      onTap: () => setState(() {
                        _sport = 0;
                        // TODO: здесь будет фильтрация лидерборда по виду спорта
                      }),
                    ),
                    const SizedBox(width: 8),
                    _SportIcon(
                      selected: _sport == 1,
                      icon: Icons.directions_bike,
                      onTap: () => setState(() {
                        _sport = 1;
                        // TODO: здесь будет фильтрация лидерборда по виду спорта
                      }),
                    ),
                    const SizedBox(width: 8),
                    _SportIcon(
                      selected: _sport == 2,
                      icon: Icons.pool,
                      onTap: () => setState(() {
                        _sport = 2;
                        // TODO: здесь будет фильтрация лидерборда по виду спорта
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Выпадающий список периода + иконки пола
                Row(
                  children: [
                    Expanded(
                      child: _PeriodDropdown(
                        value: _selectedPeriod,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedPeriod = newValue;
                              // TODO: здесь будет фильтрация лидерборда по выбранному периоду
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    _GenderIcon(
                      selected: _genderMale,
                      label: 'М',
                      onTap: () {
                        // ── Если обе выбраны, снимаем выбор с мужской
                        // ── Если выбрана только женская, выбираем обе
                        // ── Если выбрана только мужская, нельзя снять (должна быть активна хотя бы одна)
                        if (_genderMale && _genderFemale) {
                          setState(() {
                            _genderMale = false;
                            // TODO: здесь будет фильтрация лидерборда по полу
                          });
                        } else if (!_genderMale && _genderFemale) {
                          setState(() {
                            _genderMale = true;
                            // TODO: здесь будет фильтрация лидерборда по полу
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _GenderIcon(
                      selected: _genderFemale,
                      label: 'Ж',
                      onTap: () {
                        // ── Если обе выбраны, снимаем выбор с женской
                        // ── Если выбрана только мужская, выбираем обе
                        // ── Если выбрана только женская, нельзя снять (должна быть активна хотя бы одна)
                        if (_genderMale && _genderFemale) {
                          setState(() {
                            _genderFemale = false;
                            // TODO: здесь будет фильтрация лидерборда по полу
                          });
                        } else if (_genderMale && !_genderFemale) {
                          setState(() {
                            _genderFemale = true;
                            // TODO: здесь будет фильтрация лидерборда по полу
                          });
                        }
                      },
                    ),
                  ],
                ),
                // ── Поля для выбора дат (появляются при выборе "Выбранный период")
                if (_selectedPeriod == 'Выбранный период') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        flex: 2,
                        child: _DateField(
                          controller: _startDateController,
                          focusNode: _startDateFocusNode,
                          hintText: _formatDate(
                            DateTime.now().subtract(const Duration(days: 8)),
                          ),
                          onComplete: () {
                            // ── Переключаем фокус на второе поле
                            _endDateFocusNode.requestFocus();
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '—',
                          style: AppTextStyles.h14w4.copyWith(
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: _DateField(
                          controller: _endDateController,
                          focusNode: _endDateFocusNode,
                          hintText: _formatDate(
                            DateTime.now().subtract(const Duration(days: 1)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _ApplyDateIcon(
                        selected: _applyDatePressed,
                        enabled: _areDateFieldsComplete(),
                        onTap: () {
                          setState(() {
                            _applyDatePressed = !_applyDatePressed;
                            // TODO: здесь будет применение выбранного периода
                          });
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Топ-3 лидера перед таблицей
          const _TopThreeLeaders(),
          const SizedBox(height: 16),
          // ── Таблица лидерборда на всю ширину с отступами по 4px
          const _LeaderboardTable(),
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

// ─────────────────────────────────────────────────────────────────────────────
//                     КОНТЕНТ ВКЛАДКИ «ГОРОД»
// ─────────────────────────────────────────────────────────────────────────────
/// Вкладка с полем поиска города для фильтрации лидерборда по городу
class _CityLeaderboardContent extends ConsumerStatefulWidget {
  const _CityLeaderboardContent({super.key});

  @override
  ConsumerState<_CityLeaderboardContent> createState() =>
      _CityLeaderboardContentState();
}

class _CityLeaderboardContentState
    extends ConsumerState<_CityLeaderboardContent> {
  // ── контроллер для поля поиска города
  final _cityController = TextEditingController();

  // ── список городов для автокомплита (пока пустой, будет загружаться из API)
  final List<String> _cities = [];

  // ── выбранный параметр лидерборда (по умолчанию "Расстояние")
  String? _selectedParameter = 'Расстояние';

  // ── вид спорта: 0 бег, 1 вело, 2 плавание (single-select)
  int _sport = 0;

  // ── выбранный период (по умолчанию "Текущая неделя")
  String? _selectedPeriod = 'Текущая неделя';

  // ── пол: по умолчанию оба выбраны, всегда хотя бы один должен быть активен
  bool _genderMale = true;
  bool _genderFemale = true;

  // ── состояние кнопки применения даты (активна при нажатии)
  bool _applyDatePressed = false;

  // ── контроллеры для полей дат (появляются при выборе "Выбранный период")
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  // ── FocusNode для полей дат
  final _startDateFocusNode = FocusNode();
  final _endDateFocusNode = FocusNode();

  @override
  void dispose() {
    _cityController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _startDateFocusNode.dispose();
    _endDateFocusNode.dispose();
    super.dispose();
  }

  // ── форматирует дату в формат "dd.MM.yyyy"
  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd.$mm.$yy';
  }

  // ── проверяет, заполнены ли оба поля дат полностью (по 8 цифр в каждом)
  bool _areDateFieldsComplete() {
    final startDigits = _startDateController.text.replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    final endDigits = _endDateController.text.replaceAll(RegExp(r'[^\d]'), '');
    return startDigits.length == 8 && endDigits.length == 8;
  }

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Поле автокомплита для выбора города
                _CityAutocompleteField(
                  controller: _cityController,
                  suggestions: _cities,
                  onSelected: (city) {
                    _cityController.text = city;
                    // TODO: здесь будет фильтрация лидерборда по выбранному городу
                  },
                ),
                const SizedBox(height: 8),
                // ── Выпадающий список параметров + иконки видов спорта
                Row(
                  children: [
                    Expanded(
                      child: _ParameterDropdown(
                        value: _selectedParameter,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedParameter = newValue;
                              // TODO: здесь будет фильтрация лидерборда по выбранному параметру
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    _SportIcon(
                      selected: _sport == 0,
                      icon: Icons.directions_run,
                      onTap: () => setState(() {
                        _sport = 0;
                        // TODO: здесь будет фильтрация лидерборда по виду спорта
                      }),
                    ),
                    const SizedBox(width: 8),
                    _SportIcon(
                      selected: _sport == 1,
                      icon: Icons.directions_bike,
                      onTap: () => setState(() {
                        _sport = 1;
                        // TODO: здесь будет фильтрация лидерборда по виду спорта
                      }),
                    ),
                    const SizedBox(width: 8),
                    _SportIcon(
                      selected: _sport == 2,
                      icon: Icons.pool,
                      onTap: () => setState(() {
                        _sport = 2;
                        // TODO: здесь будет фильтрация лидерборда по виду спорта
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Выпадающий список периода + иконки пола
                Row(
                  children: [
                    Expanded(
                      child: _PeriodDropdown(
                        value: _selectedPeriod,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedPeriod = newValue;
                              // TODO: здесь будет фильтрация лидерборда по выбранному периоду
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    _GenderIcon(
                      selected: _genderMale,
                      label: 'М',
                      onTap: () {
                        // ── Если обе выбраны, снимаем выбор с мужской
                        // ── Если выбрана только женская, выбираем обе
                        // ── Если выбрана только мужская, нельзя снять (должна быть активна хотя бы одна)
                        if (_genderMale && _genderFemale) {
                          setState(() {
                            _genderMale = false;
                            // TODO: здесь будет фильтрация лидерборда по полу
                          });
                        } else if (!_genderMale && _genderFemale) {
                          setState(() {
                            _genderMale = true;
                            // TODO: здесь будет фильтрация лидерборда по полу
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _GenderIcon(
                      selected: _genderFemale,
                      label: 'Ж',
                      onTap: () {
                        // ── Если обе выбраны, снимаем выбор с женской
                        // ── Если выбрана только мужская, выбираем обе
                        // ── Если выбрана только женская, нельзя снять (должна быть активна хотя бы одна)
                        if (_genderMale && _genderFemale) {
                          setState(() {
                            _genderFemale = false;
                            // TODO: здесь будет фильтрация лидерборда по полу
                          });
                        } else if (_genderMale && !_genderFemale) {
                          setState(() {
                            _genderFemale = true;
                            // TODO: здесь будет фильтрация лидерборда по полу
                          });
                        }
                      },
                    ),
                  ],
                ),
                // ── Поля для выбора дат (появляются при выборе "Выбранный период")
                if (_selectedPeriod == 'Выбранный период') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        flex: 2,
                        child: _DateField(
                          controller: _startDateController,
                          focusNode: _startDateFocusNode,
                          hintText: _formatDate(
                            DateTime.now().subtract(const Duration(days: 8)),
                          ),
                          onComplete: () {
                            // ── Переключаем фокус на второе поле
                            _endDateFocusNode.requestFocus();
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '—',
                          style: AppTextStyles.h14w4.copyWith(
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: _DateField(
                          controller: _endDateController,
                          focusNode: _endDateFocusNode,
                          hintText: _formatDate(
                            DateTime.now().subtract(const Duration(days: 1)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _ApplyDateIcon(
                        selected: _applyDatePressed,
                        enabled: _areDateFieldsComplete(),
                        onTap: () {
                          setState(() {
                            _applyDatePressed = !_applyDatePressed;
                            // TODO: здесь будет применение выбранного периода
                          });
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Топ-3 лидера перед таблицей
          const _TopThreeLeaders(),
          const SizedBox(height: 16),
          // ── Таблица лидерборда на всю ширину с отступами по 4px
          const _LeaderboardTable(),
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

// ─────────────────────────────────────────────────────────────────────────────
//                     ПОЛЕ АВТОКОМПЛИТА ДЛЯ ГОРОДА
// ─────────────────────────────────────────────────────────────────────────────
/// Виджет автокомплита для поиска города (аналогичен create_club_screen.dart)
class _CityAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final Function(String) onSelected;

  const _CityAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.getBorderColor(context);

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final query = textEditingValue.text.toLowerCase();
        return suggestions.where((city) {
          return city.toLowerCase().startsWith(query);
        });
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Инициализируем текст из внешнего контроллера
            if (textEditingController.text.isEmpty &&
                controller.text.isNotEmpty) {
              textEditingController.text = controller.text;
            }

            // Синхронизируем изменения в Autocomplete контроллере с внешним
            textEditingController.addListener(() {
              if (textEditingController.text != controller.text) {
                controller.text = textEditingController.text;
              }
            });

            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              onSubmitted: (String value) {
                onFieldSubmitted();
              },
              style: AppTextStyles.h14w4.copyWith(
                color: AppColors.getTextPrimaryColor(context),
              ),
              decoration: InputDecoration(
                hintText: 'Введите город',
                hintStyle: AppTextStyles.h14w4Place,
                filled: true,
                fillColor: AppColors.getSurfaceColor(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 17,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
              ),
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: AppColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Text(
                            option,
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ВЫПАДАЮЩИЙ СПИСОК ПАРАМЕТРОВ
// ─────────────────────────────────────────────────────────────────────────────
/// Виджет выпадающего списка параметров лидерборда (стиль как "Вид активности")
class _ParameterDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _ParameterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.getSurfaceColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: const Text(
              'Выберите параметр',
              style: AppTextStyles.h14w4Place,
            ),
            onChanged: onChanged,
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.md),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
            items: _kLeaderboardParameters.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Builder(
                  builder: (context) => Text(
                    option,
                    style: AppTextStyles.h14w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ИКОНКА ВИДА СПОРТА
// ─────────────────────────────────────────────────────────────────────────────
/// Иконка вида спорта с кружком (аналогична general_stats_content.dart)
class _SportIcon extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _SportIcon({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary
              : AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected
              ? AppColors.getSurfaceColor(context)
              : AppColors.getIconPrimaryColor(context),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ВЫПАДАЮЩИЙ СПИСОК ПЕРИОДА
// ─────────────────────────────────────────────────────────────────────────────
/// Виджет выпадающего списка периода лидерборда
class _PeriodDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _PeriodDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.getSurfaceColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: const Text(
              'Выберите период',
              style: AppTextStyles.h14w4Place,
            ),
            onChanged: onChanged,
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.md),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
            items: _kPeriods.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Builder(
                  builder: (context) => Text(
                    option,
                    style: AppTextStyles.h14w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ИКОНКА ПОЛА
// ─────────────────────────────────────────────────────────────────────────────
/// Иконка пола с текстом "М" или "Ж" (аналогична _SportIcon)
class _GenderIcon extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _GenderIcon({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary
              : AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.h14w4.copyWith(
              color: selected
                  ? AppColors.getSurfaceColor(context)
                  : AppColors.getTextPrimaryColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ИКОНКА ПРИМЕНИТЬ ДАТЫ
// ─────────────────────────────────────────────────────────────────────────────
/// Иконка галочки для применения выбранного периода (аналогична _GenderIcon)
class _ApplyDateIcon extends StatelessWidget {
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;

  const _ApplyDateIcon({
    required this.onTap,
    this.selected = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandPrimary
                : AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.check,
            size: 20,
            color: selected
                ? AppColors.getSurfaceColor(context)
                : AppColors.getIconPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ПОЛЕ ДЛЯ ВВОДА ДАТЫ
// ─────────────────────────────────────────────────────────────────────────────
/// Поле для ввода даты с маской формата "dd.MM.yyyy" и клавиатурой с цифрами
class _DateField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final VoidCallback? onComplete;

  const _DateField({
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [_DateInputFormatter()],
      onChanged: (value) {
        // ── Если введены все 8 цифр (10 символов с точками: dd.MM.yyyy),
        // ── переключаем фокус на следующее поле
        final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
        if (digitsOnly.length == 8 && onComplete != null) {
          onComplete!();
        }
      },
      style: AppTextStyles.h14w4.copyWith(
        color: AppColors.getTextPrimaryColor(context),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.h14w4Place,
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ФОРМАТТЕР ДЛЯ МАСКИ ДАТЫ
// ─────────────────────────────────────────────────────────────────────────────
/// Форматтер для автоматического форматирования даты в формате "dd.MM.yyyy"
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // ── Удаляем все символы, кроме цифр
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // ── Ограничиваем длину до 8 цифр (ddMMyyyy)
    String limitedText = text.length > 8 ? text.substring(0, 8) : text;

    // ── Валидация по позициям
    String validatedText = '';
    for (int i = 0; i < limitedText.length; i++) {
      final digit = limitedText[i];
      bool isValid = false;

      switch (i) {
        case 0: // ── Первая цифра дня: 0-3
          isValid =
              digit == '0' || digit == '1' || digit == '2' || digit == '3';
          break;
        case 1: // ── Вторая цифра дня: зависит от первой
          if (validatedText.isNotEmpty) {
            final firstDayDigit = validatedText[0];
            if (firstDayDigit == '0' ||
                firstDayDigit == '1' ||
                firstDayDigit == '2') {
              // ── Для 0x, 1x, 2x: вторая цифра 0-9
              isValid = true;
            } else if (firstDayDigit == '3') {
              // ── Для 3x: вторая цифра только 0-1 (30, 31)
              isValid = digit == '0' || digit == '1';
            }
          } else {
            isValid = true; // ── Если первая цифра еще не введена
          }
          break;
        case 2: // ── Первая цифра месяца: 0-1
          isValid = digit == '0' || digit == '1';
          break;
        case 3: // ── Вторая цифра месяца: зависит от первой
          if (validatedText.length >= 3) {
            final firstMonthDigit = validatedText[2];
            if (firstMonthDigit == '0') {
              // ── Для 0x: вторая цифра 0-9 (01-09)
              isValid = true;
            } else if (firstMonthDigit == '1') {
              // ── Для 1x: вторая цифра только 0-2 (10, 11, 12)
              isValid = digit == '0' || digit == '1' || digit == '2';
            }
          } else {
            isValid = true; // ── Если первая цифра месяца еще не введена
          }
          break;
        case 4: // ── Первая цифра года: только 2
          isValid = digit == '2';
          break;
        case 5: // ── Вторая цифра года: только 0
          isValid = digit == '0';
          break;
        case 6: // ── Третья цифра года: только 2
          isValid = digit == '2';
          break;
        case 7: // ── Четвертая цифра года: только 5-6
          isValid = digit == '5' || digit == '6';
          break;
        default:
          isValid = false;
      }

      if (isValid) {
        validatedText += digit;
      } else {
        // ── Если символ невалиден, останавливаем обработку
        break;
      }
    }

    // ── Форматируем с точками
    String formatted = '';
    for (int i = 0; i < validatedText.length; i++) {
      if (i == 2 || i == 4) {
        formatted += '.';
      }
      formatted += validatedText[i];
    }

    // ── Вычисляем новую позицию курсора
    // ── Если добавляем символ, курсор сдвигается вперед
    // ── Если удаляем, курсор остается на месте
    int cursorPosition = formatted.length;
    if (oldValue.text.length < formatted.length) {
      // ── Добавление символа: курсор после последнего символа
      cursorPosition = formatted.length;
    } else if (oldValue.text.length > formatted.length) {
      // ── Удаление символа: курсор на позиции удаления
      final oldDigits = oldValue.text.replaceAll(RegExp(r'[^\d]'), '');
      final newDigits = formatted.replaceAll(RegExp(r'[^\d]'), '');
      if (oldDigits.length > newDigits.length) {
        // ── Вычисляем позицию в отформатированной строке
        int digitIndex = 0;
        for (int i = 0; i < formatted.length; i++) {
          if (RegExp(r'\d').hasMatch(formatted[i])) {
            if (digitIndex == newDigits.length) {
              cursorPosition = i;
              break;
            }
            digitIndex++;
          }
        }
        if (cursorPosition == formatted.length) {
          cursorPosition = newValue.selection.baseOffset.clamp(
            0,
            formatted.length,
          );
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: cursorPosition.clamp(0, formatted.length),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ТОП-3 ЛИДЕРА
// ─────────────────────────────────────────────────────────────────────────────
/// Виджет для отображения топ-3 лидеров в стиле all_results_screen.dart
class _TopThreeLeaders extends StatelessWidget {
  const _TopThreeLeaders();

  @override
  Widget build(BuildContext context) {
    // ── Берем первые 3 элемента из демо-данных
    final topThree = _rows.take(3).toList();

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
            _LeaderAvatar(
              rank: topThree[1].rank,
              name: topThree[1].name,
              value: topThree[1].value,
              avatar: topThree[1].avatar,
              borderColor: AppColors.textSecondary, // светло-серый
            ),
            // ── 1 место (по центру, больше)
            _LeaderAvatar(
              rank: topThree[0].rank,
              name: topThree[0].name,
              value: topThree[0].value,
              avatar: topThree[0].avatar,
              borderColor: AppColors.accentYellow, // желтый
              isFirst: true,
            ),
            // ── 3 место (справа)
            _LeaderAvatar(
              rank: topThree[2].rank,
              name: topThree[2].name,
              value: topThree[2].value,
              avatar: topThree[2].avatar,
              borderColor: AppColors.orange, // оранжевый
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     АВАТАР ЛИДЕРА С РАМКОЙ И ЗНАЧКОМ
// ─────────────────────────────────────────────────────────────────────────────
/// Аватар лидера в стиле _LeaderCard из all_results_screen.dart:
/// цветной контейнер с padding, значок в правом нижнем углу
class _LeaderAvatar extends StatelessWidget {
  final int rank;
  final String name;
  final String value;
  final AssetImage avatar;
  final Color borderColor;
  final bool isFirst;

  const _LeaderAvatar({
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

// ─────────────────────────────────────────────────────────────────────────────
//                     ТАБЛИЦА ЛИДЕРБОРДА (ОТДЕЛЬНЫЙ ВИДЖЕТ)
// ─────────────────────────────────────────────────────────────────────────────
/// Таблица лидерборда на всю ширину экрана с отступами по 4px
class _LeaderboardTable extends StatelessWidget {
  const _LeaderboardTable();

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
          children: _rows.length > 3
              ? List.generate(_rows.length - 3, (i) {
                  final r = _rows[i + 3]; // начинаем с индекса 3 (4-е место)
                  final isMe = r.rank == 4;
                  final totalTableRows = _rows.length - 3;
                  return _FriendRow(
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

// ─────────────────────────────────────────────────────────────────────────────
//                     СТРОКА ТАБЛИЦЫ ЛИДЕРБОРДА
// ─────────────────────────────────────────────────────────────────────────────
class _FriendRow extends StatelessWidget {
  final int rank;
  final String name;
  final String value;
  final AssetImage avatar;
  final bool highlight;
  final bool isLast;

  const _FriendRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.avatar,
    required this.highlight,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
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
          const SizedBox(width: 12),
          ClipOval(
            child: Image(
              image: avatar,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.getTextPrimaryColor(context),
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
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.getDividerColor(context),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ДЕМО-ДАННЫЕ ДЛЯ ТАБЛИЦЫ
// ─────────────────────────────────────────────────────────────────────────────
class _RowData {
  final int rank;
  final String name;
  final String value;
  final AssetImage avatar;
  const _RowData(this.rank, this.name, this.value, this.avatar);
}

const _rows = <_RowData>[
  _RowData(1, 'Алексей Лукашин', '272,8', AssetImage('assets/avatar_1.png')),
  _RowData(2, 'Татьяна Свиридова', '214,7', AssetImage('assets/avatar_3.png')),
  _RowData(3, 'Борис Жарких', '197,2', AssetImage('assets/avatar_2.png')),
  _RowData(4, 'Евгений Бойко', '145,8', AssetImage('assets/avatar_0.png')),
  _RowData(
    5,
    'Екатерина Виноградова',
    '108,5',
    AssetImage('assets/avatar_4.png'),
  ),
  _RowData(6, 'Юрий Селиванов', '96,4', AssetImage('assets/avatar_5.png')),
];
