import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';

/// ──────────── Bottom Sheet для фильтров событий ────────────
///
/// Отображает фильтры: вид спорта, тип события, даты.
/// Использует стиль iOS с BouncingScrollPhysics и AppTheme токенами.
class EventsFiltersBottomSheet extends StatefulWidget {
  /// Callback для применения фильтров
  /// Передает параметры фильтра: виды спорта, типы событий, даты
  final Function(EventsFilterParams)? onApplyFilters;

  /// Начальные параметры фильтра (для восстановления состояния)
  final EventsFilterParams? initialParams;

  const EventsFiltersBottomSheet({
    super.key,
    this.onApplyFilters,
    this.initialParams,
  });

  @override
  State<EventsFiltersBottomSheet> createState() =>
      _EventsFiltersBottomSheetState();
}

class _EventsFiltersBottomSheetState extends State<EventsFiltersBottomSheet> {
  // ──── Состояние фильтров ────

  /// Выбранные виды спорта (множественный выбор, минимум один)
  late Set<SportType> _selectedSports;

  /// Выбранные типы событий (множественный выбор, минимум один)
  late Set<EventType> _selectedEventTypes;

  /// Дата начала периода
  DateTime? _startDate;

  /// Дата окончания периода
  DateTime? _endDate;

  // ──── Инициализация фильтров ────
  @override
  void initState() {
    super.initState();
    
    // Восстанавливаем параметры из initialParams, если они есть
    if (widget.initialParams != null) {
      _selectedSports = widget.initialParams!.sports.toSet();
      _selectedEventTypes = widget.initialParams!.eventTypes.toSet();
      _startDate = widget.initialParams!.startDate;
      _endDate = widget.initialParams!.endDate;
    } else {
      // Устанавливаем дефолтные значения
      _selectedSports = {
        SportType.run,
        SportType.bike,
        SportType.swim,
      };
      _selectedEventTypes = {
        EventType.official,
        EventType.amateur,
      };
      // Устанавливаем дефолтные даты: сегодня и сегодня + 1 год
      final today = DateTime.now();
      _startDate = DateTime(today.year, today.month, today.day);
      _endDate = DateTime(today.year + 1, today.month, today.day);
    }
  }

  // ──── Применение фильтров ────
  void _applyFilters() {
    // Формируем параметры фильтра
    final params = EventsFilterParams(
      sports: _selectedSports.toList(),
      eventTypes: _selectedEventTypes.toList(),
      startDate: _startDate,
      endDate: _endDate,
    );

    // Вызываем callback с параметрами фильтра
    widget.onApplyFilters?.call(params);

    // Закрываем bottom sheet
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

            // ──── Заголовок ────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: Text('Фильтры', style: AppTextStyles.h17w6)),
            ),
            const SizedBox(height: 16),

            // ──── Разделительная линия ────
            Divider(height: 1, thickness: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // ──── Контент ────
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 34),

                  // ──── Кнопка "Применить" ────
                  Center(
                    child: PrimaryButton(
                      text: 'Применить',
                      onPressed: _applyFilters,
                      width: MediaQuery.of(context).size.width * 0.5,
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
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

// ──────────── Модели данных ────────────

/// Параметры фильтра событий
class EventsFilterParams {
  /// Выбранные виды спорта
  final List<SportType> sports;

  /// Выбранные типы событий
  final List<EventType> eventTypes;

  /// Дата начала периода
  final DateTime? startDate;

  /// Дата окончания периода
  final DateTime? endDate;

  const EventsFilterParams({
    required this.sports,
    required this.eventTypes,
    this.startDate,
    this.endDate,
  });

  /// Проверяет, применены ли какие-либо фильтры (кроме дефолтных)
  bool get hasFilters {
    // Если выбраны не все виды спорта или не все типы событий - есть фильтры
    if (sports.length < SportType.values.length) return true;
    if (eventTypes.length < EventType.values.length) return true;
    // Если даты установлены - есть фильтры
    if (startDate != null || endDate != null) return true;
    return false;
  }
}

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

  /// Преобразует вид спорта в строку для API
  String get apiValue {
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

  /// Преобразует тип события в строку для API
  String get apiValue {
    switch (this) {
      case EventType.official:
        return 'official';
      case EventType.amateur:
        return 'amateur';
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
