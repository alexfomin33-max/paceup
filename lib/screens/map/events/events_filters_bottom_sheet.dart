import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';

/// ──────────── Bottom Sheet для фильтров событий ────────────
///
/// Отображает фильтры: вид спорта, тип события, даты, регистрация, друзья.
/// Использует стиль iOS с BouncingScrollPhysics и AppTheme токенами.
class EventsFiltersBottomSheet extends StatefulWidget {
  const EventsFiltersBottomSheet({super.key});

  @override
  State<EventsFiltersBottomSheet> createState() =>
      _EventsFiltersBottomSheetState();
}

class _EventsFiltersBottomSheetState extends State<EventsFiltersBottomSheet> {
  // ──── Состояние фильтров ────

  /// Выбранные виды спорта (множественный выбор, минимум один)
  final Set<SportType> _selectedSports = {
    SportType.run,
    SportType.bike,
    SportType.swim,
  };

  /// Выбранные типы событий (множественный выбор, минимум один)
  final Set<EventType> _selectedEventTypes = {
    EventType.official,
    EventType.amateur,
  };

  /// Дата начала периода
  DateTime? _startDate;

  /// Дата окончания периода
  DateTime? _endDate;

  /// Показывать только события, в которых зарегистрирован
  bool _onlyRegistered = false;

  /// Выбранный друг (для фильтрации по друзьям)
  String? _selectedFriend;

  // ──── Инициализация дат по умолчанию ────
  @override
  void initState() {
    super.initState();
    // Устанавливаем дефолтные даты: сегодня и сегодня + 1 год
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = DateTime(today.year + 1, today.month, today.day);
  }

  // ──── Сброс всех фильтров ────
  void _resetFilters() {
    setState(() {
      _selectedSports.clear();
      _selectedSports.addAll(SportType.values);
      _selectedEventTypes.clear();
      _selectedEventTypes.addAll(EventType.values);
      // Сбрасываем даты на дефолтные: сегодня и сегодня + 1 год
      final today = DateTime.now();
      _startDate = DateTime(today.year, today.month, today.day);
      _endDate = DateTime(today.year + 1, today.month, today.day);
      _onlyRegistered = false;
      _selectedFriend = null;
    });
  }

  // ──── Применение фильтров ────
  void _applyFilters() {
    // TODO: Здесь будет логика применения фильтров
    Navigator.of(context).pop();
  }

  // ──── Форматирование даты ────
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  // ──── Выбор даты начала ────
  Future<void> _pickStartDate() async {
    final today = DateTime.now();
    final initial = _startDate ?? today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        // Если дата начала больше даты окончания, обновляем дату окончания
        if (_endDate != null && picked.isAfter(_endDate!)) {
          _endDate = picked;
        }
      });
    }
  }

  // ──── Выбор даты окончания ────
  Future<void> _pickEndDate() async {
    final today = DateTime.now();
    final initial = _endDate ?? _startDate ?? today;
    final firstDate = _startDate ?? DateTime(today.year - 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(today.year + 5),
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final maxH = h * 0.67; // примерно 2/3 экрана

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ──── Ручка для перетаскивания ────
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10, top: 4),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),

              // ──── Заголовок с кнопками ────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Кнопка "Закрыть"
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Закрыть',
                        style: AppTextStyles.h14w4.copyWith(
                          color: AppColors.link,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Заголовок
                    Text('Фильтры', style: AppTextStyles.h17w6),
                    const Spacer(),
                    // Кнопка "Сбросить"
                    TextButton(
                      onPressed: _resetFilters,
                      child: Text(
                        'Сбросить',
                        style: AppTextStyles.h14w4.copyWith(
                          color: AppColors.link,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ──── Контент с прокруткой ────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ──── Секция "Вид спорта" ────
                      _SectionTitle('Вид спорта'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SportType.values.map((sport) {
                          final isSelected = _selectedSports.contains(sport);
                          return _SportPillButton(
                            sport: sport,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  // Нельзя снять последний выбранный вид спорта
                                  if (_selectedSports.length > 1) {
                                    _selectedSports.remove(sport);
                                  }
                                } else {
                                  _selectedSports.add(sport);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // ──── Секция "Тип события" ────
                      _SectionTitle('Тип события'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: EventType.values.map((type) {
                          final isSelected = _selectedEventTypes.contains(type);
                          return _EventTypePillButton(
                            type: type,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  // Нельзя снять последний выбранный тип события
                                  if (_selectedEventTypes.length > 1) {
                                    _selectedEventTypes.remove(type);
                                  }
                                } else {
                                  _selectedEventTypes.add(type);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // ──── Секция "Дата проведения" ────
                      _SectionTitle('Дата проведения'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DatePickerButton(
                              label: _formatDate(_startDate),
                              onTap: _pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '—',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DatePickerButton(
                              label: _formatDate(_endDate),
                              onTap: _pickEndDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ──── Чекбокс "События, в которых зарегистрированы" ────
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _onlyRegistered,
                              onChanged: (v) =>
                                  setState(() => _onlyRegistered = v ?? false),
                              side: const BorderSide(color: AppColors.border),
                              activeColor: AppColors.brandPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'События, в которых зарегистрированы',
                              style: AppTextStyles.h14w4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ──── Поле "Все друзья" ────
                      _FriendsDropdown(
                        value: _selectedFriend,
                        onChanged: (value) {
                          setState(() {
                            _selectedFriend = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ──── Кнопка "Применить" ────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: PrimaryButton(
                    text: 'Применить',
                    onPressed: _applyFilters,
                    width: MediaQuery.of(context).size.width * 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────── Вспомогательные виджеты ────────────

/// Заголовок секции фильтров
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.h14w6);
  }
}

/// Кнопка-пилюля для вида спорта
class _SportPillButton extends StatelessWidget {
  final SportType sport;
  final bool isSelected;
  final VoidCallback onTap;

  const _SportPillButton({
    required this.sport,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? AppColors.brandPrimary : AppColors.surface;
    final textColor = isSelected ? AppColors.surface : AppColors.textPrimary;
    final borderColor = isSelected ? AppColors.brandPrimary : AppColors.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(sport.icon, size: 16, color: textColor),
              const SizedBox(width: 6),
              Text(
                sport.label,
                style: AppTextStyles.h14w4.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка-пилюля для типа события
class _EventTypePillButton extends StatelessWidget {
  final EventType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _EventTypePillButton({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? AppColors.brandPrimary : AppColors.surface;
    final textColor = isSelected ? AppColors.surface : AppColors.textPrimary;
    final borderColor = isSelected ? AppColors.brandPrimary : AppColors.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type.icon, size: 16, color: textColor),
              const SizedBox(width: 6),
              Text(
                type.label,
                style: AppTextStyles.h14w4.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка для выбора даты
class _DatePickerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DatePickerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.calendar,
                size: 16,
                color: AppColors.iconSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.isEmpty ? 'Дата' : label,
                  style: label.isEmpty
                      ? AppTextStyles.h14w4Place
                      : AppTextStyles.h14w4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Выпадающий список для выбора друзей
class _FriendsDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _FriendsDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Демо-список друзей (в реальности будет из API)
    const friends = [
      'Все друзья',
      'Иван Иванов',
      'Мария Петрова',
      'Алексей Сидоров',
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value ?? friends.first,
          isExpanded: true,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.iconSecondary,
          ),
          dropdownColor: AppColors.surface,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          style: AppTextStyles.h14w4,
          onChanged: (newValue) => onChanged(newValue),
          items: friends.map((friend) {
            return DropdownMenuItem(
              value: friend,
              child: Text(friend, style: AppTextStyles.h14w4),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ──────────── Модели данных ────────────

/// Виды спорта для фильтра
enum SportType { run, bike, swim }

extension SportTypeExtension on SportType {
  String get label {
    switch (this) {
      case SportType.run:
        return 'Бег';
      case SportType.bike:
        return 'Велосипед';
      case SportType.swim:
        return 'Плавание';
    }
  }

  IconData get icon {
    switch (this) {
      case SportType.run:
        return Icons.directions_run;
      case SportType.bike:
        return Icons.directions_bike;
      case SportType.swim:
        return Icons.pool;
    }
  }
}

/// Типы событий для фильтра
enum EventType { official, amateur }

extension EventTypeExtension on EventType {
  String get label {
    switch (this) {
      case EventType.official:
        return 'Официальные';
      case EventType.amateur:
        return 'Любительские';
    }
  }

  IconData get icon {
    switch (this) {
      case EventType.official:
        return Icons.emoji_events; // трофей/награда
      case EventType.amateur:
        return CupertinoIcons.person;
    }
  }
}
