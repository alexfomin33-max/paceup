// lib/features/tasks/screens/rating_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран «Рейтинг» с PaceAppBar + TabBar для переключения вкладок
// Переключение вкладок через TabBarView со свайпом и синхронизированным TabBar.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bar.dart';

// ── Параметры статистики для выпадающего списка
const _kRatingParameters = [
  'Расстояние',
  'Тренировок',
  'Общее время',
  'Набор высоты',
  'Средний темп',
  'Средний пульс',
];

class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen>
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
        title: 'Рейтинг',
        showBack: true,
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
            child: Padding(
              // Добавляем padding снизу, чтобы контент не перекрывал нижнее меню
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).padding.bottom +
                    60, // высота нижнего меню + системный отступ
              ),
              child: TabBarView(
                controller: _tab,
                physics: const BouncingScrollPhysics(),
                children: const [
                  // TODO: заменить на реальные виджеты контента
                  _PlaceholderContent(
                    key: PageStorageKey('rating_subscriptions'),
                    label: 'Подписки',
                  ),
                  _PlaceholderContent(
                    key: PageStorageKey('rating_users'),
                    label: 'Все пользователи',
                  ),
                  _CityRatingContent(key: PageStorageKey('rating_city')),
                ],
              ),
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
  // ── выбранный параметр рейтинга (по умолчанию "Расстояние")
  String? _selectedParameter = 'Расстояние';

  // ── вид спорта: 0 бег, 1 вело, 2 плавание (single-select)
  int _sport = 0;

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
                              // TODO: здесь будет фильтрация рейтинга по выбранному параметру
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
                        // TODO: здесь будет фильтрация рейтинга по виду спорта
                      }),
                    ),
                    const SizedBox(width: 8),
                    _SportIcon(
                      selected: _sport == 1,
                      icon: Icons.directions_bike,
                      onTap: () => setState(() {
                        _sport = 1;
                        // TODO: здесь будет фильтрация рейтинга по виду спорта
                      }),
                    ),
                    const SizedBox(width: 8),
                    _SportIcon(
                      selected: _sport == 2,
                      icon: Icons.pool,
                      onTap: () => setState(() {
                        _sport = 2;
                        // TODO: здесь будет фильтрация рейтинга по виду спорта
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Таблица рейтинга на всю ширину с отступами по 4px
          const _RatingTable(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     КОНТЕНТ ВКЛАДКИ «ГОРОД»
// ─────────────────────────────────────────────────────────────────────────────
/// Вкладка с полем поиска города для фильтрации рейтинга по городу
class _CityRatingContent extends ConsumerStatefulWidget {
  const _CityRatingContent({super.key});

  @override
  ConsumerState<_CityRatingContent> createState() => _CityRatingContentState();
}

class _CityRatingContentState extends ConsumerState<_CityRatingContent> {
  // ── контроллер для поля поиска города
  final _cityController = TextEditingController();

  // ── список городов для автокомплита (пока пустой, будет загружаться из API)
  final List<String> _cities = [];

  // ── выбранный параметр рейтинга (по умолчанию "Расстояние")
  String? _selectedParameter = 'Расстояние';

  // ── вид спорта: 0 бег, 1 вело, 2 плавание (single-select)
  int _sport = 0;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
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
                              // TODO: здесь будет фильтрация рейтинга по выбранному параметру
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SportIcon(
                      selected: _sport == 0,
                      icon: Icons.directions_run,
                      onTap: () => setState(() {
                        _sport = 0;
                        // TODO: здесь будет фильтрация рейтинга по виду спорта
                      }),
                    ),
                    const SizedBox(width: 8),
                    _SportIcon(
                      selected: _sport == 1,
                      icon: Icons.directions_bike,
                      onTap: () => setState(() {
                        _sport = 1;
                        // TODO: здесь будет фильтрация рейтинга по виду спорта
                      }),
                    ),
                    const SizedBox(width: 8),
                    _SportIcon(
                      selected: _sport == 2,
                      icon: Icons.pool,
                      onTap: () => setState(() {
                        _sport = 2;
                        // TODO: здесь будет фильтрация рейтинга по виду спорта
                      }),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Поле автокомплита для выбора города
                _CityAutocompleteField(
                  controller: _cityController,
                  suggestions: _cities,
                  onSelected: (city) {
                    _cityController.text = city;
                    // TODO: здесь будет фильтрация рейтинга по выбранному городу
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Таблица рейтинга на всю ширину с отступами по 4px
          const _RatingTable(),
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
/// Виджет выпадающего списка параметров рейтинга (стиль как "Вид активности")
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
            items: _kRatingParameters.map((option) {
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
//                     ТАБЛИЦА РЕЙТИНГА (ОТДЕЛЬНЫЙ ВИДЖЕТ)
// ─────────────────────────────────────────────────────────────────────────────
/// Таблица рейтинга на всю ширину экрана с отступами по 4px
class _RatingTable extends StatelessWidget {
  const _RatingTable();

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
          children: List.generate(_rows.length, (i) {
            final r = _rows[i];
            final isMe = r.rank == 4;
            return _FriendRow(
              rank: r.rank,
              name: r.name,
              value: r.value,
              avatar: r.avatar,
              highlight: isMe,
              isLast: i == _rows.length - 1,
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     СТРОКА ТАБЛИЦЫ РЕЙТИНГА
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
